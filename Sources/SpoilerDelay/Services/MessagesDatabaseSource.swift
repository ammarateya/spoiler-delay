import Foundation
import SQLite3

actor MessagesReader {
    private let databasePath: String
    private let resolver: any ContactResolving

    init(databasePath: String, resolver: any ContactResolving = ContactResolver()) {
        self.databasePath = databasePath
        self.resolver = resolver
    }

    func canOpen() -> Bool {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        if db != nil { sqlite3_close(db) }
        return result == SQLITE_OK
    }

    func maximumRowID() throws -> Int64 {
        try withDatabase { db in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(ROWID), 0) FROM message", -1, &statement, nil) == SQLITE_OK else {
                throw databaseError(db)
            }
            defer { sqlite3_finalize(statement) }
            return sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int64(statement, 0) : 0
        }
    }

    func messages(after cursor: Int64) throws -> [IncomingMessage] {
        try withDatabase { db in
            let sql = """
            SELECT m.ROWID, COALESCE(m.guid, ''), m.text, m.attributedBody, m.date,
                   m.is_from_me, COALESCE(h.id, ''), c.display_name, c.chat_identifier,
                   EXISTS(SELECT 1 FROM message_attachment_join maj WHERE maj.message_id = m.ROWID)
            FROM message m
            LEFT JOIN handle h ON h.ROWID = m.handle_id
            LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            LEFT JOIN chat c ON c.ROWID = cmj.chat_id
            WHERE m.ROWID > ?
              AND COALESCE(m.item_type, 0) = 0
              AND COALESCE(m.associated_message_type, 0) = 0
            GROUP BY m.ROWID
            ORDER BY m.ROWID ASC
            LIMIT 500
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw databaseError(db) }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, cursor)
            var result: [IncomingMessage] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let rowID = sqlite3_column_int64(statement, 0)
                guard sqlite3_column_int(statement, 5) == 0 else { continue }
                let guid = string(statement, 1) ?? "message-\(rowID)"
                let handle = string(statement, 6) ?? "Unknown sender"
                let chatName = string(statement, 7)
                let chatIdentifier = string(statement, 8)
                let hasAttachment = sqlite3_column_int(statement, 9) != 0
                let text = string(statement, 2) ?? attributedText(statement, 3)
                let body = text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? (hasAttachment ? "Attachment" : "New message")
                let sender = resolver.displayName(for: handle) ?? handle
                result.append(IncomingMessage(
                    id: rowID,
                    guid: guid,
                    sender: sender,
                    chatName: chatName?.nilIfEmpty ?? chatIdentifier?.nilIfEmpty,
                    body: body,
                    receivedAt: messageDate(sqlite3_column_int64(statement, 4))
                ))
            }
            return result
        }
    }

    private func withDatabase<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let db else { throw NSError(domain: "SpoilerDelay.Messages", code: 1, userInfo: [NSLocalizedDescriptionKey: "Messages database access was denied."]) }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        return try work(db)
    }

    private func databaseError(_ db: OpaquePointer) -> Error {
        NSError(domain: "SpoilerDelay.Messages", code: Int(sqlite3_errcode(db)), userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))])
    }

    private func string(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let bytes = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: bytes)
    }

    private func attributedText(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) == SQLITE_BLOB,
              let bytes = sqlite3_column_blob(statement, column) else { return nil }
        let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
        if let attributed = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            return attributed.string
        }
        if let attributed = NSUnarchiver.unarchiveObject(with: data) as? NSAttributedString {
            return attributed.string
        }
        return nil
    }

    private func messageDate(_ raw: Int64) -> Date {
        let seconds = raw > 10_000_000_000 ? TimeInterval(raw) / 1_000_000_000 : TimeInterval(raw)
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}

@MainActor
final class MessagesDatabaseSource: MessageSource {
    private let reader: MessagesReader
    private var timer: Timer?
    private var cursor: Int64
    private var handler: (@MainActor ([IncomingMessage]) -> Void)?
    private var polling = false

    init(path: String = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath) {
        reader = MessagesReader(databasePath: path)
        cursor = Int64(UserDefaults.standard.object(forKey: "messagesCursor") as? Int ?? 0)
    }

    var canReadDatabase: Bool {
        get async { await reader.canOpen() }
    }

    func start(_ handler: @escaping @MainActor ([IncomingMessage]) -> Void) {
        self.handler = handler
        timer?.invalidate()
        Task {
            if cursor == 0, let max = try? await reader.maximumRowID() {
                cursor = max
                saveCursor()
            }
            await poll()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        handler = nil
    }

    private func poll() async {
        guard !polling else { return }
        polling = true
        defer { polling = false }
        do {
            let messages = try await reader.messages(after: cursor)
            if let newest = messages.map(\.id).max() {
                cursor = newest
                saveCursor()
            } else if let max = try? await reader.maximumRowID(), max > cursor {
                // Advance past outgoing/system rows so they are not queried forever.
                cursor = max
                saveCursor()
            }
            if !messages.isEmpty { handler?(messages) }
        } catch {
            // Permission and transient SQLite failures are surfaced through diagnostics.
        }
    }

    private func saveCursor() {
        UserDefaults.standard.set(cursor, forKey: "messagesCursor")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

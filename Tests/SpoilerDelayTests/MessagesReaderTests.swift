import Foundation
import SQLite3
import XCTest
@testable import SpoilerDelay

final class MessagesReaderTests: XCTestCase {
    func testReadsIncomingTextAndFiltersOutgoingMessages() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        defer { try? FileManager.default.removeItem(at: url) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        guard let db else { return XCTFail("Could not create fixture database") }

        let schema = """
        CREATE TABLE message (ROWID INTEGER PRIMARY KEY, guid TEXT, text TEXT, attributedBody BLOB, date INTEGER, is_from_me INTEGER, handle_id INTEGER, item_type INTEGER DEFAULT 0, associated_message_type INTEGER DEFAULT 0);
        CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
        CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, display_name TEXT, chat_identifier TEXT);
        CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
        CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
        INSERT INTO handle VALUES (1, '+15551234567');
        INSERT INTO chat VALUES (1, 'World Cup friends', 'chat-1');
        INSERT INTO message VALUES (10, 'incoming', 'hello', NULL, 1000000000, 0, 1, 0, 0);
        INSERT INTO chat_message_join VALUES (1, 10);
        INSERT INTO message VALUES (11, 'outgoing', 'sent by me', NULL, 1000000001, 1, 1, 0, 0);
        INSERT INTO chat_message_join VALUES (1, 11);
        """
        XCTAssertEqual(sqlite3_exec(db, schema, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        let reader = MessagesReader(databasePath: url.path, resolver: NoopContactResolver())
        let messages = try await reader.messages(after: 0)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].id, 10)
        XCTAssertEqual(messages[0].body, "hello")
        XCTAssertEqual(messages[0].chatName, "World Cup friends")
    }
}

private struct NoopContactResolver: ContactResolving {
    func displayName(for handle: String) -> String? { nil }
}

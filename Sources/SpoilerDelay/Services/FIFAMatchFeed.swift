import Foundation

enum MatchFeedError: LocalizedError {
    case invalidResponse
    case matchUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "FIFA returned an unreadable response."
        case .matchUnavailable: "The selected match is not currently in FIFA's feed."
        }
    }
}

struct FIFAMatchFeed: MatchFeed {
    static let competitionID = "17"
    static let seasonID = "285023"

    private let session: URLSession
    private let calendar = Calendar(identifier: .gregorian)

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upcomingMatches(now: Date = .now) async throws -> [WorldCupMatch] {
        let from = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let to = calendar.date(byAdding: .day, value: 8, to: now) ?? now
        let matches = try await fetch(from: from, to: to)
        return matches
            .filter { $0.phase != .fullTime && $0.kickoff > now.addingTimeInterval(-4 * 60 * 60) }
            .sorted { $0.kickoff < $1.kickoff }
    }

    func status(for match: WorldCupMatch) async throws -> WorldCupMatch {
        let from = calendar.date(byAdding: .day, value: -1, to: match.kickoff) ?? match.kickoff
        let to = calendar.date(byAdding: .day, value: 1, to: match.kickoff) ?? match.kickoff
        guard let current = try await fetch(from: from, to: to).first(where: { $0.id == match.id }) else {
            throw MatchFeedError.matchUnavailable
        }
        return current
    }

    private func fetch(from: Date, to: Date) async throws -> [WorldCupMatch] {
        var components = URLComponents(string: "https://api.fifa.com/api/v3/calendar/matches")!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let normalizedFrom = utcCalendar.startOfDay(for: from)
        let normalizedToStart = utcCalendar.startOfDay(for: to)
        let normalizedTo = (utcCalendar.date(byAdding: .day, value: 1, to: normalizedToStart) ?? to)
            .addingTimeInterval(-1)
        components.queryItems = [
            URLQueryItem(name: "from", value: formatter.string(from: normalizedFrom)),
            URLQueryItem(name: "to", value: formatter.string(from: normalizedTo)),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "count", value: "1000")
        ]
        guard let url = components.url else { throw MatchFeedError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("SpoilerDelay/0.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MatchFeedError.invalidResponse
        }
        return try Self.decode(data: data)
    }

    static func decode(data: Data) throws -> [WorldCupMatch] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["Results"] as? [[String: Any]] else {
            throw MatchFeedError.invalidResponse
        }

        let iso = ISO8601DateFormatter()
        return results.compactMap { raw in
            guard String(describing: raw["IdCompetition"] ?? "") == competitionID,
                  String(describing: raw["IdSeason"] ?? "") == seasonID,
                  let id = raw["IdMatch"].map({ String(describing: $0) }),
                  let dateString = raw["Date"] as? String,
                  let kickoff = iso.date(from: dateString),
                  let home = raw["Home"] as? [String: Any],
                  let away = raw["Away"] as? [String: Any] else { return nil }

            let status = intValue(raw["MatchStatus"])
            let clock = parseClock(raw["MatchTime"] as? String)
            let phase = phase(status: status, clock: clock, raw: raw)
            return WorldCupMatch(
                id: id,
                homeTeam: localizedName(home["TeamName"]) ?? (home["Abbreviation"] as? String ?? "TBD"),
                awayTeam: localizedName(away["TeamName"]) ?? (away["Abbreviation"] as? String ?? "TBD"),
                homeCode: home["Abbreviation"] as? String ?? "",
                awayCode: away["Abbreviation"] as? String ?? "",
                kickoff: kickoff,
                stage: localizedName(raw["StageName"]) ?? "World Cup",
                phase: phase,
                clockSeconds: clock
            )
        }
    }

    private static func localizedName(_ value: Any?) -> String? {
        guard let names = value as? [[String: Any]] else { return nil }
        return names.first(where: { ($0["Locale"] as? String)?.hasPrefix("en") == true })?["Description"] as? String
            ?? names.first?["Description"] as? String
    }

    private static func intValue(_ value: Any?) -> Int {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return Int(String(describing: value ?? "")) ?? -1
    }

    private static func parseClock(_ value: String?) -> Int? {
        guard let value else { return nil }
        return DelayMath.parseClock(value)
    }

    private static func phase(status: Int, clock: Int?, raw: [String: Any]) -> MatchPhase {
        if status == 0 { return .fullTime }
        if status == 1 { return .scheduled }
        let period = String(describing: raw["Period"] ?? raw["MatchStatusText"] ?? "").lowercased()
        if period.contains("half") { return .halfTime }
        if period.contains("pen") { return .penalties }
        if period.contains("extra") { return .extraTime }
        guard let clock else { return .unknown }
        if clock <= 45 * 60 { return .firstHalf }
        if clock <= 90 * 60 { return .secondHalf }
        return .extraTime
    }
}

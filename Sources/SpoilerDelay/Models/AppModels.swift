import Foundation

struct IncomingMessage: Identifiable, Equatable, Sendable {
    let id: Int64
    let guid: String
    let sender: String
    let chatName: String?
    let body: String
    let receivedAt: Date
}

enum MatchPhase: String, Codable, Sendable {
    case scheduled
    case firstHalf
    case halfTime
    case secondHalf
    case extraTime
    case penalties
    case fullTime
    case unknown

    var label: String {
        switch self {
        case .scheduled: "Upcoming"
        case .firstHalf: "First half"
        case .halfTime: "Half-time"
        case .secondHalf: "Second half"
        case .extraTime: "Extra time"
        case .penalties: "Penalties"
        case .fullTime: "Full-time"
        case .unknown: "Live"
        }
    }
}

struct WorldCupMatch: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let homeTeam: String
    let awayTeam: String
    let homeCode: String
    let awayCode: String
    let kickoff: Date
    let stage: String
    var phase: MatchPhase
    var clockSeconds: Int?

    var title: String { "\(homeTeam) vs \(awayTeam)" }
    var flaggedTitle: String {
        "\(CountryFlag.emoji(for: homeCode)) \(homeTeam) vs \(CountryFlag.emoji(for: awayCode)) \(awayTeam)"
    }

    var estimatedEnd: Date {
        let isKnockout = !stage.localizedCaseInsensitiveContains("group")
        return kickoff.addingTimeInterval(isKnockout ? 3 * 60 * 60 : 2.5 * 60 * 60)
    }
}

enum CountryFlag {
    private static let fifaToISO2: [String: String] = [
        "ALG": "DZ", "ARG": "AR", "AUS": "AU", "AUT": "AT", "BEL": "BE",
        "BIH": "BA", "BRA": "BR", "CAN": "CA", "CIV": "CI", "COL": "CO",
        "COD": "CD", "CPV": "CV", "CRO": "HR", "CUW": "CW", "CZE": "CZ",
        "ECU": "EC", "EGY": "EG", "FRA": "FR", "GER": "DE", "GHA": "GH",
        "HAI": "HT", "IRN": "IR", "IRQ": "IQ", "JOR": "JO", "JPN": "JP",
        "KOR": "KR", "KSA": "SA", "MAR": "MA", "MEX": "MX", "NED": "NL",
        "NOR": "NO", "NZL": "NZ", "PAN": "PA", "PAR": "PY", "POR": "PT",
        "QAT": "QA", "RSA": "ZA", "SEN": "SN", "SUI": "CH", "SWE": "SE",
        "TUN": "TN", "URU": "UY", "USA": "US", "UZB": "UZ", "ESP": "ES"
    ]

    static func emoji(for fifaCode: String) -> String {
        switch fifaCode.uppercased() {
        case "ENG": return subdivisionFlag("gbeng")
        case "SCO": return subdivisionFlag("gbsct")
        case "WAL": return subdivisionFlag("gbwls")
        default:
            guard let iso = fifaToISO2[fifaCode.uppercased()] else { return "⚽️" }
            let scalars = iso.unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }
            return String(String.UnicodeScalarView(scalars))
        }
    }

    private static func subdivisionFlag(_ code: String) -> String {
        var scalars: [UnicodeScalar] = [UnicodeScalar(0x1F3F4)!]
        scalars += code.unicodeScalars.compactMap { UnicodeScalar(0xE0000 + $0.value) }
        scalars.append(UnicodeScalar(0xE007F)!)
        return String(String.UnicodeScalarView(scalars))
    }
}

struct DelaySession: Codable, Equatable, Sendable {
    var match: WorldCupMatch
    var delaySeconds: TimeInterval
    var startedAt: Date
    var fallbackEnd: Date
    var fullTimeDetectedAt: Date?

    var automaticEnd: Date {
        if let fullTimeDetectedAt {
            return fullTimeDetectedAt.addingTimeInterval(delaySeconds + 30)
        }
        return fallbackEnd
    }
}

struct PermissionState: Equatable, Sendable {
    var notificationsAuthorized = false
    var fullDiskAccess = false
    var contactsAuthorized = false
    var launchAtLogin = false
    var nativeMessagesDisabled = false

    var requiredReady: Bool {
        notificationsAuthorized && fullDiskAccess && nativeMessagesDisabled
    }
}

enum DelayMath {
    static let presets: [TimeInterval] = [30, 60, 90, 120, 300]

    static func parseClock(_ value: String) -> Int? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
        if cleaned.contains("+") {
            let parts = cleaned.split(separator: "+")
            guard parts.count == 2,
                  let base = Int(parts[0]),
                  let added = Int(parts[1].split(separator: ":").first ?? "") else { return nil }
            return (base + added) * 60
        }
        let parts = cleaned.split(separator: ":")
        if parts.count == 1, let minutes = Int(parts[0]) { return minutes * 60 }
        guard parts.count == 2, let minutes = Int(parts[0]), let seconds = Int(parts[1]),
              minutes >= 0, seconds >= 0, seconds < 60 else { return nil }
        return minutes * 60 + seconds
    }

    static func calibratedDelay(officialClock: Int, streamClock: String) -> TimeInterval? {
        guard let observed = parseClock(streamClock) else { return nil }
        return TimeInterval(max(0, officialClock - observed))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        let remainder = total % 60
        return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
    }
}

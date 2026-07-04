import Foundation
import XCTest
@testable import SpoilerDelay

final class FIFAMatchFeedTests: XCTestCase {
    func testLiveFeedWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["RUN_FIFA_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set RUN_FIFA_LIVE_TEST=1 to exercise FIFA's public endpoint.")
        }
        let matches = try await FIFAMatchFeed().upcomingMatches(now: .now)
        XCTAssertFalse(matches.isEmpty)
    }

    func testDecodesOnlyWorldCupAndDropsScoreFields() throws {
        let json = """
        {
          "Results": [
            {
              "IdCompetition": "17", "IdSeason": "285023", "IdMatch": "4001",
              "Date": "2026-07-02T23:00:00Z", "MatchStatus": 3, "MatchTime": "84'",
              "HomeTeamScore": 7, "AwayTeamScore": 6,
              "Home": {"Abbreviation":"POR","TeamName":[{"Locale":"en-gb","Description":"Portugal"}]},
              "Away": {"Abbreviation":"CRO","TeamName":[{"Locale":"en-gb","Description":"Croatia"}]},
              "StageName":[{"Locale":"en-gb","Description":"Round of 16"}]
            },
            {
              "IdCompetition": "other", "IdSeason": "285023", "IdMatch": "ignore",
              "Date": "2026-07-02T23:00:00Z", "MatchStatus": 1,
              "Home": {"Abbreviation":"X"}, "Away": {"Abbreviation":"Y"}
            }
          ]
        }
        """
        let matches = try FIFAMatchFeed.decode(data: Data(json.utf8))
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].title, "Portugal vs Croatia")
        XCTAssertEqual(matches[0].homeTeam, "Portugal")
        XCTAssertEqual(matches[0].awayTeam, "Croatia")
        XCTAssertEqual(matches[0].homeCode, "POR")
        XCTAssertEqual(matches[0].awayCode, "CRO")
        XCTAssertEqual(CountryFlag.emoji(for: matches[0].homeCode), "🇵🇹")
        XCTAssertEqual(CountryFlag.emoji(for: matches[0].awayCode), "🇭🇷")
        XCTAssertEqual(matches[0].clockSeconds, 84 * 60)
        XCTAssertEqual(matches[0].phase, .secondHalf)

        let encoded = String(decoding: try JSONEncoder().encode(matches[0]), as: UTF8.self)
        XCTAssertFalse(encoded.localizedCaseInsensitiveContains("score"))
        XCTAssertFalse(encoded.contains("HomeTeamScore"))
    }

    func testMapsCompletedMatchToFullTime() throws {
        let json = """
        {"Results":[{"IdCompetition":"17","IdSeason":"285023","IdMatch":"finished",
        "Date":"2026-07-02T19:00:00Z","MatchStatus":0,"MatchTime":"97'",
        "Home":{"Abbreviation":"ESP"},"Away":{"Abbreviation":"AUT"}}]}
        """
        XCTAssertEqual(try FIFAMatchFeed.decode(data: Data(json.utf8)).first?.phase, .fullTime)
    }
}

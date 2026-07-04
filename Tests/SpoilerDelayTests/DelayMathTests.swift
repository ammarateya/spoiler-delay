import XCTest
@testable import SpoilerDelay

final class DelayMathTests: XCTestCase {
    func testClockParsing() {
        XCTAssertEqual(DelayMath.parseClock("63:24"), 3_804)
        XCTAssertEqual(DelayMath.parseClock("90+4"), 5_640)
        XCTAssertEqual(DelayMath.parseClock("45'"), 2_700)
        XCTAssertNil(DelayMath.parseClock("12:99"))
        XCTAssertNil(DelayMath.parseClock("goal"))
    }

    func testCalibrationNeverCreatesNegativeDelay() {
        XCTAssertEqual(DelayMath.calibratedDelay(officialClock: 4_000, streamClock: "60:00"), 400)
        XCTAssertEqual(DelayMath.calibratedDelay(officialClock: 3_000, streamClock: "60:00"), 0)
    }

    func testSessionEndsAfterFullTimeDelayAndSafetyMargin() {
        let kickoff = Date(timeIntervalSince1970: 1_000)
        let match = WorldCupMatch(
            id: "1", homeTeam: "A", awayTeam: "B", homeCode: "A", awayCode: "B",
            kickoff: kickoff, stage: "Round of 16", phase: .fullTime, clockSeconds: nil
        )
        let detected = Date(timeIntervalSince1970: 10_000)
        let session = DelaySession(
            match: match, delaySeconds: 90, startedAt: kickoff,
            fallbackEnd: kickoff.addingTimeInterval(20_000), fullTimeDetectedAt: detected
        )
        XCTAssertEqual(session.automaticEnd, detected.addingTimeInterval(120))
    }
}

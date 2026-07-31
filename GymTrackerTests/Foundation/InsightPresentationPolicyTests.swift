import XCTest
@testable import GymTracker

final class InsightPresentationPolicyTests: XCTestCase {
    func testEstimatedLoadsUseWholeUnitPrecision() {
        XCTAssertEqual(Formatters.formatEstimatedLoad(63.33), "63")
        XCTAssertEqual(Formatters.formatEstimatedLoad(63.8), "64")
    }

    func testGroupedMetricsKeepOnlyActionablePrecision() {
        let formatted = Formatters.formatGroupedMetric(12_450)
        XCTAssertTrue(formatted == "12,450" || formatted == "12 450" || formatted == "12 450")
        XCTAssertFalse(formatted.contains(".0"))
    }

    func testVolumeTakeawayRequiresEnoughCompletedSessions() {
        XCTAssertEqual(
            StrengthInsightPresentationPolicy.volumeTakeaway(
                sessionCount: 2,
                weeklyVolumes: [100, 0, 0, 0, 120, 0, 0, 0]
            ),
            "Early comparison · completed sessions: 2"
        )
    }

    func testVolumeTakeawayComparesFourWeekWindows() {
        XCTAssertEqual(
            StrengthInsightPresentationPolicy.volumeTakeaway(
                sessionCount: 8,
                weeklyVolumes: [100, 100, 100, 100, 125, 125, 125, 125]
            ),
            "The recent four weeks contained 25% more completed volume than the previous four weeks."
        )
    }
}

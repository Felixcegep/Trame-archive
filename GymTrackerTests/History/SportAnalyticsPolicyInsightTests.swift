import XCTest
@testable import GymTracker

final class SportAnalyticsPolicyInsightTests: XCTestCase {
    func testEvidenceWordingTiersBySessionCount() {
        let policy = StandardStrengthAnalyticsPolicy()

        // 0 sessions => .none, no title, no directional claim
        let zeroInsight = policy.evaluateInsight(sessionCount: 0)
        XCTAssertEqual(zeroInsight.sessionCount, 0)
        XCTAssertNil(zeroInsight.wordingTier)
        XCTAssertEqual(zeroInsight.evidenceLevel, .none)
        XCTAssertFalse(zeroInsight.allowsDirectionalClaim)

        // 1 session => .latestResult, "Latest result", no directional claim
        let oneInsight = policy.evaluateInsight(sessionCount: 1)
        XCTAssertEqual(oneInsight.sessionCount, 1)
        XCTAssertEqual(oneInsight.wordingTier, "Latest result")
        XCTAssertEqual(oneInsight.evidenceLevel, .latestResult)
        XCTAssertFalse(oneInsight.allowsDirectionalClaim)

        // 2-3 sessions => .earlyComparison, "Early comparison", allows directional claim
        for count in [2, 3] {
            let insight = policy.evaluateInsight(sessionCount: count)
            XCTAssertEqual(insight.sessionCount, count)
            XCTAssertEqual(insight.wordingTier, "Early comparison")
            XCTAssertEqual(insight.evidenceLevel, .earlyComparison)
            XCTAssertTrue(insight.allowsDirectionalClaim)
        }

        // 4+ sessions => .trend, "Trend", allows directional claim
        for count in [4, 8, 12] {
            let insight = policy.evaluateInsight(sessionCount: count)
            XCTAssertEqual(insight.sessionCount, count)
            XCTAssertEqual(insight.wordingTier, "Trend")
            XCTAssertEqual(insight.evidenceLevel, .trend)
            XCTAssertTrue(insight.allowsDirectionalClaim)
        }
    }

    func testEveryDisciplinePolicyExposesRequiredExplanatoryMetadata() {
        let policies: [SportAnalyticsPolicy] = [
            StandardStrengthAnalyticsPolicy(),
            OlympicAttemptAnalyticsPolicy(),
            YokeCarryAnalyticsPolicy(),
            FarmersHoldAnalyticsPolicy(),
            StrongmanGeneralEventAnalyticsPolicy(),
            ErgDistanceAnalyticsPolicy(),
            FitnessSimulationAnalyticsPolicy()
        ]

        for policy in policies {
            let insight = policy.evaluateInsight(sessionCount: 3, takeaway: "Test takeaway")
            XCTAssertEqual(insight.sessionCount, 3)
            XCTAssertEqual(insight.wordingTier, "Early comparison")
            XCTAssertFalse(insight.comparisonConditions.isEmpty, "\(type(of: policy)) must expose non-empty comparisonConditions.")
            XCTAssertFalse(insight.excludedEvidence.isEmpty, "\(type(of: policy)) must expose non-empty excludedEvidence.")
            XCTAssertFalse(insight.calculationMethod.isEmpty, "\(type(of: policy)) must expose non-empty calculationMethod.")
            XCTAssertEqual(insight.takeaway, "Test takeaway")
        }
    }

    func testStrengthInsightPresentationPolicyProducesStructuredInsight() {
        let insight = StrengthInsightPresentationPolicy.insight(
            sessionCount: 2,
            weeklyVolumes: [100, 0, 0, 0, 120, 0, 0, 0]
        )
        XCTAssertEqual(insight.sessionCount, 2)
        XCTAssertEqual(insight.wordingTier, "Early comparison")
        XCTAssertEqual(insight.takeaway, "Early comparison · completed sessions: 2")
        XCTAssertFalse(insight.comparisonConditions.isEmpty)
        XCTAssertFalse(insight.excludedEvidence.isEmpty)
        XCTAssertFalse(insight.calculationMethod.isEmpty)
    }
}

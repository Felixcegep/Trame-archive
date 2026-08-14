import XCTest
@testable import GymTracker

final class WeightliftingDashboardPresentationTests: XCTestCase {
    func testEmptyPresentationDoesNotInventFullLiftOrComponentEvidence() {
        let presentation = WeightliftingDashboardPresentation.empty

        XCTAssertEqual(presentation.availability, .empty)
        XCTAssertFalse(presentation.hasFullLiftEvidence)
        XCTAssertFalse(presentation.hasComponentEvidence)
        XCTAssertNil(presentation.fullLiftBest)
        XCTAssertTrue(presentation.componentOutcomes.isEmpty)
    }

    func testComponentEvidenceRemainsSeparateFromFullLiftMetric() {
        let clean = WeightliftingDashboardMetric(
            id: "clean",
            title: "Clean",
            value: "100 kg",
            detail: "Best recorded clean component",
            evidenceAvailable: true
        )
        let presentation = WeightliftingDashboardPresentation(
            availability: .sparse,
            fullLiftBest: nil,
            cleanBest: clean,
            jerkAfterCleanBest: nil,
            attemptSummary: "2 made · 1 missed",
            componentOutcomes: [],
            qualityTrend: nil,
            evidenceNote: "Full-lift evidence is not recorded yet."
        )

        XCTAssertFalse(presentation.hasFullLiftEvidence)
        XCTAssertTrue(presentation.hasComponentEvidence)
        XCTAssertEqual(presentation.cleanBest?.value, "100 kg")
        XCTAssertNil(presentation.fullLiftBest)
    }

    func testUnavailableCountsStayDescriptiveInsteadOfBecomingZero() {
        XCTAssertEqual(WeightliftingEvidenceCount.observed(0).displayText, "0")
        XCTAssertEqual(WeightliftingEvidenceCount.unavailable.displayText, "Not recorded")
    }

    func testRecentAttemptMatrixPreservesParentAndComponentOutcomes() {
        let attempt = WeightliftingComplexOutcome(
            workoutID: UUID(),
            setID: UUID(),
            date: Date(timeIntervalSince1970: 100),
            weight: 95,
            weightType: .kg,
            outcome: .missed,
            liftQuality: .missed,
            components: [
                WeightliftingComponentOutcomeEvidence(
                    exerciseID: UUID(),
                    exerciseNameSnapshot: "Clean",
                    orderIndex: 0,
                    role: .clean,
                    prescribedRepetitions: 1,
                    performedRepetitions: 1,
                    outcome: .completed,
                    liftQuality: .acceptable
                ),
                WeightliftingComponentOutcomeEvidence(
                    exerciseID: UUID(),
                    exerciseNameSnapshot: "Jerk",
                    orderIndex: 1,
                    role: .jerk,
                    prescribedRepetitions: 1,
                    performedRepetitions: 0,
                    outcome: .missed,
                    liftQuality: .missed
                )
            ]
        )
        let projection = WeightliftingAnalyticsProjection(
            bestCompleteSuccessfulLift: nil,
            bestCompleteSuccessfulLiftsByUnit: [],
            cleanSuccess: nil,
            jerkAfterCleanSuccess: nil,
            componentFailureDistribution: [],
            successRatesByIntensityGroup: [],
            complexOutcomes: [attempt],
            qualityTrend: []
        )

        let presentation = WeightliftingDashboardPresentation.make(projection: projection)

        XCTAssertEqual(presentation.recentAttempts.first?.outcome, .missed)
        XCTAssertEqual(presentation.recentAttempts.first?.components, [.completed, .missed])
    }
}

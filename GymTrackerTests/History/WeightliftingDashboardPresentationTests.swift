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
}

import XCTest
@testable import GymTracker

final class TrainingJourneyTimelineTransitionPresentationTests: XCTestCase {
    func testSameDateMarkersStackIntoDeterministicCollisionRows() {
        let day = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        let first = makeMarker(id: "b", date: day, kind: .dominantDisciplineChange)
        let second = makeMarker(id: "a", date: day, kind: .returnToEarlierDiscipline)
        let third = makeMarker(id: "c", date: later, kind: .dominantDisciplineChange)

        let rows = TrainingJourneyTimelineTransitionPresentation.collisionRows([third, first, second])

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].map(\.id), ["a", "b"])
        XCTAssertEqual(rows[1].map(\.id), ["c"])
    }

    func testPresentationDistinguishesDeclaredStructureFromObservedPracticeWithoutCausality() {
        let date = Date(timeIntervalSince1970: 1_000)
        let declared = makeMarker(
            id: "declared",
            date: date,
            kind: .structureChange(from: .fixedPlan, to: .freeTraining),
            state: .observed
        )
        let observed = makeMarker(id: "observed", date: date, kind: .dominantDisciplineChange)

        XCTAssertEqual(
            TrainingJourneyTimelineTransitionPresentation.shortLabel(declared),
            "Declared"
        )
        XCTAssertEqual(
            TrainingJourneyTimelineTransitionPresentation.shortLabel(observed),
            "Observed"
        )
        XCTAssertTrue(
            TrainingJourneyTimelineTransitionPresentation.accessibilityLabel(observed)
                .contains("no causality inferred")
        )
        XCTAssertTrue(
            TrainingJourneyTimelineTransitionPresentation.evidenceSummary(declared)
                .contains("No reason or causal outcome is inferred")
        )
    }

    func testUncertainEvidenceUsesReviewLabelAndRetainsState() {
        let marker = makeMarker(
            id: "uncertain",
            date: Date(timeIntervalSince1970: 1_000),
            kind: .dominantDisciplineChange,
            state: .ambiguousDiscipline
        )

        XCTAssertEqual(TrainingJourneyTimelineTransitionPresentation.shortLabel(marker), "Review")
        XCTAssertTrue(TrainingJourneyTimelineTransitionPresentation.title(marker).contains("Ambiguous discipline evidence"))
        XCTAssertTrue(TrainingJourneyTimelineTransitionPresentation.accessibilityLabel(marker).contains("Descriptive evidence only"))
    }

    private func makeMarker(
        id: String,
        date: Date,
        kind: TrainingJourneyPracticeTransitionKind,
        state: TrainingJourneyPracticeTransitionEvidenceState = .observed
    ) -> TrainingJourneyPracticeTransitionMarker {
        let evidence = TrainingJourneyPracticeTransitionChapterEvidence(
            chapterID: "chapter-\(id)",
            completedWorkouts: 3,
            discipline: .dominant(.generalStrength),
            sourceEvidence: []
        )
        return TrainingJourneyPracticeTransitionMarker(
            id: id,
            date: date,
            normalizedDate: date,
            position: 0.5,
            kind: kind,
            state: state,
            from: evidence,
            to: evidence
        )
    }
}

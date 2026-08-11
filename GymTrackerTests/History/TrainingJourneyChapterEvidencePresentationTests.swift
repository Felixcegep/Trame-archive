import XCTest
@testable import GymTracker

final class TrainingJourneyChapterEvidencePresentationTests: XCTestCase {
    func testPresentationKeepsUnknownSliceAndStableEvidence() {
        let knownWorkoutID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let unknownWorkoutID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let distribution = TrainingJourneyDisciplineDistribution(
            totalEntryCount: 3,
            classifiedEntryCount: 2,
            unknownEntryCount: 1,
            slices: [
                .init(
                    id: "powerlifting|estimatedOneRepMax,load,volume",
                    discipline: .powerlifting,
                    recordKinds: [.load, .estimatedOneRepMax, .volume],
                    entryCount: 2,
                    proportion: 2.0 / 3.0,
                    evidence: [AnalyticsSourceReference(workoutID: knownWorkoutID)]
                ),
                .init(
                    id: "unknown|",
                    discipline: nil,
                    recordKinds: [],
                    entryCount: 1,
                    proportion: 1.0 / 3.0,
                    evidence: [AnalyticsSourceReference(workoutID: unknownWorkoutID)]
                )
            ]
        )

        let presentation = TrainingJourneyChapterEvidencePresentation.make(distribution: distribution)

        XCTAssertEqual(presentation.totalEntryCount, 3)
        XCTAssertEqual(presentation.classifiedEntryCount, 2)
        XCTAssertEqual(presentation.unknownEntryCount, 1)
        XCTAssertEqual(presentation.slices.map(\.title), ["Powerlifting", "Unclassified"])
        XCTAssertEqual(presentation.slices.map(\.evidenceCount), [1, 1])
        XCTAssertEqual(presentation.slices.map(\.evidence.first?.workoutID), [knownWorkoutID, unknownWorkoutID])
    }

    func testSummaryRemainsDescriptiveAndExposesUnknownEvidence() throws {
        let distribution = TrainingJourneyDisciplineDistribution(
            totalEntryCount: 2,
            classifiedEntryCount: 1,
            unknownEntryCount: 1,
            slices: [
                .init(
                    id: "bodybuilding|load,volume",
                    discipline: .bodybuilding,
                    recordKinds: [.load, .volume],
                    entryCount: 1,
                    proportion: 0.5,
                    evidence: []
                ),
                .init(
                    id: "unknown|",
                    discipline: nil,
                    recordKinds: [],
                    entryCount: 1,
                    proportion: 0.5,
                    evidence: []
                )
            ]
        )

        let summary = try XCTUnwrap(
            TrainingJourneyChapterEvidencePresentation.summary(distribution: distribution)
        )

        XCTAssertTrue(summary.contains("2"))
        XCTAssertTrue(summary.contains("Bodybuilding"))
        XCTAssertTrue(summary.contains("unclassified"))
    }
}

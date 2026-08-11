import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION
final class ProgressionReceiptLedgerPresentationTests: XCTestCase {
    func testLegacyOutcomeLabelRemainsExplicit() {
        XCTAssertEqual(
            ProgressionReceiptLedgerPresentation.decisionLabel(.outcomeNotRecorded),
            "Outcome not recorded"
        )
    }

    func testEvidenceLabelsDistinguishRecordedAbsentAndUnreadable() {
        XCTAssertEqual(
            ProgressionReceiptLedgerPresentation.evidenceLabel(.decoded, kind: .performance),
            "Performance evidence recorded"
        )
        XCTAssertEqual(
            ProgressionReceiptLedgerPresentation.evidenceLabel(.absent, kind: .performance),
            "Performance evidence not recorded"
        )
        XCTAssertEqual(
            ProgressionReceiptLedgerPresentation.evidenceLabel(.unreadable, kind: .action),
            "Rule action could not be read"
        )
    }

    func testProposalAndAppliedValueKeepTypedLoadAndStructuralChangesVisible() {
        let proposal = ProgressionReceiptLedgerProjection.Proposal(
            load: 102.5,
            loadUnit: .kg,
            trainingMax: nil,
            estimatedOneRepMax: nil,
            actualOneRepMax: nil,
            stageID: nil,
            variationExerciseID: nil,
            repetitionOffset: 0,
            setCountOffset: 0,
            durationOffset: 0,
            distanceOffset: 0,
            restDurationOffset: 0,
            caloriesOffset: 0,
            waveIndex: 0,
            blockIndex: 0,
            isDeloading: false
        )
        XCTAssertTrue(ProgressionReceiptLedgerPresentation.proposalSummary(proposal).contains("102.5"))
    }
}
#endif

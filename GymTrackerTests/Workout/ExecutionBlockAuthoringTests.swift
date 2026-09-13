import XCTest
@testable import GymTracker

final class ExecutionBlockAuthoringTests: XCTestCase {
    func testFormatFamiliesCoverEveryKindOnce() {
        let kinds = ExecutionBlockAuthoring.FormatFamily.allCases.flatMap(\.kinds)
        XCTAssertEqual(Set(kinds), Set(ExerciseBlockKind.allCases))
        XCTAssertEqual(kinds.count, ExerciseBlockKind.allCases.count)
    }

    func testPairedSetAndGiantSetCounts() {
        XCTAssertFalse(ExecutionBlockAuthoring.meetsExerciseRequirement(1, kind: .pairedSet))
        XCTAssertTrue(ExecutionBlockAuthoring.meetsExerciseRequirement(2, kind: .pairedSet))
        XCTAssertFalse(ExecutionBlockAuthoring.meetsExerciseRequirement(3, kind: .pairedSet))

        XCTAssertFalse(ExecutionBlockAuthoring.meetsExerciseRequirement(3, kind: .giantSet))
        XCTAssertTrue(ExecutionBlockAuthoring.meetsExerciseRequirement(4, kind: .giantSet))
        XCTAssertTrue(ExecutionBlockAuthoring.meetsExerciseRequirement(6, kind: .giantSet))
    }

    func testCircuitAllowsAnyNonEmptySelection() {
        XCTAssertFalse(ExecutionBlockAuthoring.meetsExerciseRequirement(0, kind: .circuit))
        XCTAssertTrue(ExecutionBlockAuthoring.meetsExerciseRequirement(1, kind: .circuit))
        XCTAssertTrue(ExecutionBlockAuthoring.meetsExerciseRequirement(3, kind: .amrap))
    }

    func testSelectionStatusNamesTheExactCountUntilItIsMet() {
        XCTAssertEqual(
            ExecutionBlockAuthoring.selectionStatus(kind: .pairedSet, selected: 0),
            "Choose exactly two exercises."
        )
        XCTAssertEqual(
            ExecutionBlockAuthoring.selectionStatus(kind: .pairedSet, selected: 1),
            "1 of 2 selected"
        )
        XCTAssertEqual(
            ExecutionBlockAuthoring.selectionStatus(kind: .circuit, selected: 2),
            "2 selected"
        )
    }

    func testSaveDisabledReasonExplainsEmptyAndAlreadyGroupedSessions() {
        XCTAssertEqual(
            ExecutionBlockAuthoring.saveDisabledReason(
                kind: .circuit,
                selectedCount: 0,
                availableCount: 0,
                sessionExerciseCount: 0
            ),
            "Add an exercise to this workout first."
        )
        XCTAssertEqual(
            ExecutionBlockAuthoring.saveDisabledReason(
                kind: .circuit,
                selectedCount: 0,
                availableCount: 0,
                sessionExerciseCount: 2
            ),
            "Every exercise is already in a group. Add another exercise to continue."
        )
        XCTAssertNil(
            ExecutionBlockAuthoring.saveDisabledReason(
                kind: .pairedSet,
                selectedCount: 2,
                availableCount: 2,
                sessionExerciseCount: 2
            )
        )
    }

    func testGroupedSubtitlePrefersANamedBlock() {
        XCTAssertEqual(
            ExecutionBlockAuthoring.groupedSubtitle(blockName: "Power circuit", kindTitle: "Circuit"),
            "In Power circuit"
        )
        XCTAssertEqual(
            ExecutionBlockAuthoring.groupedSubtitle(blockName: "  ", kindTitle: "Circuit"),
            "In Circuit"
        )
    }

    func testNewCircuitPreselectsASingleAvailableExercise() {
        XCTAssertTrue(
            ExecutionBlockAuthoring.shouldPreselectSingleAvailableExercise(
                isEditing: false,
                availableCount: 1,
                kind: .circuit
            )
        )
        XCTAssertFalse(
            ExecutionBlockAuthoring.shouldPreselectSingleAvailableExercise(
                isEditing: false,
                availableCount: 1,
                kind: .pairedSet
            )
        )
        XCTAssertFalse(
            ExecutionBlockAuthoring.shouldPreselectSingleAvailableExercise(
                isEditing: true,
                availableCount: 1,
                kind: .circuit
            )
        )
    }
}

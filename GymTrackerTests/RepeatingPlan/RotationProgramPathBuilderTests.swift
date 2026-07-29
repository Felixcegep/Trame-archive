import XCTest
@testable import GymTracker

@MainActor
final class RotationProgramPathBuilderTests: XCTestCase {
    func testBuildUsesCopiedSlotOrderAndProjectsCurrentCursor() {
        let run = makeRun(
            slots: [
                slot(order: 2, name: "Legs"),
                slot(order: 0, name: "Push"),
                slot(order: 1, name: "Pull")
            ],
            currentSlotIndex: 1,
            completedCycleCount: 2
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertEqual(projection.source, .rotation)
        XCTAssertEqual(projection.title, "Test Rotation")
        XCTAssertEqual(projection.currentCycleIndex, 2)
        XCTAssertEqual(projection.currentCycleNumber, 3)
        XCTAssertEqual(projection.completedCycleCount, 2)
        XCTAssertEqual(projection.slotCount, 3)
        XCTAssertEqual(projection.nextWorkout?.workoutName, "Pull")
        XCTAssertEqual(projection.nextWorkout?.slotIndex, 1)
        XCTAssertEqual(projection.currentCycleSlots.map(\.workoutName), ["Push", "Pull", "Legs"])
        XCTAssertEqual(projection.currentCycleSlots.map(\.slotIndex), [0, 1, 2])
        XCTAssertEqual(projection.currentCycleSlots.map(\.isCursor), [false, true, false])
        XCTAssertEqual(
            projection.primaryAction,
            .startExpectedRotationWorkout(runID: run.id)
        )
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testBuildPreservesExpectedAlternateRepeatAndSkipAuditFacts() {
        let start = Date(timeIntervalSince1970: 10)
        let slots = [slot(order: 0, name: "A"), slot(order: 1, name: "B"), slot(order: 2, name: "C")]
        let workout = Workout(name: "Completed A")
        let expected = occurrence(
            cycle: 1,
            expected: 0,
            selected: 0,
            kind: .expected,
            continuation: .continueAfterSelected,
            status: .completed,
            cursorBefore: 0,
            cursorAfter: 1,
            cycleBefore: 1,
            cycleAfter: 1,
            createdAt: start,
            completedWorkout: workout
        )
        let skipped = occurrence(
            cycle: 1,
            expected: 1,
            selected: nil,
            kind: .skip,
            continuation: .continueAfterSelected,
            status: .skipped,
            cursorBefore: 1,
            cursorAfter: 2,
            cycleBefore: 1,
            cycleAfter: 1,
            createdAt: start.addingTimeInterval(1)
        )
        let repeated = occurrence(
            cycle: 1,
            expected: 2,
            selected: 0,
            kind: .repeatWorkout,
            continuation: .keepExpected,
            status: .completed,
            cursorBefore: 2,
            cursorAfter: 2,
            cycleBefore: 1,
            cycleAfter: 1,
            createdAt: start.addingTimeInterval(2)
        )
        let alternate = occurrence(
            cycle: 1,
            expected: 2,
            selected: 0,
            kind: .alternate,
            continuation: .keepExpected,
            status: .completed,
            cursorBefore: 2,
            cursorAfter: 2,
            cycleBefore: 1,
            cycleAfter: 1,
            createdAt: start.addingTimeInterval(3)
        )
        let run = makeRun(
            slots: slots,
            currentSlotIndex: 2,
            completedCycleCount: 1,
            occurrences: [alternate, repeated, skipped, expected]
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertEqual(projection.history.map(\.kind), [.expected, .skip, .repeatWorkout, .alternate])
        XCTAssertEqual(projection.history[0].completedWorkoutID, workout.id)
        XCTAssertEqual(projection.history[1].selectedSlot, nil)
        XCTAssertEqual(projection.history[2].selectedSlot?.workoutName, "A")
        XCTAssertEqual(projection.history[2].continuationMode, .keepExpected)
        XCTAssertEqual(projection.history[3].expectedSlot.workoutName, "C")
        XCTAssertEqual(projection.history[3].selectedSlot?.workoutName, "A")
        XCTAssertTrue(projection.history[3].didAdvance == false)
        XCTAssertEqual(
            projection.currentCycleSlots.map(\.occurrenceState),
            [.completed, .skipped, nil]
        )
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testRestartIsHistoryButNeverMarksASessionCompleted() {
        let restart = occurrence(
            cycle: 0,
            expected: 1,
            selected: nil,
            kind: .restart,
            continuation: .continueAfterSelected,
            status: .completed,
            cursorBefore: 1,
            cursorAfter: 0,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let run = makeRun(
            slots: [slot(order: 0, name: "A"), slot(order: 1, name: "B")],
            currentSlotIndex: 0,
            completedCycleCount: 0,
            occurrences: [restart]
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertEqual(projection.history.map(\.kind), [.restart])
        XCTAssertEqual(projection.currentCycleSlots.map(\.occurrenceState), [nil, nil])
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testUndoneCompletionRemainsInAuditButDoesNotFillCurrentCycle() {
        let workout = Workout(name: "Preserved History")
        let undone = occurrence(
            cycle: 0,
            expected: 0,
            selected: 0,
            kind: .expected,
            continuation: .continueAfterSelected,
            status: .undone,
            cursorBefore: 0,
            cursorAfter: 1,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: Date(timeIntervalSince1970: 10),
            completedWorkout: workout,
            undoneAt: Date(timeIntervalSince1970: 20)
        )
        let run = makeRun(
            slots: [slot(order: 0, name: "A"), slot(order: 1, name: "B")],
            currentSlotIndex: 0,
            completedCycleCount: 0,
            occurrences: [undone]
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertEqual(projection.history[0].status, .undone)
        XCTAssertEqual(projection.history[0].completedWorkoutID, workout.id)
        XCTAssertEqual(projection.history[0].undoneAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(projection.currentCycleSlots.map(\.occurrenceState), [nil, nil])
        XCTAssertEqual(
            projection.primaryAction,
            .startExpectedRotationWorkout(runID: run.id)
        )
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testInProgressAlternateOccupiesSelectedSlotAndSuppressesStart() {
        let activeAlternate = occurrence(
            cycle: 0,
            expected: 1,
            selected: 2,
            kind: .alternate,
            continuation: .keepExpected,
            status: .inProgress,
            cursorBefore: 1,
            cursorAfter: 1,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let run = makeRun(
            slots: [slot(order: 0, name: "A"), slot(order: 1, name: "B"), slot(order: 2, name: "C")],
            currentSlotIndex: 1,
            completedCycleCount: 0,
            occurrences: [activeAlternate]
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertEqual(projection.currentCycleSlots[1].occurrenceState, nil)
        XCTAssertEqual(projection.currentCycleSlots[2].occurrenceState, .inProgress)
        XCTAssertNil(projection.primaryAction)
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testCurrentWorkoutRemainsStartableWhenAnotherFutureTemplateIsUnavailable() {
        let run = makeRun(
            slots: [
                slot(order: 0, name: "Available"),
                slot(order: 1, name: "Deleted future workout", isAvailable: false)
            ],
            currentSlotIndex: 0,
            completedCycleCount: 0
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertEqual(projection.nextWorkout?.workoutName, "Available")
        XCTAssertEqual(
            projection.primaryAction,
            .startExpectedRotationWorkout(runID: run.id)
        )
        XCTAssertEqual(
            projection.warnings,
            [.unavailableTemplate(
                slotID: run.orderedSlots[1].id,
                slotIndex: 1,
                workoutName: "Deleted future workout"
            )]
        )
    }

    func testPausedEndedAndArchivedRunsRetainCursorButDoNotOfferStart() {
        for status in [RepeatingPlanRunStatus.paused, .ended, .archived] {
            let run = makeRun(
                slots: [slot(order: 0, name: "A")],
                currentSlotIndex: 0,
                completedCycleCount: 4,
                status: status
            )

            let projection = RotationProgramPathBuilder.build(run: run)

            XCTAssertEqual(projection.runStatus, status)
            XCTAssertEqual(projection.currentCycleNumber, 5)
            XCTAssertEqual(projection.nextWorkout?.workoutName, "A")
            XCTAssertNil(projection.primaryAction)
        }
    }

    func testBuildReportsInvalidPersistedStateWithoutInventingACursor() {
        let invalidRepeat = occurrence(
            cycle: 0,
            expected: 0,
            selected: 1,
            kind: .repeatWorkout,
            continuation: .continueAfterSelected,
            status: .completed,
            cursorBefore: 0,
            cursorAfter: 0,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let run = makeRun(
            slots: [slot(order: 0, name: "A"), slot(order: 0, name: "B")],
            currentSlotIndex: 4,
            completedCycleCount: -1,
            occurrences: [invalidRepeat]
        )

        let projection = RotationProgramPathBuilder.build(run: run)

        XCTAssertNil(projection.currentSlotIndex)
        XCTAssertNil(projection.nextWorkout)
        XCTAssertNil(projection.primaryAction)
        XCTAssertEqual(projection.currentCycleNumber, 1)
        XCTAssertTrue(projection.warnings.contains(.invalidCompletedCycleCount(-1)))
        XCTAssertTrue(projection.warnings.contains(.invalidCursor(currentSlotIndex: 4, slotCount: 2)))
        XCTAssertTrue(projection.warnings.contains(.duplicateSlotOrder(0)))
        XCTAssertTrue(projection.warnings.contains(.invalidOccurrence(occurrenceID: invalidRepeat.id)))
    }

    private func makeRun(
        slots: [RepeatingPlanRunSlot],
        currentSlotIndex: Int,
        completedCycleCount: Int,
        status: RepeatingPlanRunStatus = .active,
        occurrences: [RepeatingPlanOccurrence] = []
    ) -> RepeatingPlanRun {
        RepeatingPlanRun(
            sourcePlanID: UUID(),
            sourcePlanName: "Test Rotation",
            status: status,
            currentSlotIndex: currentSlotIndex,
            completedCycleCount: completedCycleCount,
            slots: slots,
            occurrences: occurrences
        )
    }

    private func slot(
        order: Int,
        name: String,
        isAvailable: Bool = true
    ) -> RepeatingPlanRunSlot {
        RepeatingPlanRunSlot(
            sourceSlotID: UUID(),
            orderIndex: order,
            templateIDSnapshot: UUID(),
            templateNameSnapshot: name,
            workoutTemplate: isAvailable ? WorkoutTemplate(name: name, exercises: []) : nil
        )
    }

    private func occurrence(
        cycle: Int,
        expected: Int,
        selected: Int?,
        kind: RepeatingPlanOccurrenceKind,
        continuation: RepeatingPlanContinuationMode,
        status: RepeatingPlanOccurrenceStatus,
        cursorBefore: Int,
        cursorAfter: Int,
        cycleBefore: Int,
        cycleAfter: Int,
        createdAt: Date,
        completedWorkout: Workout? = nil,
        undoneAt: Date? = nil
    ) -> RepeatingPlanOccurrence {
        RepeatingPlanOccurrence(
            cycleIndex: cycle,
            expectedSlotIndex: expected,
            selectedSlotIndex: selected,
            kind: kind,
            continuationMode: continuation,
            status: status,
            cursorBefore: cursorBefore,
            cursorAfter: cursorAfter,
            cycleBefore: cycleBefore,
            cycleAfter: cycleAfter,
            createdAt: createdAt,
            completedAt: status == .completed || status == .skipped || status == .undone
                ? createdAt
                : nil,
            undoneAt: undoneAt,
            completedWorkout: completedWorkout
        )
    }
}

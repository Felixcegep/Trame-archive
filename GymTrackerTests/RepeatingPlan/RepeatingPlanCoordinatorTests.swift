import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanCoordinatorTests: XCTestCase {
    func testActivationCopiesSlotsWithoutSavingOrMutatingDefinition() throws {
        let (plan, templates) = makePlan(names: ["Push", "Pull", "Legs"])
        let startedAt = Date(timeIntervalSince1970: 100)

        let run = try RepeatingPlanCoordinator.activate(plan, startedAt: startedAt)

        XCTAssertEqual(run.sourcePlanID, plan.id)
        XCTAssertEqual(run.sourcePlanName, plan.name)
        XCTAssertEqual(run.startedAt, startedAt)
        XCTAssertEqual(run.orderedSlots.map(\.sourceSlotID), plan.orderedSlots.map(\.id))
        XCTAssertEqual(run.orderedSlots.map(\.templateIDSnapshot), templates.map(\.id))
        XCTAssertEqual(run.orderedSlots.map(\.templateNameSnapshot), ["Push", "Pull", "Legs"])
        XCTAssertTrue(plan.runs.contains(where: { $0 === run }))

        plan.name = "Edited PPL"
        plan.slots[0].orderIndex = 2
        plan.slots[2].orderIndex = 0
        templates[0].name = "Edited Push"

        XCTAssertEqual(run.sourcePlanName, "Test Rotation")
        XCTAssertEqual(run.orderedSlots.map(\.templateNameSnapshot), ["Push", "Pull", "Legs"])
        XCTAssertEqual(run.orderedSlots.map(\.orderIndex), [0, 1, 2])
    }

    func testActivationReportsGuidedSourceConflictsWithoutMutatingThem() throws {
        let (plan, _) = makePlan(names: ["A"])
        let fixed = PlanRun(
            sourcePlanID: UUID(),
            sourcePlanName: "Fixed Strength",
            startDate: .now
        )
        let (otherPlan, _) = makePlan(names: ["Other"])
        let repeating = RepeatingPlanRun(plan: otherPlan)

        XCTAssertThrowsError(
            try RepeatingPlanCoordinator.activate(
                plan,
                fixedPlanRuns: [fixed],
                repeatingPlanRuns: [repeating]
            )
        ) { error in
            guard case .activationConflict(let conflicts) = error as? RepeatingPlanCoordinatorError else {
                return XCTFail("Expected a typed activation conflict")
            }
            XCTAssertEqual(conflicts.count, 2)
            XCTAssertTrue(conflicts.contains(.fixedPlan(
                runID: fixed.id,
                planID: fixed.sourcePlanID,
                name: fixed.sourcePlanName
            )))
            XCTAssertTrue(conflicts.contains(.repeatingPlan(
                runID: repeating.id,
                planID: repeating.sourcePlanID,
                name: repeating.sourcePlanName
            )))
        }
        XCTAssertEqual(fixed.status, .active)
        XCTAssertEqual(repeating.status, .active)
        XCTAssertTrue(plan.runs.isEmpty)
    }

    func testExpectedCompletionAdvancesAndWrapsExactlyOnce() throws {
        let (plan, _) = makePlan(names: ["A", "B"])
        let run = try RepeatingPlanCoordinator.activate(plan)

        let first = try RepeatingPlanCoordinator.startExpected(in: run)
        XCTAssertEqual(first.occurrence.expectedSlotIndex, 0)
        XCTAssertEqual(run.currentSlotIndex, 0, "Starting must not advance")
        let firstWorkout = completedWorkout(named: "A")
        XCTAssertEqual(
            try RepeatingPlanCoordinator.complete(first.occurrence, with: firstWorkout, in: run),
            .completed
        )
        XCTAssertEqual(run.currentSlotIndex, 1)
        XCTAssertEqual(run.completedCycleCount, 0)
        XCTAssertEqual(
            try RepeatingPlanCoordinator.complete(first.occurrence, with: firstWorkout, in: run),
            .alreadyCompleted
        )
        XCTAssertEqual(run.currentSlotIndex, 1)

        let second = try RepeatingPlanCoordinator.startExpected(in: run)
        let secondWorkout = completedWorkout(named: "B")
        XCTAssertEqual(
            try RepeatingPlanCoordinator.complete(second.occurrence, with: secondWorkout, in: run),
            .completed
        )
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(run.completedCycleCount, 1)
    }

    func testInvalidCompletionAndDiscardLeaveCursorUnchanged() throws {
        let (plan, _) = makePlan(names: ["A", "B"])
        let run = try RepeatingPlanCoordinator.activate(plan)
        let start = try RepeatingPlanCoordinator.startExpected(in: run)
        let invalidWorkout = Workout(name: "Invalid")

        XCTAssertThrowsError(
            try RepeatingPlanCoordinator.complete(start.occurrence, with: invalidWorkout, in: run)
        ) { error in
            XCTAssertEqual(
                error as? RepeatingPlanCoordinatorError,
                .workoutHasNoCompletedSets
            )
        }
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(start.occurrence.status, .inProgress)

        let discarded = try RepeatingPlanCoordinator.discard(start.occurrence, in: run)
        XCTAssertTrue(discarded === start.occurrence)
        XCTAssertNil(discarded.run)
        XCTAssertTrue(run.occurrences.isEmpty)
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(run.completedCycleCount, 0)
    }

    func testRepeatAndAlternateContinuationModesAreExplicit() throws {
        let (plan, _) = makePlan(names: ["A", "B", "C"])
        let run = try RepeatingPlanCoordinator.activate(plan)

        let expected = try RepeatingPlanCoordinator.startExpected(in: run)
        try RepeatingPlanCoordinator.complete(
            expected.occurrence,
            with: completedWorkout(named: "A"),
            in: run
        )
        XCTAssertEqual(run.currentSlotIndex, 1)

        let repeated = try RepeatingPlanCoordinator.startRepeat(in: run)
        XCTAssertEqual(repeated.occurrence.selectedSlotIndex, 0)
        XCTAssertEqual(repeated.occurrence.continuationMode, .keepExpected)
        try RepeatingPlanCoordinator.complete(
            repeated.occurrence,
            with: completedWorkout(named: "A again"),
            in: run
        )
        XCTAssertEqual(run.currentSlotIndex, 1)

        let keepExpected = try RepeatingPlanCoordinator.startAlternate(
            slotIndex: 2,
            continuationMode: .keepExpected,
            in: run
        )
        try RepeatingPlanCoordinator.complete(
            keepExpected.occurrence,
            with: completedWorkout(named: "C"),
            in: run
        )
        XCTAssertEqual(run.currentSlotIndex, 1)
        XCTAssertEqual(run.completedCycleCount, 0)

        let continueAfter = try RepeatingPlanCoordinator.startAlternate(
            slotIndex: 2,
            continuationMode: .continueAfterSelected,
            in: run
        )
        try RepeatingPlanCoordinator.complete(
            continueAfter.occurrence,
            with: completedWorkout(named: "C again"),
            in: run
        )
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(run.completedCycleCount, 1)
    }

    func testSkipAndUndoRestoreCursorWithoutDeletingWorkoutHistory() throws {
        let (plan, _) = makePlan(names: ["A", "B"])
        let run = try RepeatingPlanCoordinator.activate(plan)
        let first = try RepeatingPlanCoordinator.startExpected(in: run)
        let workout = completedWorkout(named: "A")
        try RepeatingPlanCoordinator.complete(first.occurrence, with: workout, in: run)

        let undoneCompletion = try RepeatingPlanCoordinator.undoLastAdvancement(in: run)
        XCTAssertEqual(undoneCompletion.status, .undone)
        XCTAssertNotNil(undoneCompletion.undoneAt)
        XCTAssertTrue(undoneCompletion.completedWorkout === workout)
        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(run.completedCycleCount, 0)

        let skipped = try RepeatingPlanCoordinator.skip(in: run)
        XCTAssertEqual(skipped.status, .skipped)
        XCTAssertEqual(run.currentSlotIndex, 1)
        XCTAssertEqual(skipped.cursorBefore, 0)
        XCTAssertEqual(skipped.cursorAfter, 1)
        _ = try RepeatingPlanCoordinator.undoLastAdvancement(in: run)
        XCTAssertEqual(skipped.status, .undone)
        XCTAssertEqual(run.currentSlotIndex, 0)
    }

    func testUndoIsRejectedWhenAnActiveOrLaterStateMakesItUnsafe() throws {
        let (plan, _) = makePlan(names: ["A", "B"])
        let run = try RepeatingPlanCoordinator.activate(plan)
        let completed = try RepeatingPlanCoordinator.startExpected(in: run)
        try RepeatingPlanCoordinator.complete(
            completed.occurrence,
            with: completedWorkout(named: "A"),
            in: run
        )
        _ = try RepeatingPlanCoordinator.startExpected(in: run)

        XCTAssertThrowsError(try RepeatingPlanCoordinator.undoLastAdvancement(in: run)) { error in
            XCTAssertEqual(error as? RepeatingPlanCoordinatorError, .unsafeUndo)
        }
        XCTAssertEqual(completed.occurrence.status, .completed)
        XCTAssertEqual(run.currentSlotIndex, 1)
    }

    func testPauseResumeRestartEndAndArchivePreserveOccurrenceHistory() throws {
        let (plan, _) = makePlan(names: ["A", "B"])
        let run = try RepeatingPlanCoordinator.activate(plan)
        let first = try RepeatingPlanCoordinator.startExpected(in: run)
        try RepeatingPlanCoordinator.complete(
            first.occurrence,
            with: completedWorkout(named: "A"),
            in: run
        )
        XCTAssertEqual(run.occurrences.count, 1)

        try RepeatingPlanCoordinator.pause(run)
        XCTAssertEqual(run.status, .paused)
        XCTAssertThrowsError(try RepeatingPlanCoordinator.nextWorkout(in: run))
        try RepeatingPlanCoordinator.resume(run)
        XCTAssertEqual(run.status, .active)
        try RepeatingPlanCoordinator.restart(
            run,
            at: Date(timeIntervalSinceNow: 60)
        )
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(run.completedCycleCount, 0)
        XCTAssertEqual(run.occurrences.count, 2)
        let restart = try XCTUnwrap(run.orderedOccurrences.last)
        XCTAssertEqual(restart.kind, .restart)
        XCTAssertEqual(restart.status, .completed)
        XCTAssertEqual(restart.cursorBefore, 1)
        XCTAssertEqual(restart.cursorAfter, 0)
        XCTAssertEqual(restart.cycleBefore, 0)
        XCTAssertEqual(restart.cycleAfter, 0)
        XCTAssertNil(restart.completedWorkout)

        try RepeatingPlanCoordinator.end(run)
        XCTAssertEqual(run.status, .ended)
        XCTAssertNotNil(run.endedAt)
        XCTAssertEqual(run.occurrences.count, 2)
        try RepeatingPlanCoordinator.archive(run)
        XCTAssertEqual(run.status, .archived)
        XCTAssertEqual(run.occurrences.count, 2)
    }

    func testRestartIsALaterEventThatBlocksUndoButNotRepeatHistory() throws {
        let (plan, _) = makePlan(names: ["A", "B", "C"])
        let run = try RepeatingPlanCoordinator.activate(plan)
        let first = try RepeatingPlanCoordinator.startExpected(in: run)
        try RepeatingPlanCoordinator.complete(
            first.occurrence,
            with: completedWorkout(named: "A"),
            in: run
        )
        let second = try RepeatingPlanCoordinator.startExpected(in: run)
        let secondWorkout = completedWorkout(named: "B")
        try RepeatingPlanCoordinator.complete(
            second.occurrence,
            with: secondWorkout,
            in: run
        )
        XCTAssertEqual(run.currentSlotIndex, 2)

        try RepeatingPlanCoordinator.restart(
            run,
            at: Date(timeIntervalSinceNow: 60)
        )

        XCTAssertThrowsError(try RepeatingPlanCoordinator.undoLastAdvancement(in: run)) { error in
            XCTAssertEqual(error as? RepeatingPlanCoordinatorError, .unsafeUndo)
        }
        XCTAssertEqual(run.currentSlotIndex, 0)
        XCTAssertEqual(second.occurrence.status, .completed)
        XCTAssertTrue(second.occurrence.completedWorkout === secondWorkout)

        let repeated = try RepeatingPlanCoordinator.startRepeat(in: run)
        XCTAssertEqual(repeated.occurrence.kind, .repeatWorkout)
        XCTAssertEqual(repeated.occurrence.selectedSlotIndex, 1)
        XCTAssertEqual(repeated.occurrence.cursorBefore, 0)
        XCTAssertEqual(repeated.occurrence.cursorAfter, 0)
    }

    func testRestartOccurrenceKindHasStableRawValue() {
        XCTAssertEqual(RepeatingPlanOccurrenceKind.restart.rawValue, "restart")
        XCTAssertEqual(RepeatingPlanOccurrenceKind(rawValue: "restart"), .restart)
    }

    func testOnlyOneOccurrenceCanBeInProgressAndActiveRunProjectionIsDeterministic() throws {
        let (plan, _) = makePlan(names: ["A"])
        let older = try RepeatingPlanCoordinator.activate(
            plan,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = RepeatingPlanRun(
            sourcePlanID: plan.id,
            sourcePlanName: plan.name,
            startedAt: Date(timeIntervalSince1970: 200),
            plan: plan,
            slots: plan.orderedSlots.map(RepeatingPlanRunSlot.init(slot:))
        )

        XCTAssertTrue(RepeatingPlanCoordinator.activeRun(in: [older, newer]) === newer)
        _ = try RepeatingPlanCoordinator.startExpected(in: newer)
        XCTAssertThrowsError(try RepeatingPlanCoordinator.startExpected(in: newer)) { error in
            XCTAssertEqual(
                error as? RepeatingPlanCoordinatorError,
                .runHasActiveOccurrence
            )
        }
    }

    private func makePlan(names: [String]) -> (RepeatingPlan, [WorkoutTemplate]) {
        let templates = names.map { WorkoutTemplate(name: $0, exercises: []) }
        let slots = templates.enumerated().map {
            RepeatingPlanSlot(orderIndex: $0.offset, workoutTemplate: $0.element)
        }
        return (RepeatingPlan(name: "Test Rotation", slots: slots), templates)
    }

    private func completedWorkout(named name: String) -> Workout {
        let exercise = WorkoutTestFixture.makeExercise()
        let workout = WorkoutTestFixture.makeWorkout(with: exercise)
        workout.name = name
        return workout
    }
}

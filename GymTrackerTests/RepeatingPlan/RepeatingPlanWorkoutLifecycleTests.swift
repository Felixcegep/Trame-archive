import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanWorkoutLifecycleTests: XCTestCase {
    func testStartPersistsWorkoutAndOccurrenceTogetherWithoutAdvancing() throws {
        let fixture = try makeFixture(targetSets: 1)
        let viewModel = WorkoutViewModel()

        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))

        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)
        XCTAssertEqual(occurrence.status, .inProgress)
        XCTAssertEqual(occurrence.expectedSlotIndex, 0)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
        XCTAssertEqual(workout.sourceRepeatingPlanID, fixture.plan.id)
        XCTAssertEqual(workout.sourceRepeatingPlanRunID, fixture.run.id)
        XCTAssertEqual(workout.sourceRepeatingPlanOccurrenceID, occurrence.id)
        XCTAssertEqual(workout.sourceRepeatingPlanName, fixture.plan.name)
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .active }.count,
            1
        )
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<RepeatingPlanOccurrence>()).count,
            1
        )
    }

    func testFinishAdvancesExactlyOnceAndLinksCompletedHistory() throws {
        let fixture = try makeFixture(names: ["Push", "Pull"], targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)
        completeFirstSet(in: workout)

        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        XCTAssertFalse(viewModel.saveWorkout(using: fixture.context))

        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(occurrence.status, .completed)
        XCTAssertEqual(occurrence.completedWorkout?.id, workout.id)
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .completed }.count,
            1
        )
    }

    func testPartialValidSavePrunesIncompleteSetsAndAdvances() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 2)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 2)
        completeFirstSet(in: workout)

        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))

        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 1)
        XCTAssertTrue(workout.orderedExercises.first?.orderedSets.first?.done == true)
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)
        XCTAssertEqual(fixture.run.orderedOccurrences.first?.status, .completed)
    }

    func testInvalidSaveLeavesDraftOccurrenceAndCursorUntouched() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 2)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)

        XCTAssertFalse(viewModel.saveWorkout(using: fixture.context))

        XCTAssertTrue(viewModel.activeWorkout === workout)
        XCTAssertEqual(workout.status, .active)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 2)
        XCTAssertEqual(occurrence.status, .inProgress)
        XCTAssertNil(occurrence.completedWorkout)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
    }

    func testDiscardDeletesWorkoutAndOccurrenceWithoutAdvancing() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workoutID = try XCTUnwrap(viewModel.activeWorkout?.id)
        let occurrenceID = try XCTUnwrap(fixture.run.orderedOccurrences.first?.id)

        viewModel.discardActiveWorkout(using: fixture.context)

        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
        XCTAssertFalse(
            try fixture.context.fetch(FetchDescriptor<Workout>()).contains { $0.id == workoutID }
        )
        XCTAssertFalse(
            try fixture.context.fetch(FetchDescriptor<RepeatingPlanOccurrence>())
                .contains { $0.id == occurrenceID }
        )
    }

    func testRelaunchRestoresOnlyWorkoutWithMatchingInProgressOccurrence() throws {
        let fixture = try makeFixture(targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workoutID = try XCTUnwrap(viewModel.activeWorkout?.id)
        let occurrenceID = try XCTUnwrap(fixture.run.orderedOccurrences.first?.id)

        let restoreContext = ModelContext(fixture.container)
        let restoredViewModel = WorkoutViewModel()
        XCTAssertTrue(restoredViewModel.restoreActiveWorkout(using: restoreContext))
        XCTAssertEqual(restoredViewModel.activeWorkout?.id, workoutID)
        XCTAssertEqual(restoredViewModel.activeWorkout?.sourceRepeatingPlanOccurrenceID, occurrenceID)
        let restoredOccurrence = try XCTUnwrap(
            restoreContext.fetch(FetchDescriptor<RepeatingPlanOccurrence>())
                .first { $0.id == occurrenceID }
        )
        XCTAssertEqual(restoredOccurrence.status, .inProgress)
        XCTAssertEqual(restoredOccurrence.run?.id, fixture.run.id)
    }

    func testCompletedHistorySurvivesSourceArchivalAndEdits() throws {
        let fixture = try makeFixture(names: ["Original A", "B"], targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)
        completeFirstSet(in: workout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))

        fixture.plan.isArchived = true
        fixture.plan.name = "Edited Definition"
        fixture.templates[0].name = "Edited Template"
        try fixture.context.save()

        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(workout.name, "Original A")
        XCTAssertEqual(workout.sourceRepeatingPlanID, fixture.plan.id)
        XCTAssertEqual(workout.sourceRepeatingPlanRunID, fixture.run.id)
        XCTAssertEqual(workout.sourceRepeatingPlanOccurrenceID, occurrence.id)
        XCTAssertEqual(workout.sourceRepeatingPlanName, "Test Rotation")
        XCTAssertEqual(occurrence.status, .completed)
        XCTAssertEqual(occurrence.completedWorkout?.id, workout.id)
        XCTAssertEqual(fixture.run.sourcePlanName, "Test Rotation")
    }

    func testTypedRepeatStartPersistsWorkoutAndKeepsExpectedCursor() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let firstWorkout = try XCTUnwrap(viewModel.activeWorkout)
        completeFirstSet(in: firstWorkout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)

        XCTAssertTrue(viewModel.startWorkout(
            from: fixture.run,
            command: .repeatLast,
            using: fixture.context
        ))

        let repeatedWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let repeatedOccurrence = try XCTUnwrap(fixture.run.orderedOccurrences.last)
        XCTAssertEqual(repeatedWorkout.name, "A")
        XCTAssertEqual(repeatedOccurrence.kind, .repeatWorkout)
        XCTAssertEqual(repeatedOccurrence.expectedSlotIndex, 1)
        XCTAssertEqual(repeatedOccurrence.selectedSlotIndex, 0)
        XCTAssertEqual(repeatedOccurrence.cursorBefore, 1)
        XCTAssertEqual(repeatedOccurrence.cursorAfter, 1)
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .active }.count,
            1
        )

        completeFirstSet(in: repeatedWorkout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)
        XCTAssertEqual(repeatedOccurrence.status, .completed)
    }

    func testTypedAlternateStartPersistsChoiceAndAdvancesOnlyAfterSave() throws {
        let fixture = try makeFixture(names: ["A", "B", "C"], targetSets: 1)
        let viewModel = WorkoutViewModel()

        XCTAssertTrue(viewModel.startWorkout(
            from: fixture.run,
            command: .alternate(
                slotIndex: 2,
                continuationMode: .continueAfterSelected
            ),
            using: fixture.context
        ))

        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.last)
        XCTAssertEqual(workout.name, "C")
        XCTAssertEqual(occurrence.kind, .alternate)
        XCTAssertEqual(occurrence.expectedSlotIndex, 0)
        XCTAssertEqual(occurrence.selectedSlotIndex, 2)
        XCTAssertEqual(occurrence.continuationMode, .continueAfterSelected)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)

        completeFirstSet(in: workout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 1)
        XCTAssertEqual(occurrence.status, .completed)
    }

    func testInvalidTypedStartRollsBackOccurrenceAndWorkoutTogether() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 1)
        let viewModel = WorkoutViewModel()

        XCTAssertFalse(viewModel.startWorkout(
            from: fixture.run,
            command: .alternate(
                slotIndex: 99,
                continuationMode: .keepExpected
            ),
            using: fixture.context
        ))

        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertTrue(fixture.run.orderedOccurrences.isEmpty)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertTrue(
            try fixture.context.fetch(FetchDescriptor<RepeatingPlanOccurrence>()).isEmpty
        )
        XCTAssertTrue(
            try fixture.context.fetch(FetchDescriptor<Workout>()).isEmpty
        )
    }

    func testRestartEventPersistsWithoutChangingCompletedWorkoutHistory() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let completedWorkout = try XCTUnwrap(viewModel.activeWorkout)
        completeFirstSet(in: completedWorkout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))

        try RepeatingPlanCoordinator.restart(
            fixture.run,
            at: Date(timeIntervalSinceNow: 60)
        )
        try fixture.context.save()

        let verificationContext = ModelContext(fixture.container)
        let restoredRun = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<RepeatingPlanRun>())
                .first { $0.id == fixture.run.id }
        )
        let restart = try XCTUnwrap(restoredRun.orderedOccurrences.last)
        XCTAssertEqual(restart.kind, .restart)
        XCTAssertEqual(restart.status, .completed)
        XCTAssertEqual(restart.cursorBefore, 1)
        XCTAssertEqual(restart.cursorAfter, 0)
        XCTAssertEqual(restoredRun.currentSlotIndex, 0)
        XCTAssertTrue(
            try verificationContext.fetch(FetchDescriptor<Workout>())
                .contains { $0.id == completedWorkout.id && $0.status == .completed }
        )
    }

    func testSafeUndoRejectsAnyActiveWorkoutThenPersistsWithoutChangingHistory() throws {
        let fixture = try makeFixture(names: ["A", "B"], targetSets: 1)
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let completedWorkout = try XCTUnwrap(viewModel.activeWorkout)
        completeFirstSet(in: completedWorkout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.last)
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)

        let blockingWorkout = Workout(name: "Other Active Workout")
        fixture.context.insert(blockingWorkout)
        try fixture.context.save()

        XCTAssertFalse(viewModel.undoLastRepeatingPlanAdvancement(
            in: fixture.run,
            using: fixture.context
        ))
        XCTAssertEqual(occurrence.status, .completed)
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)

        blockingWorkout.status = .completed
        blockingWorkout.endTime = .now
        try fixture.context.save()

        XCTAssertTrue(viewModel.undoLastRepeatingPlanAdvancement(
            in: fixture.run,
            using: fixture.context
        ))
        XCTAssertEqual(occurrence.status, .undone)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(completedWorkout.status, .completed)
        XCTAssertEqual(occurrence.completedWorkout?.id, completedWorkout.id)

        let verificationContext = ModelContext(fixture.container)
        let restoredRun = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<RepeatingPlanRun>())
                .first { $0.id == fixture.run.id }
        )
        XCTAssertEqual(restoredRun.currentSlotIndex, 0)
        XCTAssertEqual(restoredRun.orderedOccurrences.last?.status, .undone)
        XCTAssertTrue(
            try verificationContext.fetch(FetchDescriptor<Workout>())
                .contains { $0.id == completedWorkout.id && $0.status == .completed }
        )
    }

    private func makeFixture(
        names: [String] = ["A"],
        targetSets: Int
    ) throws -> Fixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = WorkoutTestFixture.makeExercise()
        let templates = names.map { name -> WorkoutTemplate in
            let template = WorkoutTestFixture.makeTemplate(
                exercise: exercise,
                targetSets: targetSets
            )
            template.name = name
            return template
        }
        let plan = RepeatingPlan(
            name: "Test Rotation",
            slots: templates.enumerated().map {
                RepeatingPlanSlot(orderIndex: $0.offset, workoutTemplate: $0.element)
            }
        )

        context.insert(exercise)
        for template in templates {
            context.insert(template)
        }
        context.insert(plan)
        try context.save()

        let run = try RepeatingPlanCoordinator.activate(plan)
        context.insert(run)
        try context.save()
        return Fixture(
            container: container,
            context: context,
            plan: plan,
            run: run,
            templates: templates
        )
    }

    private func completeFirstSet(in workout: Workout) {
        guard let set = workout.orderedExercises.first?.orderedSets.first else {
            return XCTFail("Expected a snapshotted set")
        }
        set.repetitions = 8
        set.weight = 50
        set.done = true
    }
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let context: ModelContext
    let plan: RepeatingPlan
    let run: RepeatingPlanRun
    let templates: [WorkoutTemplate]
}

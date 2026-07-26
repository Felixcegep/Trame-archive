import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanMobilityLifecycleTests: XCTestCase {
    func testWarmupAndCooldownContextAndWorkoutIDPersistFromRunSlotLinks() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let runSlot = try XCTUnwrap(fixture.run.orderedSlots.first)

        let warmup = try XCTUnwrap(MobilitySessionService.start(
            routine: try XCTUnwrap(runSlot.preWorkoutMobilityRoutine),
            context: .warmup,
            workoutID: workout.id,
            using: fixture.context
        ))
        XCTAssertTrue(MobilitySessionService.completeCurrent(
            in: warmup,
            performedRepetitions: 5,
            using: fixture.context
        ))
        completeFirstSet(in: workout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        XCTAssertEqual(workout.status, .completed)

        let cooldown = try XCTUnwrap(MobilitySessionService.start(
            routine: try XCTUnwrap(runSlot.postWorkoutMobilityRoutine),
            context: .cooldown,
            workoutID: workout.id,
            using: fixture.context
        ))
        XCTAssertTrue(MobilitySessionService.stop(cooldown, using: fixture.context))

        let verificationContext = ModelContext(fixture.container)
        let sessions = try verificationContext.fetch(FetchDescriptor<MobilitySession>())
        let storedWarmup = try XCTUnwrap(sessions.first { $0.id == warmup.id })
        let storedCooldown = try XCTUnwrap(sessions.first { $0.id == cooldown.id })

        XCTAssertEqual(storedWarmup.context, .warmup)
        XCTAssertEqual(storedWarmup.workoutID, workout.id)
        XCTAssertEqual(storedWarmup.sourceRoutineID, fixture.warmupRoutine.id)
        XCTAssertEqual(storedWarmup.status, .completed)
        XCTAssertEqual(storedCooldown.context, .cooldown)
        XCTAssertEqual(storedCooldown.workoutID, workout.id)
        XCTAssertEqual(storedCooldown.sourceRoutineID, fixture.cooldownRoutine.id)
        XCTAssertEqual(storedCooldown.status, .stopped)
    }

    func testMobilityCompletionStopAndSkipDoNotMutateOccurrenceOrCursor() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workoutID = try XCTUnwrap(viewModel.activeWorkout?.id)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)

        let completed = try XCTUnwrap(MobilitySessionService.start(
            routine: fixture.warmupRoutine,
            context: .warmup,
            workoutID: workoutID,
            using: fixture.context
        ))
        XCTAssertTrue(MobilitySessionService.completeCurrent(
            in: completed,
            performedRepetitions: 5,
            using: fixture.context
        ))
        assertUnadvanced(fixture.run, occurrence: occurrence)

        let stopped = try XCTUnwrap(MobilitySessionService.start(
            routine: fixture.warmupRoutine,
            context: .warmup,
            workoutID: workoutID,
            using: fixture.context
        ))
        XCTAssertTrue(MobilitySessionService.stop(stopped, using: fixture.context))
        assertUnadvanced(fixture.run, occurrence: occurrence)

        let skipped = try XCTUnwrap(MobilitySessionService.start(
            routine: fixture.warmupRoutine,
            context: .warmup,
            workoutID: workoutID,
            using: fixture.context
        ))
        XCTAssertTrue(MobilitySessionService.skipCurrent(in: skipped, using: fixture.context))
        assertUnadvanced(fixture.run, occurrence: occurrence)

        let verificationContext = ModelContext(fixture.container)
        let storedRun = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<RepeatingPlanRun>())
                .first { $0.id == fixture.run.id }
        )
        let storedOccurrence = try XCTUnwrap(
            storedRun.orderedOccurrences.first { $0.id == occurrence.id }
        )
        assertUnadvanced(storedRun, occurrence: storedOccurrence)
    }

    func testOnlySuccessfullySavedWorkoutAdvancesAfterMobility() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)

        let warmup = try XCTUnwrap(MobilitySessionService.start(
            routine: fixture.warmupRoutine,
            context: .warmup,
            workoutID: workout.id,
            using: fixture.context
        ))
        XCTAssertTrue(MobilitySessionService.completeCurrent(
            in: warmup,
            performedRepetitions: 5,
            using: fixture.context
        ))
        assertUnadvanced(fixture.run, occurrence: occurrence)

        XCTAssertFalse(viewModel.saveWorkout(using: fixture.context))
        assertUnadvanced(fixture.run, occurrence: occurrence)

        completeFirstSet(in: workout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        XCTAssertEqual(fixture.run.currentSlotIndex, 1)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
        XCTAssertEqual(occurrence.status, .completed)
        XCTAssertEqual(occurrence.completedWorkout?.id, workout.id)
    }

    func testDiscardLeavesCursorUnchangedAndDoesNotDeleteActiveMobility() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workoutID = try XCTUnwrap(viewModel.activeWorkout?.id)
        let occurrenceID = try XCTUnwrap(fixture.run.orderedOccurrences.first?.id)
        let mobility = try XCTUnwrap(MobilitySessionService.start(
            routine: fixture.warmupRoutine,
            context: .warmup,
            workoutID: workoutID,
            using: fixture.context
        ))

        viewModel.discardActiveWorkout(using: fixture.context)

        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
        XCTAssertFalse(
            try fixture.context.fetch(FetchDescriptor<RepeatingPlanOccurrence>())
                .contains { $0.id == occurrenceID }
        )
        XCTAssertFalse(
            try fixture.context.fetch(FetchDescriptor<Workout>())
                .contains { $0.id == workoutID }
        )
        let persistedMobility = try XCTUnwrap(MobilitySessionService.activeSession(using: fixture.context))
        XCTAssertEqual(persistedMobility.id, mobility.id)
        XCTAssertEqual(persistedMobility.workoutID, workoutID)
        XCTAssertEqual(persistedMobility.status, .active)
    }

    func testRelaunchRestoresActiveMobilityAndActiveWorkoutIndependently() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workoutID = try XCTUnwrap(viewModel.activeWorkout?.id)
        let occurrenceID = try XCTUnwrap(fixture.run.orderedOccurrences.first?.id)
        let mobility = try XCTUnwrap(MobilitySessionService.start(
            routine: fixture.warmupRoutine,
            context: .warmup,
            workoutID: workoutID,
            using: fixture.context
        ))

        let restoreContext = ModelContext(fixture.container)
        let restoredViewModel = WorkoutViewModel()
        XCTAssertTrue(restoredViewModel.restoreActiveWorkout(using: restoreContext))
        let restoredMobility = try XCTUnwrap(MobilitySessionService.activeSession(using: restoreContext))

        XCTAssertEqual(restoredViewModel.activeWorkout?.id, workoutID)
        XCTAssertEqual(
            restoredViewModel.activeWorkout?.sourceRepeatingPlanOccurrenceID,
            occurrenceID
        )
        XCTAssertEqual(restoredMobility.id, mobility.id)
        XCTAssertEqual(restoredMobility.context, .warmup)
        XCTAssertEqual(restoredMobility.workoutID, workoutID)

        XCTAssertTrue(MobilitySessionService.stop(restoredMobility, using: restoreContext))

        let workoutOnlyContext = ModelContext(fixture.container)
        let workoutOnlyViewModel = WorkoutViewModel()
        XCTAssertTrue(workoutOnlyViewModel.restoreActiveWorkout(using: workoutOnlyContext))
        XCTAssertEqual(workoutOnlyViewModel.activeWorkout?.id, workoutID)
        XCTAssertNil(MobilitySessionService.activeSession(using: workoutOnlyContext))
        let storedRun = try XCTUnwrap(
            workoutOnlyContext.fetch(FetchDescriptor<RepeatingPlanRun>())
                .first { $0.id == fixture.run.id }
        )
        XCTAssertEqual(storedRun.currentSlotIndex, 0)
        XCTAssertEqual(
            storedRun.orderedOccurrences.first { $0.id == occurrenceID }?.status,
            .inProgress
        )
    }

    private func makeFixture() throws -> MobilityLifecycleFixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = WorkoutTestFixture.makeExercise()
        let warmupDefinition = MobilityDefinition(
            name: "Lifecycle Warmup Movement",
            trackingType: .repetitions,
            defaultDurationSeconds: nil,
            defaultRepetitions: 5
        )
        let cooldownDefinition = MobilityDefinition(
            name: "Lifecycle Cooldown Movement",
            defaultDurationSeconds: 30
        )
        let warmupRoutine = MobilityRoutine(name: "Lifecycle Warmup")
        warmupRoutine.items = [
            MobilityRoutineItem(
                definition: warmupDefinition,
                orderIndex: 0,
                targetRepetitions: 5
            )
        ]
        let cooldownRoutine = MobilityRoutine(name: "Lifecycle Cooldown")
        cooldownRoutine.items = [
            MobilityRoutineItem(
                definition: cooldownDefinition,
                orderIndex: 0,
                targetDurationSeconds: 30
            )
        ]

        let firstTemplate = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        firstTemplate.name = "Mobility Linked A"
        firstTemplate.preWorkoutMobilityRoutine = warmupRoutine
        firstTemplate.postWorkoutMobilityRoutine = cooldownRoutine
        let secondTemplate = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        secondTemplate.name = "Mobility Linked B"
        let plan = RepeatingPlan(
            name: "Mobility Lifecycle Rotation",
            slots: [
                RepeatingPlanSlot(orderIndex: 0, workoutTemplate: firstTemplate),
                RepeatingPlanSlot(orderIndex: 1, workoutTemplate: secondTemplate)
            ]
        )

        context.insert(exercise)
        context.insert(warmupDefinition)
        context.insert(cooldownDefinition)
        context.insert(warmupRoutine)
        context.insert(cooldownRoutine)
        context.insert(firstTemplate)
        context.insert(secondTemplate)
        context.insert(plan)
        try context.save()

        let run = try RepeatingPlanCoordinator.activate(plan)
        context.insert(run)
        try context.save()
        return MobilityLifecycleFixture(
            container: container,
            context: context,
            run: run,
            warmupRoutine: warmupRoutine,
            cooldownRoutine: cooldownRoutine
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

    private func assertUnadvanced(
        _ run: RepeatingPlanRun,
        occurrence: RepeatingPlanOccurrence,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(run.currentSlotIndex, 0, file: file, line: line)
        XCTAssertEqual(run.completedCycleCount, 0, file: file, line: line)
        XCTAssertEqual(occurrence.status, .inProgress, file: file, line: line)
        XCTAssertNil(occurrence.completedWorkout, file: file, line: line)
    }
}

@MainActor
private struct MobilityLifecycleFixture {
    let container: ModelContainer
    let context: ModelContext
    let run: RepeatingPlanRun
    let warmupRoutine: MobilityRoutine
    let cooldownRoutine: MobilityRoutine
}

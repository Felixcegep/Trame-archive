import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutIntentServiceTests: XCTestCase {
    func testLogCurrentSetPersistsValuesStartsRestAndKeepsOneEffortMeasure() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        // Explicit, distinct order indices: both defaulting to 0 makes which
        // one `WorkoutSetSelector` treats as "current" depend on an
        // unspecified tiebreak (persistent identity hash), not intent.
        let set = ExerciseSet(repetitions: 0, weight: 0, orderIndex: 0, usedMetric: .metric)
        let nextSet = ExerciseSet(repetitions: 8, weight: 100, orderIndex: 1, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set, nextSet], usedMetric: .metric)
        let workout = Workout(name: "Shortcut workout")
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()

        let result = ActiveWorkoutMutationService(modelContext: context, defaultRestSeconds: 90)
            .logCurrentSet(
                workoutID: workout.id,
                log: .init(repetitions: 8, weight: 100, rpe: 8.5)
            )

        guard case .applied = result else {
            return XCTFail("Expected current-set logging to persist")
        }
        XCTAssertTrue(set.done)
        XCTAssertEqual(set.repetitions, 8)
        XCTAssertEqual(set.weight, 100)
        XCTAssertEqual(set.rpe, 8.5)
        XCTAssertNil(set.rir)
        XCTAssertNotNil(workout.restEndDate)
    }

    func testLogCurrentSetRejectsConflictingEffortWithoutMutatingTheSet() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let set = ExerciseSet(repetitions: 8, weight: 100, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Shortcut workout")
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()

        let result = ActiveWorkoutMutationService(modelContext: context)
            .logCurrentSet(workoutID: workout.id, log: .init(rpe: 8, rir: 2))

        guard case .invalid = result else {
            return XCTFail("Expected conflicting RPE/RIR to be rejected")
        }
        XCTAssertFalse(set.done)
        XCTAssertNil(set.rpe)
        XCTAssertNil(set.rir)
    }

    func testStartTodayResumesInsteadOfCreatingASecondActiveWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let existing = Workout(name: "Existing")
        context.insert(existing)
        try context.save()

        let returned = WorkoutIntentService.startToday(using: context)
        let active = try context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .active }

        XCTAssertEqual(returned?.id, existing.id)
        XCTAssertEqual(active.count, 1)
    }

    func testIntentRouteIsConsumedOnlyOnce() {
        let store = AppIntentRouteStore.shared
        _ = store.consume()
        let workoutID = UUID()
        store.submit(.activeWorkout(workoutID))

        XCTAssertEqual(store.consume(), .activeWorkout(workoutID))
        XCTAssertNil(store.consume())
    }

    func testTodayProjectionReturnsNoWorkoutWhenNothingIsScheduled() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        let projection = WorkoutIntentProjectionService.todayPlan(using: context)

        XCTAssertEqual(projection.state, .noWorkout)
        XCTAssertTrue(projection.exercises.isEmpty)
    }

    func testTodayProjectionPrefersTheActiveWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let set = ExerciseSet(repetitions: 8, weight: 100, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Active workout")
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()

        let projection = WorkoutIntentProjectionService.todayPlan(using: context)

        XCTAssertEqual(projection.state, .activeWorkout)
        XCTAssertEqual(projection.title, "Active workout")
        XCTAssertEqual(projection.exercises.first?.name, "Bench Press")
        XCTAssertTrue(projection.exercises.first?.isCurrent == true)
    }

    func testStartFreeWorkoutCreatesThenResumesTheSingleActiveWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        let first = WorkoutIntentService.startFree(using: context)
        let second = WorkoutIntentService.startFree(using: context)
        let active = try context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .active }

        guard case .started(let firstWorkout) = first else {
            return XCTFail("Expected a new free workout")
        }
        guard case .resumed(let secondWorkout) = second else {
            return XCTFail("Expected the active workout to be resumed")
        }
        XCTAssertEqual(firstWorkout.id, secondWorkout.id)
        XCTAssertEqual(active.count, 1)
    }

    func testWeeklyVolumeUsesCompletedEligibleWorkingSetsOnly() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let working = ExerciseSet(repetitions: 10, weight: 100, done: true, usedMetric: .metric)
        let warmup = ExerciseSet(repetitions: 10, weight: 40, done: true, usedMetric: .metric)
        warmup.setType = .warmup
        let entry = ExerciseEntry(exercise: exercise, sets: [working, warmup], usedMetric: .metric)
        let workout = Workout(name: "Completed", endTime: .now)
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()

        let projection = WorkoutIntentProjectionService.weeklyVolume(
            using: context,
            preferredUnit: .kg
        )

        XCTAssertEqual(projection.completedWorkoutCount, 1)
        XCTAssertEqual(projection.workingSetCount, 1)
        XCTAssertEqual(try XCTUnwrap(projection.loadVolume), 1_000, accuracy: Float(0.001))
        XCTAssertEqual(projection.unit, .kg)
    }

    func testAppShortcutsExposeTheExpandedWorkoutActions() {
        // Apple caps the number of app shortcuts an `AppShortcutsProvider`
        // may vend at 10 (App Intents documentation: "provide up to ten
        // total App Shortcuts"). This literal encodes that hard platform
        // limit, not an incidental headcount that should track catalog
        // growth — GymTrackerAppShortcuts is already at the ceiling, so
        // this test doubles as a reminder that adding an eleventh shortcut
        // requires retiring one of the existing ten first.
        //
        // `AppShortcut` does not expose its phrases/title/icon for runtime
        // introspection (they are consumed by the App Intents result
        // builder at declaration time only), so the count is the only
        // property this test can assert against; the shortcut declarations
        // themselves are reviewed by hand in
        // `GymTrackerWorkoutIntents.swift`.
        XCTAssertEqual(GymTrackerAppShortcuts.appShortcuts.count, 10, "GymTrackerAppShortcuts must stay at or under Apple's 10-shortcut limit for AppShortcutsProvider")
    }
}

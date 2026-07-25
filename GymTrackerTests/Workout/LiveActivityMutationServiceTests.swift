import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class LiveActivityMutationServiceTests: XCTestCase {
    func testExpiredRestIntervalIsNotRepresentedAsAnInvalidRange() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNil(LiveActivityTimeRange.restInterval(now: now, end: now))
        XCTAssertNil(LiveActivityTimeRange.restInterval(now: now, end: now.addingTimeInterval(-1)))
        XCTAssertEqual(
            LiveActivityTimeRange.restInterval(now: now, end: now.addingTimeInterval(30)),
            now...now.addingTimeInterval(30)
        )
    }

    func testCompletingExpectedCurrentSetStartsRestAndProjectsNextSet() throws {
        let context = try makeContext()
        let fixture = try makeActiveWorkout(in: context, firstSetRepetitions: 8)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let service = ActiveWorkoutMutationService(modelContext: context, defaultRestSeconds: 20)

        let result = service.completeCurrentSet(
            workoutID: fixture.workout.id,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0,
            now: now
        )

        guard case let .applied(projection) = result else {
            return XCTFail("Expected the current set to complete")
        }

        XCTAssertTrue(fixture.firstSet.done)
        XCTAssertFalse(fixture.secondSet.done)
        XCTAssertEqual(fixture.workout.restEndDate, now.addingTimeInterval(90))
        XCTAssertNil(fixture.workout.pausedRemainingTime)
        XCTAssertEqual(projection.currentSet, 2)
        XCTAssertEqual(projection.currentSetOrderIndex, 1)
        XCTAssertEqual(projection.restPhase, .running)
    }

    func testStaleCompleteActionDoesNotCompleteTheNextSet() throws {
        let context = try makeContext()
        let fixture = try makeActiveWorkout(in: context, firstSetRepetitions: 8)
        let service = ActiveWorkoutMutationService(modelContext: context, defaultRestSeconds: 20)

        _ = service.completeCurrentSet(
            workoutID: fixture.workout.id,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0
        )
        let repeatedResult = service.completeCurrentSet(
            workoutID: fixture.workout.id,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0
        )

        guard case .stale = repeatedResult else {
            return XCTFail("A repeated Lock Screen action must be stale")
        }
        XCTAssertTrue(fixture.firstSet.done)
        XCTAssertFalse(fixture.secondSet.done)
    }

    func testInvalidSetRemainsIncomplete() throws {
        let context = try makeContext()
        let fixture = try makeActiveWorkout(in: context, firstSetRepetitions: 0)
        let service = ActiveWorkoutMutationService(modelContext: context, defaultRestSeconds: 20)

        let result = service.completeCurrentSet(
            workoutID: fixture.workout.id,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0
        )

        guard case .invalid = result else {
            return XCTFail("A set without required reps must be rejected")
        }
        XCTAssertFalse(fixture.firstSet.done)
        XCTAssertNil(fixture.workout.restEndDate)
    }

    /// Nothing is left to rest for once the last set is done, so completing it
    /// must leave the workout with no running or paused rest to restore.
    func testCompletingTheFinalSetLeavesNoRest() throws {
        let context = try makeContext()
        let fixture = try makeActiveWorkout(in: context, firstSetRepetitions: 8)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let service = ActiveWorkoutMutationService(modelContext: context, defaultRestSeconds: 20)

        _ = service.completeCurrentSet(
            workoutID: fixture.workout.id,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0,
            now: now
        )
        let result = service.completeCurrentSet(
            workoutID: fixture.workout.id,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 1,
            now: now
        )

        guard case let .applied(projection) = result else {
            return XCTFail("Expected the final set to complete")
        }

        XCTAssertTrue(fixture.secondSet.done)
        XCTAssertNil(fixture.workout.restEndDate)
        XCTAssertNil(fixture.workout.pausedRemainingTime)
        XCTAssertEqual(projection.restPhase, .inactive)
    }

    func testPausedRestCanExtendResumeAndSkip() throws {
        let context = try makeContext()
        let fixture = try makeActiveWorkout(in: context, firstSetRepetitions: 8)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        fixture.workout.restEndDate = now.addingTimeInterval(60)
        try context.save()
        let service = ActiveWorkoutMutationService(modelContext: context, defaultRestSeconds: 20)

        guard case .applied = service.pauseRest(workoutID: fixture.workout.id, now: now) else {
            return XCTFail("Expected running rest to pause")
        }
        XCTAssertEqual(fixture.workout.pausedRemainingTime, 60)

        guard case .applied = service.extendRest(workoutID: fixture.workout.id, by: 30, now: now) else {
            return XCTFail("Expected paused rest to extend")
        }
        XCTAssertEqual(fixture.workout.pausedRemainingTime, 90)

        guard case .applied = service.resumeRest(workoutID: fixture.workout.id, now: now) else {
            return XCTFail("Expected paused rest to resume")
        }
        XCTAssertEqual(fixture.workout.restEndDate, now.addingTimeInterval(90))
        XCTAssertNil(fixture.workout.pausedRemainingTime)

        guard case .applied = service.skipRest(workoutID: fixture.workout.id, now: now) else {
            return XCTFail("Expected running rest to skip")
        }
        XCTAssertNil(fixture.workout.restEndDate)
        XCTAssertNil(fixture.workout.pausedRemainingTime)
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    private func makeActiveWorkout(
        in context: ModelContext,
        firstSetRepetitions: Float
    ) throws -> (workout: Workout, firstSet: ExerciseSet, secondSet: ExerciseSet) {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let firstSet = ExerciseSet(
            repetitions: firstSetRepetitions,
            weight: 50,
            orderIndex: 0,
            usedMetric: .metric
        )
        let secondSet = ExerciseSet(repetitions: 8, weight: 50, orderIndex: 1, usedMetric: .metric)
        let entry = ExerciseEntry(
            exercise: exercise,
            sets: [firstSet, secondSet],
            orderIndex: 0,
            usedMetric: .metric
        )
        entry.prescribedRestSeconds = 90

        let workout = Workout(name: "Live Activity Workout")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()
        return (workout, firstSet, secondSet)
    }
}

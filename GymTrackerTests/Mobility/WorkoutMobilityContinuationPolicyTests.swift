import XCTest
@testable import GymTracker

final class WorkoutMobilityContinuationPolicyTests: XCTestCase {
    func testStandaloneSessionWithNoWorkoutDoesNotOpenActiveWorkout() {
        XCTAssertFalse(
            WorkoutMobilityContinuationPolicy.shouldResumeWorkout(
                sessionContext: .standalone,
                sessionWorkoutID: nil,
                pendingWarmupWorkoutID: UUID(),
                activeWorkoutID: nil
            )
        )
    }

    func testMatchingLinkedWarmupResumesItsActiveWorkout() {
        let workoutID = UUID()

        XCTAssertTrue(
            WorkoutMobilityContinuationPolicy.shouldResumeWorkout(
                sessionContext: .warmup,
                sessionWorkoutID: workoutID,
                pendingWarmupWorkoutID: workoutID,
                activeWorkoutID: workoutID
            )
        )
    }

    func testCooldownDoesNotResumeWorkout() {
        let workoutID = UUID()

        XCTAssertFalse(
            WorkoutMobilityContinuationPolicy.shouldResumeWorkout(
                sessionContext: .cooldown,
                sessionWorkoutID: workoutID,
                pendingWarmupWorkoutID: workoutID,
                activeWorkoutID: workoutID
            )
        )
    }

    func testDuringWorkoutDoesNotResumeAsWarmupContinuation() {
        let workoutID = UUID()

        XCTAssertFalse(
            WorkoutMobilityContinuationPolicy.shouldResumeWorkout(
                sessionContext: .duringWorkout,
                sessionWorkoutID: workoutID,
                pendingWarmupWorkoutID: workoutID,
                activeWorkoutID: workoutID
            )
        )
    }

    func testWarmupForDifferentWorkoutDoesNotResumeActiveWorkout() {
        XCTAssertFalse(
            WorkoutMobilityContinuationPolicy.shouldResumeWorkout(
                sessionContext: .warmup,
                sessionWorkoutID: UUID(),
                pendingWarmupWorkoutID: UUID(),
                activeWorkoutID: UUID()
            )
        )
    }
}

import XCTest
@testable import GymTracker

final class WorkoutMobilityStagePolicyTests: XCTestCase {
    func testWarmupIsLinkedOnlyWhileMatchingActiveDraft() {
        let workoutID = UUID()

        XCTAssertTrue(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .warmup,
                sessionWorkoutID: workoutID,
                activeWorkoutID: workoutID,
                performedWorkoutExists: true
            )
        )
        XCTAssertFalse(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .warmup,
                sessionWorkoutID: workoutID,
                activeWorkoutID: nil,
                performedWorkoutExists: true
            )
        )
    }

    func testDuringWorkoutIsLinkedOnlyWhileMatchingActiveDraft() {
        let workoutID = UUID()

        XCTAssertTrue(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .duringWorkout,
                sessionWorkoutID: workoutID,
                activeWorkoutID: workoutID,
                performedWorkoutExists: false
            )
        )
        XCTAssertFalse(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .duringWorkout,
                sessionWorkoutID: workoutID,
                activeWorkoutID: UUID(),
                performedWorkoutExists: true
            )
        )
        XCTAssertFalse(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .duringWorkout,
                sessionWorkoutID: nil,
                activeWorkoutID: workoutID,
                performedWorkoutExists: true
            )
        )
    }

    func testCooldownIsLinkedWhenPerformedWorkoutExists() {
        let workoutID = UUID()

        XCTAssertTrue(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .cooldown,
                sessionWorkoutID: workoutID,
                activeWorkoutID: nil,
                performedWorkoutExists: true
            )
        )
        XCTAssertFalse(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .cooldown,
                sessionWorkoutID: workoutID,
                activeWorkoutID: nil,
                performedWorkoutExists: false
            )
        )
    }

    func testStandaloneIsNeverLinked() {
        XCTAssertFalse(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: .standalone,
                sessionWorkoutID: UUID(),
                activeWorkoutID: UUID(),
                performedWorkoutExists: true
            )
        )
    }
}

final class MobilitySessionContextTests: XCTestCase {
    func testDuringWorkoutDisplayNameIsNotWarmupOrCooldown() {
        XCTAssertEqual(MobilitySessionContext.duringWorkout.displayName, "During workout")
        XCTAssertNotEqual(
            MobilitySessionContext.duringWorkout.displayName,
            MobilitySessionContext.warmup.displayName
        )
        XCTAssertNotEqual(
            MobilitySessionContext.duringWorkout.displayName,
            MobilitySessionContext.cooldown.displayName
        )
    }

    func testDuringWorkoutIsALinkedStageCandidate() {
        XCTAssertTrue(MobilitySessionContext.duringWorkout.isWorkoutLinkedStageCandidate)
        XCTAssertFalse(MobilitySessionContext.standalone.isWorkoutLinkedStageCandidate)
    }

    func testDuringWorkoutRawValueRoundTrips() {
        XCTAssertEqual(
            MobilitySessionContext(rawValue: MobilitySessionContext.duringWorkout.rawValue),
            .duringWorkout
        )
    }
}

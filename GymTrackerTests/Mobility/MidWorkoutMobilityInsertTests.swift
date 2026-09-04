import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MidWorkoutMobilityInsertTests: XCTestCase {
    func testStartDuringWorkoutLinksSessionToActiveDraft() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let routine = makeRunnableRoutine(named: "Hip openers", in: context)
        let workout = Workout(name: "Push")
        context.insert(workout)
        try context.save()

        let session = try XCTUnwrap(
            MobilitySessionService.start(
                routine: routine,
                context: .duringWorkout,
                workoutID: workout.id,
                using: context
            )
        )

        XCTAssertEqual(session.context, .duringWorkout)
        XCTAssertEqual(session.workoutID, workout.id)
        XCTAssertTrue(
            WorkoutMobilityStagePolicy.isLinkedStage(
                context: session.context,
                sessionWorkoutID: session.workoutID,
                activeWorkoutID: workout.id,
                performedWorkoutExists: true
            )
        )
    }

    func testOneActiveGateRefusesSecondMidSessionInsert() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let first = makeRunnableRoutine(named: "First", in: context)
        let second = makeRunnableRoutine(named: "Second", in: context)
        let workout = Workout(name: "Legs")
        context.insert(workout)
        try context.save()

        XCTAssertNotNil(
            MobilitySessionService.start(
                routine: first,
                context: .duringWorkout,
                workoutID: workout.id,
                using: context
            )
        )
        XCTAssertNil(
            MobilitySessionService.start(
                routine: second,
                context: .duringWorkout,
                workoutID: workout.id,
                using: context
            )
        )
        XCTAssertEqual(MobilitySessionService.activeSession(using: context)?.sourceRoutineName, "First")
    }

    func testStoppingMidSessionClearsActiveGateWithoutDeletingEvidence() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let routine = makeRunnableRoutine(named: "Flow", in: context)
        let workout = Workout(name: "Upper")
        context.insert(workout)
        try context.save()

        let session = try XCTUnwrap(
            MobilitySessionService.start(
                routine: routine,
                context: .duringWorkout,
                workoutID: workout.id,
                using: context
            )
        )
        XCTAssertTrue(MobilitySessionService.stop(session, using: context))
        XCTAssertEqual(session.status, .stopped)
        XCTAssertNil(MobilitySessionService.activeSession(using: context))
        XCTAssertEqual(session.context, .duringWorkout)
        XCTAssertEqual(session.workoutID, workout.id)
    }

    func testContinuationPolicyDoesNotTreatDuringWorkoutAsWarmupResume() {
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

    private func makeRunnableRoutine(named name: String, in context: ModelContext) -> MobilityRoutine {
        let definition = MobilityDefinition(name: "\(name) movement")
        let routine = MobilityRoutine(name: name, purpose: .development)
        routine.items = [
            MobilityRoutineItem(
                definition: definition,
                orderIndex: 0,
                targetDurationSeconds: 30,
                side: .left
            )
        ]
        context.insert(definition)
        context.insert(routine)
        return routine
    }
}

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class HistoricalExerciseIdentityTests: XCTestCase {
    func testHistoryAndAnalyticsFollowSnapshotAfterRenameAndLiveRelink() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let original = Exercise(name: "Original Lift", primaryMuscles: [.upperChest], isCustom: true)
        let replacement = Exercise(name: "Original Lift", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(original)
        context.insert(replacement)

        let workout = makeCompletedWorkout(
            exercise: original,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            comment: "Stable note",
            weight: 100,
            in: context
        )
        try context.save()

        let entry = try XCTUnwrap(workout.orderedExercises.first)
        original.name = "Renamed Original"
        entry.exercise = replacement
        try context.save()

        let history = try ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: original, before: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(history?.set(at: 0)?.weight, 100)

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: original, referenceDate: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(analytics.sessionCount, 1)
        XCTAssertEqual(analytics.notes.map(\.text), ["Stable note"])
        XCTAssertEqual(analytics.latestSession?.sets.first?.weight, 100)
        XCTAssertEqual(entry.displayName, "Original Lift")

        let replacementAnalytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: replacement, referenceDate: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(replacementAnalytics.sessionCount, 0)
        XCTAssertTrue(replacementAnalytics.notes.isEmpty)
    }

    func testRecreatedExerciseWithNewIdentityDoesNotInheritOldHistory() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let oldExercise = Exercise(name: "Archived Lift", primaryMuscles: [.upperChest], isCustom: true)
        let recreatedExercise = Exercise(name: "Archived Lift", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(oldExercise)
        context.insert(recreatedExercise)
        let oldWorkout = makeCompletedWorkout(
            exercise: oldExercise,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            weight: 120,
            in: context
        )
        let newWorkout = makeCompletedWorkout(
            exercise: recreatedExercise,
            date: Date(timeIntervalSince1970: 1_700_100_000),
            weight: 80,
            in: context
        )
        try context.save()

        let oldAnalytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: oldExercise, referenceDate: Date(timeIntervalSince1970: 1_800_000_000))
        let newAnalytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: recreatedExercise, referenceDate: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(oldAnalytics.sessionCount, 1)
        XCTAssertEqual(oldAnalytics.bestLoadSet?.weight, 120)
        XCTAssertEqual(newAnalytics.sessionCount, 1)
        XCTAssertEqual(newAnalytics.bestLoadSet?.weight, 80)
        XCTAssertNotEqual(
            oldWorkout.orderedExercises.first?.historicalExerciseID,
            newWorkout.orderedExercises.first?.historicalExerciseID
        )
    }

    func testLegacyNilSnapshotFallsBackToLiveRelationship() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Legacy Lift", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(exercise)
        let workout = makeCompletedWorkout(
            exercise: exercise,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            weight: 90,
            in: context
        )
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        entry.exerciseIDSnapshot = nil
        try context.save()

        let performance = try ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: exercise, before: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(performance?.set(at: 0)?.weight, 90)
        XCTAssertEqual(entry.historicalExerciseID, exercise.id)
    }

    func testStrengthBlockComparisonUsesHistoricalIdentity() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let original = Exercise(name: "Circuit Lift", primaryMuscles: [.upperChest], isCustom: true)
        let replacement = Exercise(name: "Circuit Lift", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(original)
        context.insert(replacement)

        let workout = makeCompletedWorkout(
            exercise: original,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            weight: 60,
            in: context
        )
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .circuit,
            targetRounds: 3,
            scoreKind: .roundsAndRepetitions
        )
        block.status = .completed
        block.completedRounds = 3
        entry.executionBlockID = block.id
        entry.executionBlockComponentOrder = 0
        workout.executionBlocks = [block]
        entry.exercise = replacement
        try context.save()

        let candidate = try XCTUnwrap(
            StrengthAnalyticsPolicy.blockCandidate(for: block, in: workout)
        )
        XCTAssertTrue(candidate.comparisonKey.contains(original.id.uuidString))
        XCTAssertFalse(candidate.comparisonKey.contains(replacement.id.uuidString))
    }

    private func makeCompletedWorkout(
        exercise: Exercise,
        date: Date,
        comment: String? = nil,
        weight: Float,
        in context: ModelContext
    ) -> Workout {
        let workout = Workout(name: "Historical Session", endTime: date.addingTimeInterval(3_600))
        workout.startTime = date
        let entry = ExerciseEntry(comment: comment, exercise: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(
            repetitions: 8,
            weight: weight,
            done: true,
            orderIndex: 0,
            usedMetric: .metric
        )]
        workout.exercises = [entry]
        context.insert(workout)
        return workout
    }
}

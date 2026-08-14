import Foundation
import SwiftData
@testable import GymTracker

/// Deterministic, opt-in history data for performance and large-data audits.
///
/// The default shape is 100 completed workouts × 1,000 sets = 100,000 sets.
/// It is intentionally not used by correctness tests: constructing this graph
/// is expensive, and a benchmark must be an explicit diagnostic lane rather
/// than hidden setup in the normal unit suite.
@MainActor
enum LargeHistoryTestFixture {
    struct Fixture {
        let exercise: Exercise
        let workouts: [Workout]
        let setCount: Int

        /// Persists the same graph when a diagnostic needs to measure
        /// SwiftData fetch/materialization cost rather than value projection.
        /// Correctness tests should continue using the small shared fixtures.
        @MainActor
        func insert(into context: ModelContext) throws {
            context.insert(exercise)
            for workout in workouts {
                context.insert(workout)
            }
            try context.save()
        }
    }

    nonisolated static let defaultSetCount = 100_000
    nonisolated static let defaultWorkoutCount = 100

    static func make(
        setCount: Int = defaultSetCount,
        workoutCount: Int = defaultWorkoutCount,
        referenceDate: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> Fixture {
        precondition(setCount >= 1, "A large-history fixture requires at least one set.")
        precondition(workoutCount >= 1, "A large-history fixture requires at least one workout.")

        let exercise = Exercise(
            name: "Benchmark Bench Press",
            primaryMuscles: [.upperChest],
            isCustom: true
        )
        let actualWorkoutCount = min(workoutCount, setCount)
        let workouts = (0..<actualWorkoutCount).map { workoutIndex in
            let lowerBound = (setCount * workoutIndex) / actualWorkoutCount
            let upperBound = (setCount * (workoutIndex + 1)) / actualWorkoutCount
            let sets = (lowerBound..<upperBound).map { globalSetIndex in
                ExerciseSet(
                    repetitions: Float(5 + (globalSetIndex % 8)),
                    weight: Float(60 + (workoutIndex % 10)),
                    done: true,
                    orderIndex: globalSetIndex - lowerBound,
                    usedMetric: .metric
                )
            }
            let entry = ExerciseEntry(
                exercise: exercise,
                sets: sets,
                orderIndex: 0,
                usedMetric: .metric
            )
            let start = referenceDate.addingTimeInterval(TimeInterval((workoutIndex - actualWorkoutCount) * 86_400))
            let workout = Workout(
                name: "Benchmark Workout \(workoutIndex + 1)",
                endTime: start.addingTimeInterval(3_600)
            )
            workout.startTime = start
            workout.status = .completed
            workout.exercises = [entry]
            return workout
        }

        return Fixture(exercise: exercise, workouts: workouts, setCount: setCount)
    }
}

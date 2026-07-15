import Foundation
import SwiftData

struct PreviousSetPerformance: Equatable, Sendable {
    let orderIndex: Int
    let repetitions: Float
    let weight: Float
    let weightType: WeightType
    let duration: TimeInterval?
    let distance: Float?
    let distanceType: DistanceType
    let setType: SetType
}

struct PreviousExercisePerformance: Equatable, Sendable {
    let workoutDate: Date
    let sets: [PreviousSetPerformance]

    var completedSetCount: Int { sets.count }

    func set(at index: Int) -> PreviousSetPerformance? {
        sets.first { $0.orderIndex == index }
    }
}

/// Historical lookup for active-workout hints and progression. It intentionally
/// returns snapshots so changing an active set can never mutate workout history.
struct ExerciseHistoryService {
    let modelContext: ModelContext

    func mostRecentPerformance(
        for exercise: Exercise,
        before date: Date
    ) throws -> PreviousExercisePerformance? {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [
                SortDescriptor(\Workout.startTime, order: .reverse),
                SortDescriptor(\Workout.id, order: .forward)
            ]
        )
        let completedWorkouts = try modelContext.fetch(descriptor)

        for workout in completedWorkouts where workout.status == .completed && workout.startTime < date {
            guard let entry = workout.orderedExercises.first(where: {
                $0.exercise.persistentModelID == exercise.persistentModelID
            }) else {
                continue
            }

            let sets = entry.orderedSets
                .filter(\.done)
                .map {
                    PreviousSetPerformance(
                        orderIndex: $0.orderIndex,
                        repetitions: $0.repetitions,
                        weight: $0.weight,
                        weightType: $0.weightType,
                        duration: $0.duration,
                        distance: $0.distance,
                        distanceType: $0.distanceType,
                        setType: $0.setType
                    )
                }

            guard !sets.isEmpty else { continue }
            return PreviousExercisePerformance(workoutDate: workout.startTime, sets: sets)
        }

        return nil
    }
}

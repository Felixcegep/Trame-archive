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
    let calories: Double?
    let setType: SetType

    init(
        orderIndex: Int,
        repetitions: Float,
        weight: Float,
        weightType: WeightType,
        duration: TimeInterval?,
        distance: Float?,
        distanceType: DistanceType,
        calories: Double? = nil,
        setType: SetType
    ) {
        self.orderIndex = orderIndex
        self.repetitions = repetitions
        self.weight = weight
        self.weightType = weightType
        self.duration = duration
        self.distance = distance
        self.distanceType = distanceType
        self.calories = calories
        self.setType = setType
    }
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
            let entries = HistoricalExerciseIdentityPolicy.entries(
                for: exercise,
                in: workout
            )

            // This API intentionally represents the most recent *workout* for
            // a catalogue exercise. When that workout prescribed repeated
            // occurrences, preserve all of their evidence in performed order
            // and assign contiguous hint indices so duplicate per-entry set
            // indices cannot collapse `set(at:)` lookups.
            let sets = entries
                .flatMap { $0.orderedSets }
                .filter(\.done)
                .enumerated()
                .map { index, set in
                    PreviousSetPerformance(
                        orderIndex: index,
                        repetitions: set.repetitions,
                        weight: set.weight,
                        weightType: set.weightType,
                        duration: set.duration,
                        distance: set.distance,
                        distanceType: set.distanceType,
                        calories: set.calories,
                        setType: set.setType
                    )
                }

            guard !sets.isEmpty else { continue }
            return PreviousExercisePerformance(workoutDate: workout.startTime, sets: sets)
        }

        return nil
    }
}

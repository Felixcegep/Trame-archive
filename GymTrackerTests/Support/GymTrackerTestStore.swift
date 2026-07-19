import Foundation
import SwiftData
@testable import GymTracker

/// Builds isolated stores with the full GymTracker schema for persistence
/// tests. Each call returns a new container so test data cannot leak between
/// cases.
@MainActor
enum GymTrackerTestStore {
    static func makeInMemoryContext() throws -> ModelContext {
        try makeContext(configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    static func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        try body(try makeContext(configuration: ModelConfiguration(url: url)))
    }

    private static func makeContext(configuration: ModelConfiguration) throws -> ModelContext {
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            PlanExerciseProgressionState.self,
            ProgramDefinitionRecord.self,
            PlanProgressionRecommendationRecord.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlannedExerciseAlternative.self,
            PlannedSet.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}

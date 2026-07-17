import SwiftData

/// The one persistent store used by both the SwiftUI scene and
/// `LiveActivityIntent` executions. A Live Activity intent runs in the app
/// process, so it can safely use this container without an App Group store.
@MainActor
enum GymTrackerModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Unable to create GymTracker's persistent model container: \(error)")
        }
    }()

    static let schema = Schema([
        Workout.self,
        Exercise.self,
        ExerciseRelationship.self,
        WorkoutTemplate.self,
        TemplateExercise.self,
        WorkoutCollection.self,
        WorkoutPlan.self,
        PlanBlock.self,
        PlanWeek.self,
        PlannedWorkout.self,
        PlannedExercise.self,
        PlannedSet.self,
        PlannedExerciseAlternative.self,
        PlanRun.self,
        PlanWorkoutProgress.self,
        PlanExerciseProgressionState.self,
        ProgramDefinitionRecord.self
    ])
}

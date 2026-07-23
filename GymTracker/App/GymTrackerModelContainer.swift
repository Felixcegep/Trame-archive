import SwiftData

/// Diagnostic-only label for the shape of the persisted SwiftData schema
/// below. This is distinct from `BackupDTO.currentVersion` (the portable
/// backup/export format) and from the Program Engine's own schema version —
/// none of the three should be conflated. Bump this whenever a persisted
/// model's stored shape changes, so a beta feedback report can distinguish
/// testers running different schema generations.
enum GymTrackerAppSchema {
    static let diagnosticVersion = "1"
}

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

    static let schema: Schema = {
        var types: [any PersistentModel.Type] = [
            Workout.self,
            WorkoutExecutionBlock.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            ExerciseSetSegment.self,
            ComplexComponentResult.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateExerciseBlock.self,
            WorkoutCollection.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlannedExerciseBlock.self,
            PlannedSet.self,
            PlannedExerciseAlternative.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            PlanExerciseProgressionState.self,
            DailyLogEntry.self,
            BodyWeightEntry.self,
            SupplementOccurrence.self,
            MobilityFamily.self,
            MobilityDefinition.self,
            MobilityRoutine.self,
            MobilityRoutineItem.self,
            MobilitySession.self,
            MobilityEntry.self,
            MobilityResult.self,
            FoodItem.self,
            FoodServing.self,
            MealTemplate.self,
            MealTemplateItem.self,
            LoggedMeal.self,
            LoggedMealItem.self,
            NutritionTarget.self
        ]
#if !GYMTRACKER_EXTENSION
        types.append(SystemSeedRecord.self)
        types.append(ProgramDefinitionRecord.self)
        types.append(PlanProgressionRecommendationRecord.self)
#endif
        return Schema(types)
    }()
}

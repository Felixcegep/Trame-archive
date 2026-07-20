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

    static let schema: Schema = {
        var types: [any PersistentModel.Type] = [
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
        types.append(ProgramDefinitionRecord.self)
        types.append(PlanProgressionRecommendationRecord.self)
#endif
        return Schema(types)
    }()
}

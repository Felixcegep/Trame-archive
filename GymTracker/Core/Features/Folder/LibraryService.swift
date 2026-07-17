import SwiftData

enum LibraryService {
    @discardableResult
    static func createWorkoutCollection(
        name: String,
        templates: [WorkoutTemplate],
        using modelContext: ModelContext
    ) -> Bool {
        modelContext.insert(WorkoutCollection(name: name, workoutTemplates: templates))
        return saveModelContext(modelContext)
    }

    @discardableResult
    static func createWorkoutTemplate(
        name: String,
        exercises: [Exercise],
        using modelContext: ModelContext
    ) -> Bool {
        modelContext.insert(WorkoutTemplate(name: name, exercises: exercises))
        return saveModelContext(modelContext)
    }

    @discardableResult
    static func createPlan(_ plan: WorkoutPlan, using modelContext: ModelContext) -> Bool {
        modelContext.insert(plan)
        return saveModelContext(modelContext)
    }

    @discardableResult
    static func createCustomExercise(_ exercise: Exercise, using modelContext: ModelContext) -> Bool {
        exercise.isCustom = true
        modelContext.insert(exercise)
        return saveModelContext(modelContext)
    }
}

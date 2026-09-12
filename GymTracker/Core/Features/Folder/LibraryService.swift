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

    /// Used by the builder, which orders exercises and can pair them into
    /// supersets — detail that a plain `[Exercise]` cannot carry. Warm-up and
    /// post-workout stretches are the same links the template editor owns, so
    /// they can be chosen while the workout is still a draft.
    @discardableResult
    static func createWorkoutTemplate(
        name: String,
        templateExercises: [TemplateExercise],
        preWorkoutMobilityRoutine: MobilityRoutine? = nil,
        postWorkoutMobilityRoutine: MobilityRoutine? = nil,
        using modelContext: ModelContext
    ) -> Bool {
        modelContext.insert(
            WorkoutTemplate(
                name: name,
                exercises: [],
                templateExercises: templateExercises,
                preWorkoutMobilityRoutine: preWorkoutMobilityRoutine,
                postWorkoutMobilityRoutine: postWorkoutMobilityRoutine
            )
        )
        return saveModelContext(modelContext)
    }

    @discardableResult
    static func createPlan(_ plan: WorkoutPlan, using modelContext: ModelContext) -> Bool {
        modelContext.insert(plan)
        return saveModelContext(modelContext)
    }

    @discardableResult
    static func createRepeatingPlan(_ plan: RepeatingPlan, using modelContext: ModelContext) -> Bool {
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

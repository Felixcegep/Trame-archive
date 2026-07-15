import SwiftData

enum ExerciseArchiveService {
    static func hideOrDelete(_ exercise: ExerciceTemplate, using context: ModelContext) throws {
        if !exercise.isCustom {
            exercise.isArchived = true
        } else if try isReferenced(exercise, using: context) {
            exercise.isArchived = true
        } else {
            context.delete(exercise)
        }

        try context.save()
    }

    static func restore(_ exercise: ExerciceTemplate, using context: ModelContext) throws {
        exercise.isArchived = false
        try context.save()
    }

    private static func isReferenced(
        _ exercise: ExerciceTemplate,
        using context: ModelContext
    ) throws -> Bool {
        let entries = try context.fetch(FetchDescriptor<ExerciceEntry>())
        if entries.contains(where: { $0.exercice.id == exercise.id }) { return true }

        let templateExercises = try context.fetch(FetchDescriptor<TemplateExercise>())
        if templateExercises.contains(where: { $0.exercise.id == exercise.id }) { return true }

        let plannedExercises = try context.fetch(FetchDescriptor<PlannedExercise>())
        return plannedExercises.contains(where: { $0.exercise.id == exercise.id })
    }
}

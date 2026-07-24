import SwiftData

enum ExerciseArchiveService {
    static func hideOrDelete(_ exercise: Exercise, using context: ModelContext) throws {
        if !exercise.isCustom {
            exercise.isArchived = true
        } else if try isReferenced(exercise, using: context) {
            exercise.isArchived = true
        } else {
            context.delete(exercise)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func restore(_ exercise: Exercise, using context: ModelContext) throws {
        exercise.isArchived = false
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func isReferenced(
        _ exercise: Exercise,
        using context: ModelContext
    ) throws -> Bool {
        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>())
        if entries.contains(where: { $0.exercise.id == exercise.id }) { return true }

        let templateExercises = try context.fetch(FetchDescriptor<TemplateExercise>())
        if templateExercises.contains(where: { $0.exercise.id == exercise.id }) { return true }

        let plannedExercises = try context.fetch(FetchDescriptor<PlannedExercise>())
        if plannedExercises.contains(where: { $0.exercise.id == exercise.id }) { return true }

        let plannedAlternatives = try context.fetch(FetchDescriptor<PlannedExerciseAlternative>())
        if plannedAlternatives.contains(where: { $0.exercise.id == exercise.id }) { return true }

        let relationships = try context.fetch(FetchDescriptor<ExerciseRelationship>())
        return relationships.contains {
            $0.sourceExercise?.id == exercise.id || $0.targetExercise?.id == exercise.id
        }
    }
}

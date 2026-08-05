import SwiftData

enum ExerciseArchiveOutcome: Equatable {
    case deleted
    case archived(reason: String)
}

enum ExerciseArchiveService {
    @discardableResult
    static func hideOrDelete(_ exercise: Exercise, using context: ModelContext) throws -> ExerciseArchiveOutcome {
        try hideOrDeleteResult(exercise, using: context)
    }

    static func hideOrDeleteResult(
        _ exercise: Exercise,
        using context: ModelContext
    ) throws -> ExerciseArchiveOutcome {
        let outcome: ExerciseArchiveOutcome
        if !exercise.isCustom {
            exercise.isArchived = true
            outcome = .archived(reason: "System exercises are archived to preserve application default content.")
        } else if let reason = try referenceReason(exercise, using: context) {
            exercise.isArchived = true
            outcome = .archived(reason: reason)
        } else {
            context.delete(exercise)
            outcome = .deleted
        }

        do {
            try context.save()
            return outcome
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

    private static func referenceReason(
        _ exercise: Exercise,
        using context: ModelContext
    ) throws -> String? {
        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>())
        if entries.contains(where: { $0.exercise.id == exercise.id }) {
            return "Referenced by completed workout history. Archived so past workouts remain unchanged."
        }

        let templateExercises = try context.fetch(FetchDescriptor<TemplateExercise>())
        if templateExercises.contains(where: { $0.exercise.id == exercise.id }) {
            return "Referenced by a workout template. Archived so template prescriptions remain valid."
        }

        let plannedExercises = try context.fetch(FetchDescriptor<PlannedExercise>())
        if plannedExercises.contains(where: { $0.exercise.id == exercise.id }) {
            return "Referenced by a planned program. Archived so plan prescriptions remain valid."
        }

        let plannedAlternatives = try context.fetch(FetchDescriptor<PlannedExerciseAlternative>())
        if plannedAlternatives.contains(where: { $0.exercise.id == exercise.id }) {
            return "Referenced as a plan exercise alternative. Archived so plan options remain valid."
        }

        let relationships = try context.fetch(FetchDescriptor<ExerciseRelationship>())
        if relationships.contains(where: { $0.sourceExercise?.id == exercise.id || $0.targetExercise?.id == exercise.id }) {
            return "Referenced in exercise relationships. Archived so exercise links remain valid."
        }

        return nil
    }

    private static func isReferenced(
        _ exercise: Exercise,
        using context: ModelContext
    ) throws -> Bool {
        try referenceReason(exercise, using: context) != nil
    }
}

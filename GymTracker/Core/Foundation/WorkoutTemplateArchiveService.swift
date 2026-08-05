import Foundation
import SwiftData

enum TemplateArchiveOutcome: Equatable {
    case deleted
    case archived(reason: String)
}

enum WorkoutTemplateArchiveService {
    /// Renames the specified template after trimming whitespace.
    static func rename(_ template: WorkoutTemplate, to newName: String, using context: ModelContext) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TemplateArchiveError.emptyName
        }
        template.name = trimmed
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Duplicates the specified template into a fresh copy with copied exercises, sets, execution blocks, and mobility links.
    @discardableResult
    static func duplicate(_ template: WorkoutTemplate, using context: ModelContext) throws -> WorkoutTemplate {
        let copyName = "\(template.name) Copy"

        let duplicateTemplate = WorkoutTemplate(
            name: copyName,
            exercises: [],
            preWorkoutMobilityRoutine: template.preWorkoutMobilityRoutine,
            postWorkoutMobilityRoutine: template.postWorkoutMobilityRoutine,
            isBuiltIn: false
        )
        context.insert(duplicateTemplate)

        // Deep copy template exercises & sets
        var blockIDMap: [UUID: UUID] = [:]
        for templateExercise in template.orderedTemplateExercises {
            let copiedExercise = TemplateExercise(
                exercise: templateExercise.exercise,
                order: templateExercise.orderIndex,
                targetSets: templateExercise.targetSets,
                repRangeMinimum: templateExercise.repRangeMinimum,
                repRangeMaximum: templateExercise.repRangeMaximum,
                restSeconds: templateExercise.restSeconds,
                targetRPE: templateExercise.targetRPE,
                targetRIR: templateExercise.targetRIR,
                stimulus: templateExercise.stimulus
            )
            copiedExercise.supersetGroupID = templateExercise.supersetGroupID

            if let blockID = templateExercise.executionBlockID {
                let newBlockID = blockIDMap[blockID] ?? UUID()
                blockIDMap[blockID] = newBlockID
                copiedExercise.executionBlockID = newBlockID
                copiedExercise.executionBlockComponentOrder = templateExercise.executionBlockComponentOrder
            }

            duplicateTemplate.templateExercises.append(copiedExercise)
        }

        // Deep copy execution blocks
        for block in template.orderedExecutionBlocks {
            let newID = blockIDMap[block.id] ?? UUID()
            let copiedBlock = TemplateExerciseBlock(
                orderIndex: block.orderIndex,
                kind: block.kind,
                name: block.name
            )
            copiedBlock.id = newID
            duplicateTemplate.executionBlocks.append(copiedBlock)
        }

        duplicateTemplate.normalizeTemplateExerciseOrder()

        do {
            try context.save()
            return duplicateTemplate
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Deletes or archives the template based on whether historical workouts, repeating plan slots, or collections reference it.
    @discardableResult
    static func hideOrDeleteResult(
        _ template: WorkoutTemplate,
        using context: ModelContext
    ) throws -> TemplateArchiveOutcome {
        let outcome: TemplateArchiveOutcome
        if template.isBuiltIn {
            template.isArchived = true
            outcome = .archived(reason: "System templates are archived to preserve starter content.")
        } else if let reason = try referenceReason(template, using: context) {
            template.isArchived = true
            outcome = .archived(reason: reason)
        } else {
            context.delete(template)
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

    /// Restores an archived template.
    static func restore(_ template: WorkoutTemplate, using context: ModelContext) throws {
        template.isArchived = false
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func referenceReason(
        _ template: WorkoutTemplate,
        using context: ModelContext
    ) throws -> String? {
        if template.sourceWorkouts.isEmpty == false {
            return "Referenced by completed workout history. Archived so past workouts remain unchanged."
        }

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        if workouts.contains(where: { $0.sourceTemplate?.id == template.id }) {
            return "Referenced by completed workout history. Archived so past workouts remain unchanged."
        }

        if template.repeatingPlanSlots.isEmpty == false || template.repeatingPlanRunSlots.isEmpty == false {
            return "Referenced by a repeating plan rotation. Archived so plan rotations remain valid."
        }

        let repeatingPlanSlots = try context.fetch(FetchDescriptor<RepeatingPlanSlot>())
        if repeatingPlanSlots.contains(where: { $0.workoutTemplate?.id == template.id }) {
            return "Referenced by a repeating plan slot. Archived so plan rotations remain valid."
        }

        let repeatingPlanRunSlots = try context.fetch(FetchDescriptor<RepeatingPlanRunSlot>())
        if repeatingPlanRunSlots.contains(where: { $0.workoutTemplate?.id == template.id }) {
            return "Referenced by an active repeating plan run. Archived so active rotations remain valid."
        }

        if template.workoutCollections.isEmpty == false {
            return "Referenced in a workout collection folder. Archived so collection contents remain valid."
        }

        return nil
    }
}

enum TemplateArchiveError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Workout template name cannot be empty."
        }
    }
}

import Foundation
import SwiftData

// MARK: - Outcome & Error Types

enum PlanArchiveOutcome: Equatable {
    case deleted
    case archived(reason: String)
}

enum PlanArchiveError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Plan name cannot be empty."
        }
    }
}

// MARK: - Fixed Plan Lifecycle

/// Definition-level lifecycle operations for `WorkoutPlan`: rename, duplicate,
/// archive, restore, and reference-checked deletion.
///
/// Run-level operations (start, pause, resume, end) live in
/// `PlanLifecycleService` and `PlanCoordinator`.
enum WorkoutPlanArchiveService {

    // MARK: Rename

    static func rename(_ plan: WorkoutPlan, to newName: String, using context: ModelContext) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlanArchiveError.emptyName
        }
        plan.name = trimmed
        plan.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Duplicate

    /// Creates a shallow duplicate of the plan definition (metadata only).
    /// The full deep copy of blocks/weeks/workouts/exercises is intentionally
    /// deferred — plans are complex graphs with progression rules, and the
    /// user's immediate need is a rename-and-tweak workflow, not a full clone
    /// of every planned exercise and set prescription.
    @discardableResult
    static func duplicate(_ plan: WorkoutPlan, using context: ModelContext) throws -> WorkoutPlan {
        let copy = WorkoutPlan(
            name: "\(plan.name) Copy",
            goal: plan.goal,
            experienceLevel: plan.experienceLevel,
            requiredEquipment: plan.requiredEquipment,
            daysPerWeek: plan.daysPerWeek,
            durationWeeks: plan.durationWeeks,
            scheduleMode: plan.scheduleMode,
            scheduleIntervalDays: plan.scheduleIntervalDays,
            notes: plan.notes
        )
        context.insert(copy)

        // Deep copy block → week → workout structure
        for block in plan.orderedBlocks {
            let copiedBlock = PlanBlock(
                name: block.name,
                phaseType: block.phaseType,
                orderIndex: block.orderIndex,
                goal: block.goal,
                notes: block.notes,
                deloadVolumeReductionPercent: block.deloadVolumeReductionPercent,
                deloadIntensityReductionPercent: block.deloadIntensityReductionPercent
            )
            copy.blocks.append(copiedBlock)

            for week in block.orderedWeeks {
                let copiedWeek = PlanWeek(
                    weekIndex: week.weekIndex,
                    name: week.name,
                    notes: week.notes
                )
                copiedBlock.weeks.append(copiedWeek)

                for workout in week.orderedPlannedWorkouts {
                    let copiedWorkout = PlannedWorkout(
                        name: workout.name,
                        orderIndex: workout.orderIndex,
                        dayOffset: workout.dayOffset,
                        isOptional: workout.isOptional,
                        isTestDay: workout.isTestDay,
                        estimatedDurationSeconds: workout.estimatedDurationSeconds,
                        notes: workout.notes,
                        sourceTemplate: workout.sourceTemplate
                    )
                    copiedWeek.plannedWorkouts.append(copiedWorkout)

                    // Deep copy execution blocks
                    var blockIDMap: [UUID: UUID] = [:]
                    for execBlock in workout.orderedExecutionBlocks {
                        let newBlockID = UUID()
                        blockIDMap[execBlock.id] = newBlockID
                        let copiedExecBlock = PlannedExerciseBlock(
                            orderIndex: execBlock.orderIndex,
                            kind: execBlock.kind,
                            name: execBlock.name,
                            targetRounds: execBlock.targetRounds,
                            isSharedLoad: execBlock.isSharedLoad,
                            restSeconds: execBlock.restSeconds,
                            clockMode: execBlock.clockMode,
                            prescribedDurationSeconds: execBlock.prescribedDurationSeconds,
                            timeCapSeconds: execBlock.timeCapSeconds,
                            intervalSeconds: execBlock.intervalSeconds,
                            scoreKind: execBlock.scoreKind,
                            repetitionScheme: execBlock.repetitionScheme,
                            repetitionStart: execBlock.repetitionStart,
                            repetitionEnd: execBlock.repetitionEnd,
                            repetitionStep: execBlock.repetitionStep
                        )
                        copiedExecBlock.id = newBlockID
                        copiedWorkout.executionBlocks.append(copiedExecBlock)
                    }

                    // Deep copy planned exercises
                    for plannedExercise in workout.orderedPlannedExercises {
                        let copiedPlannedExercise = PlannedExercise(
                            exercise: plannedExercise.exercise,
                            orderIndex: plannedExercise.orderIndex,
                            role: plannedExercise.role,
                            isOptional: plannedExercise.isOptional,
                            targetSets: plannedExercise.targetSets,
                            repRangeMinimum: plannedExercise.repRangeMinimum,
                            repRangeMaximum: plannedExercise.repRangeMaximum,
                            suggestedLoad: plannedExercise.suggestedLoad,
                            suggestedLoadType: plannedExercise.suggestedLoadType,
                            restSeconds: plannedExercise.restSeconds,
                            targetRPE: plannedExercise.targetRPE,
                            targetRIR: plannedExercise.targetRIR,
                            notes: plannedExercise.notes,
                            progressionRule: plannedExercise.progressionRule,
                            stimulus: plannedExercise.resolvedStimulus,
                            trackingTypeOverride: plannedExercise.trackingTypeOverride,
                            supersetGroupID: plannedExercise.supersetGroupID,
                            progressionKey: plannedExercise.progressionKey,
                            progressionRulesData: plannedExercise.progressionRulesData,
                            progressionWavesData: plannedExercise.progressionWavesData,
                            progressionStagesData: plannedExercise.progressionStagesData,
                            variationLadderData: plannedExercise.variationLadderData,
                            initialVariationExerciseID: plannedExercise.initialVariationExerciseID,
                            initialVelocityBaseline: plannedExercise.initialVelocityBaseline,
                            initialTrainingMax: plannedExercise.initialTrainingMax,
                            initialEstimatedOneRepMax: plannedExercise.initialEstimatedOneRepMax,
                            initialActualOneRepMax: plannedExercise.initialActualOneRepMax,
                            automaticDeloadVolumeReductionPercent: plannedExercise.automaticDeloadVolumeReductionPercent,
                            automaticDeloadIntensityReductionPercent: plannedExercise.automaticDeloadIntensityReductionPercent,
                            warmupSchemeData: plannedExercise.warmupSchemeData
                        )

                        if let origBlockID = plannedExercise.executionBlockID,
                           let newBlockID = blockIDMap[origBlockID] {
                            copiedPlannedExercise.executionBlockID = newBlockID
                            copiedPlannedExercise.executionBlockComponentOrder = plannedExercise.executionBlockComponentOrder
                        }

                        // Copy planned sets
                        for plannedSet in plannedExercise.orderedPlannedSets {
                            let copiedSet = PlannedSet(
                                orderIndex: plannedSet.orderIndex,
                                setType: plannedSet.setType,
                                repetitions: plannedSet.repetitions,
                                repRangeMinimum: plannedSet.repRangeMinimum,
                                repRangeMaximum: plannedSet.repRangeMaximum,
                                suggestedLoad: plannedSet.suggestedLoad,
                                suggestedLoadType: plannedSet.suggestedLoadType,
                                restSeconds: plannedSet.restSeconds,
                                targetRPE: plannedSet.targetRPE,
                                targetRIR: plannedSet.targetRIR,
                                tempo: plannedSet.tempo,
                                progressionEligible: plannedSet.progressionEligible,
                                isOptional: plannedSet.isOptional,
                                notes: plannedSet.notes
                            )
                            copiedPlannedExercise.plannedSets.append(copiedSet)
                        }

                        copiedWorkout.plannedExercises.append(copiedPlannedExercise)
                    }
                }
            }
        }

        do {
            try context.save()
            return copy
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Hide or Delete

    @discardableResult
    static func hideOrDeleteResult(
        _ plan: WorkoutPlan,
        using context: ModelContext
    ) throws -> PlanArchiveOutcome {
        let outcome: PlanArchiveOutcome
        if let reason = try referenceReason(plan, using: context) {
            plan.isArchived = true
            plan.updatedAt = .now
            outcome = .archived(reason: reason)
        } else {
            context.delete(plan)
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

    // MARK: Restore

    static func restore(_ plan: WorkoutPlan, using context: ModelContext) throws {
        plan.isArchived = false
        plan.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Reference Check

    private static func referenceReason(
        _ plan: WorkoutPlan,
        using context: ModelContext
    ) throws -> String? {
        // Check for any runs (active, paused, completed, archived)
        if !plan.runs.isEmpty {
            let hasCompletedHistory = plan.runs.contains { $0.status == .completed || $0.status == .archived }
            let hasActiveRuns = plan.runs.contains { $0.status == .active || $0.status == .paused || $0.status == .testDayAvailable }

            if hasActiveRuns {
                return "This plan has an active or paused run. End the run first, or it will be archived to preserve run history."
            }
            if hasCompletedHistory {
                return "Referenced by completed plan run history. Archived so past progress remains unchanged."
            }
            return "Referenced by plan run records. Archived so run history remains valid."
        }

        // Also check via fetched runs in case inverse relationship is stale
        let allRuns = try context.fetch(FetchDescriptor<PlanRun>())
        if allRuns.contains(where: { $0.plan?.id == plan.id || $0.sourcePlanID == plan.id }) {
            return "Referenced by plan run records. Archived so run history remains valid."
        }

        // Check for completed workouts that reference this plan
        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        if allWorkouts.contains(where: { $0.sourcePlanRunID != nil && $0.sourceProgramDefinitionID == plan.sourceProgramDefinitionID && plan.sourceProgramDefinitionID != nil }) {
            return "Referenced by completed workout history. Archived so past workouts remain unchanged."
        }

        return nil
    }
}

// MARK: - Repeating Plan Lifecycle

/// Definition-level lifecycle operations for `RepeatingPlan`: rename, duplicate,
/// archive, restore, and reference-checked deletion.
enum RepeatingPlanArchiveService {

    // MARK: Rename

    static func rename(_ plan: RepeatingPlan, to newName: String, using context: ModelContext) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlanArchiveError.emptyName
        }
        plan.name = trimmed
        plan.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Duplicate

    @discardableResult
    static func duplicate(_ plan: RepeatingPlan, using context: ModelContext) throws -> RepeatingPlan {
        let copiedSlots = plan.orderedSlots.map { slot in
            RepeatingPlanSlot(
                orderIndex: slot.orderIndex,
                workoutTemplate: slot.workoutTemplate,
                templateIDSnapshot: slot.templateIDSnapshot,
                templateNameSnapshot: slot.templateNameSnapshot,
                preWorkoutMobilityRoutine: slot.preWorkoutMobilityRoutine,
                preWorkoutMobilityRoutineIDSnapshot: slot.preWorkoutMobilityRoutineIDSnapshot,
                preWorkoutMobilityRoutineNameSnapshot: slot.preWorkoutMobilityRoutineNameSnapshot,
                postWorkoutMobilityRoutine: slot.postWorkoutMobilityRoutine,
                postWorkoutMobilityRoutineIDSnapshot: slot.postWorkoutMobilityRoutineIDSnapshot,
                postWorkoutMobilityRoutineNameSnapshot: slot.postWorkoutMobilityRoutineNameSnapshot
            )
        }

        let copy = RepeatingPlan(
            name: "\(plan.name) Copy",
            goal: plan.goal,
            experienceLevel: plan.experienceLevel,
            requiredEquipment: plan.requiredEquipment,
            notes: plan.notes,
            isArchived: false,
            isBuiltIn: false,
            slots: copiedSlots
        )
        context.insert(copy)

        do {
            try context.save()
            return copy
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Hide or Delete

    @discardableResult
    static func hideOrDeleteResult(
        _ plan: RepeatingPlan,
        using context: ModelContext
    ) throws -> PlanArchiveOutcome {
        let outcome: PlanArchiveOutcome
        if plan.isBuiltIn {
            plan.isArchived = true
            plan.updatedAt = .now
            outcome = .archived(reason: "System rotations are archived to preserve starter content.")
        } else if let reason = try referenceReason(plan, using: context) {
            plan.isArchived = true
            plan.updatedAt = .now
            outcome = .archived(reason: reason)
        } else {
            context.delete(plan)
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

    // MARK: Restore

    static func restore(_ plan: RepeatingPlan, using context: ModelContext) throws {
        plan.isArchived = false
        plan.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Reference Check

    private static func referenceReason(
        _ plan: RepeatingPlan,
        using context: ModelContext
    ) throws -> String? {
        // Check for any runs (active, paused, ended)
        if !plan.runs.isEmpty {
            let hasActiveRuns = plan.runs.contains { $0.status == .active || $0.status == .paused }
            if hasActiveRuns {
                return "This rotation has an active or paused run. End the run first, or it will be archived to preserve run history."
            }
            // Ended runs still contain occurrence history
            let hasOccurrenceHistory = plan.runs.contains { !$0.occurrences.isEmpty }
            if hasOccurrenceHistory {
                return "Referenced by completed rotation history. Archived so past workout occurrences remain unchanged."
            }
            return "Referenced by rotation run records. Archived so run history remains valid."
        }

        // Also check via fetched runs in case inverse relationship is stale
        let allRuns = try context.fetch(FetchDescriptor<RepeatingPlanRun>())
        if allRuns.contains(where: { $0.plan?.id == plan.id || $0.sourcePlanID == plan.id }) {
            return "Referenced by rotation run records. Archived so run history remains valid."
        }

        return nil
    }
}

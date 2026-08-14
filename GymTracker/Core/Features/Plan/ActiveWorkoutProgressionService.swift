import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
/// Applies rules whose cadence is meaningful only while the active workout is
/// still editable. Completed-workout evaluation deliberately excludes these
/// cadences, preserving a single source of truth for each progression event.
enum ActiveWorkoutProgressionService {
    static func applyAfterCompleting(
        set: ExerciseSet,
        in entry: ExerciseEntry,
        workout: Workout,
        modelContext: ModelContext
    ) {
        guard
            let runID = workout.sourcePlanRunID,
            let plannedExerciseID = entry.sourcePlannedExerciseID,
            let rulesData = entry.prescriptionRulesData,
            let rules = try? JSONDecoder().decode([ProgressionRuleDefinition].self, from: rulesData),
            !rules.isEmpty,
            let run = planRun(id: runID, in: modelContext),
            let plannedExercise = run.plan?.orderedWeeks
                .flatMap(\.orderedPlannedWorkouts)
                .flatMap(\.orderedPlannedExercises)
                .first(where: { $0.id == plannedExerciseID })
        else { return }

        if entry.selectedSubstituteExerciseIDSnapshot != nil,
           !entry.substitutionSharesProgressionState {
            return
        }

        let eventRules = rules.filter {
            $0.isEnabled && ($0.cadence == .immediately || $0.cadence == .nextSet)
        }
        guard !eventRules.isEmpty else { return }

        let sourceProgress = run.orderedWorkoutProgress.first {
            $0.plannedWorkoutID == workout.sourcePlannedWorkoutID
        }
        let sourceWeek = sourceProgress?.sourceWeekIndex ?? sourceProgress?.weekIndex ?? run.currentWeekIndex
        let sourceBlockIndex = run.plan?.orderedBlocks.firstIndex(where: {
            $0.orderedWeeks.contains { $0.weekIndex == sourceWeek }
        }) ?? 0
        let partialPerformance = PlanProgressionEvaluationService.performance(
            for: entry,
            workout: workout,
            run: run,
            plannedExercise: plannedExercise,
            state: PlanProgressionStateService.effectiveState(for: plannedExercise, in: run)
                ?? PlanExerciseProgressionState(progressionKey: plannedExercise.progressionKey),
            weekCompleted: false,
            blockCompleted: false,
            cycleCompleted: false,
            isPartialOccurrence: true
        )
        let groupedRules = Dictionary(grouping: eventRules, by: \.scope)
        for (scope, scopedRules) in groupedRules {
            let state = PlanProgressionStateService.stateForEvaluation(
                scope: scope,
                plannedExercise: plannedExercise,
                sourceProgress: sourceProgress,
                sourceBlockIndex: sourceBlockIndex,
                cadence: scopedRules.first?.cadence ?? .immediately,
                in: run
            )
            guard state.lastAppliedSetID != set.id else { continue }
            let evaluation = PlanProgressionCadenceService.state(from: state)
            guard let result = try? ProgramProgressionEvaluator.evaluate(
                rules: scopedRules,
                performance: partialPerformance,
                state: evaluation,
                variationLadder: plannedExercise.variationLadderData
                    .flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                stageDefinitions: plannedExercise.progressionStagesData
                    .flatMap { try? JSONDecoder().decode(ProgramStageConfiguration.self, from: $0) }?.stages ?? [],
                automaticCadences: [.immediately, .nextSet]
            ) else { continue }

            PlanProgressionCadenceService.apply(result.state, to: state)
            state.lastAppliedSetID = set.id

            for recommendation in result.recommendations where recommendation.applicationMode == .recommendation {
                // A threshold may remain true after it first fires (for
                // example, a fourth attempt after the three-miss advisory).
                // Preserve one decision receipt per rule/scope/workout instead
                // of producing duplicate recommendations for the same event.
                guard !hasRecommendation(
                    ruleID: recommendation.ruleID,
                    workoutID: workout.id,
                    scopeOwnerKey: state.scopeOwnerKey,
                    in: modelContext
                ) else { continue }
                guard let record = try? PlanProgressionRecommendationRecord(
                    recommendation: recommendation,
                    planRunID: run.id,
                    workoutID: workout.id,
                    scopeOwnerKey: state.scopeOwnerKey,
                    proposedLoadUnit: plannedExercise.suggestedLoadType
                ) else { continue }
                record.progressionKey = plannedExercise.progressionKey
                modelContext.insert(record)
            }
        }

        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: entry.usedMetric,
            preservingCompletedSets: true
        )
        run.updatedAt = .now
    }

    private static func planRun(id: UUID, in modelContext: ModelContext) -> PlanRun? {
        var descriptor = FetchDescriptor<PlanRun>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private static func hasRecommendation(
        ruleID: UUID,
        workoutID: UUID,
        scopeOwnerKey: String,
        in modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<PlanProgressionRecommendationRecord>(
            predicate: #Predicate {
                $0.ruleID == ruleID && $0.workoutID == workoutID
            }
        )
        return (try? modelContext.fetch(descriptor))?.contains {
            $0.scopeOwnerKey == scopeOwnerKey
        } == true
    }
}
#endif

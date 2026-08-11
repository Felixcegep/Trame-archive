import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
@MainActor
enum PlanProgressionRecommendationService {
    /// Builds the exact read-only contract shown before a receipt decision.
    /// This uses the same scoped-state lookup and due-state projection as
    /// acceptance, but performs no persistence or mutation.
    static func preview(
        _ recommendation: PlanProgressionRecommendationRecord,
        in run: PlanRun,
        newEvidenceSinceDecline: Bool = false
    ) -> ProgressionRecommendationPreview {
        let currentPrescription = state(for: recommendation, in: run).map {
            PlanProgressionCadenceService.projectedState(for: $0, in: run)
        }
        return ProgressionRecommendationPreviewPolicy.make(
            for: recommendation,
            currentPrescription: currentPrescription,
            in: run,
            newEvidenceSinceDecline: newEvidenceSinceDecline
        )
    }

    static func accept(
        _ recommendation: PlanProgressionRecommendationRecord,
        in run: PlanRun,
        context: ModelContext
    ) throws {
        guard !recommendation.isResolved else { return }
        do {
            if try ActiveWorkoutRecommendationMutationService.applyIfSupported(
                recommendation,
                in: context
            ) {
                recommendation.isResolved = true
                recommendation.resolvedAt = .now
                recommendation.decisionOutcome = .accepted
                try context.save()
                return
            }
            guard let state = state(for: recommendation, in: run) else { return }
            try accept(recommendation, using: state, overridingLoadWith: nil, in: run)
            recommendation.isResolved = true
            recommendation.resolvedAt = .now
            recommendation.decisionOutcome = .accepted
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Accepts the recommendation with a load different from `proposedLoad`.
    /// Both the original proposal (`proposedLoad`) and the value actually
    /// applied (`appliedLoad`) survive on the record afterward.
    static func accept(
        _ recommendation: PlanProgressionRecommendationRecord,
        withLoad load: Double,
        in run: PlanRun,
        context: ModelContext
    ) throws {
        guard !recommendation.isResolved else { return }
        if case .endActiveDailyMaximumAndGenerateBackOffs = try recommendation.action() {
            // This structural action has an authored percentage, not an
            // editable absolute load. Preserve the proposal rather than
            // accepting an unrelated override value.
            throw ActiveWorkoutRecommendationMutationService.MutationError.invalidActionParameters
        }
        guard let state = state(for: recommendation, in: run) else { return }
        do {
            try accept(recommendation, using: state, overridingLoadWith: load, in: run)
            recommendation.isResolved = true
            recommendation.resolvedAt = .now
            recommendation.decisionOutcome = .acceptedWithModifiedValue
            recommendation.appliedLoad = load
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Declines the recommendation. Declining is a legitimate, ordinary user
    /// choice: it must never be surfaced or logged as failure or
    /// noncompliance.
    static func decline(_ recommendation: PlanProgressionRecommendationRecord, context: ModelContext) throws {
        do {
            recommendation.isResolved = true
            recommendation.resolvedAt = .now
            recommendation.decisionOutcome = .declined
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func apply(
        proposedState recommendation: PlanProgressionRecommendationRecord,
        to state: PlanExerciseProgressionState
    ) {
        state.currentLoad = recommendation.proposedLoad
        state.trainingMax = recommendation.proposedTrainingMax
        state.estimatedOneRepMax = recommendation.proposedEstimatedOneRepMax
        state.actualOneRepMax = recommendation.proposedActualOneRepMax
        state.currentStageID = recommendation.proposedStageID
        state.currentVariationExerciseID = recommendation.proposedVariationExerciseID
        state.repetitionOffset = recommendation.proposedRepetitionOffset
        state.setCountOffset = recommendation.proposedSetCountOffset
        state.durationOffset = recommendation.proposedDurationOffset
        state.distanceOffset = recommendation.proposedDistanceOffset
        state.restDurationOffset = recommendation.proposedRestDurationOffset
        state.caloriesOffset = recommendation.proposedCaloriesOffset
        state.currentWaveIndex = recommendation.proposedWaveIndex
        state.currentBlockIndex = recommendation.proposedBlockIndex
        state.isDeloading = recommendation.proposedIsDeloading
    }

    private static func state(
        for recommendation: PlanProgressionRecommendationRecord,
        in run: PlanRun
    ) -> PlanExerciseProgressionState? {
        if let scopedState = run.progressionStates.first(where: {
            guard $0.progressionKey == recommendation.progressionKey,
                  ProgressionScope(rawValue: $0.scopeRaw) == recommendation.scope else { return false }
            let owner = $0.scopeOwnerKey.isEmpty && recommendation.scope == .exerciseExposure
                ? $0.progressionKey
                : $0.scopeOwnerKey
            return recommendation.scopeOwnerKey.isEmpty
                ? recommendation.scope == .exerciseExposure
                : owner == recommendation.scopeOwnerKey
        }) {
            return scopedState
        }

        // Backups created before owner keys existed may carry a wider rule
        // scope but only retain the original exposure record. Continue to
        // honor a user-approved legacy recommendation rather than leaving it
        // permanently un-actionable after the scoped-state migration.
        guard recommendation.scopeOwnerKey.isEmpty else { return nil }
        return run.progressionStates.first {
            $0.progressionKey == recommendation.progressionKey
                && ProgressionScope(rawValue: $0.scopeRaw) == .exerciseExposure
        }
    }

    private static func accept(
        _ recommendation: PlanProgressionRecommendationRecord,
        using state: PlanExerciseProgressionState,
        overridingLoadWith load: Double?,
        in run: PlanRun
    ) throws {
        guard let sourceProgress = run.orderedWorkoutProgress.first(where: {
            $0.completedWorkout?.id == recommendation.workoutID
        }) else {
            // Legacy recommendations may not have a retained progress link.
            // Preserve their historic accept behavior rather than dropping a
            // user-confirmed future change.
            apply(proposedState: recommendation, to: state)
            if let load { state.currentLoad = load }
            removePending(for: recommendation, from: state)
            return
        }

        if PlanProgressionTransitionService.isDue(
            recommendation,
            sourceProgress: sourceProgress,
            in: run
        ) {
            apply(proposedState: recommendation, to: state)
            if let load { state.currentLoad = load }
            removePending(for: recommendation, from: state)
            _ = PlanProgressionTransitionService.applyAcceptedRecommendation(
                recommendation,
                progressionKey: state.progressionKey,
                sourceProgress: sourceProgress,
                in: run
            )
        } else {
            var pending = (state.pendingProgressionData.flatMap {
                try? JSONDecoder().decode([PendingProgressionState].self, from: $0)
            } ?? [])
            let proposedState = proposedState(for: recommendation, overridingLoadWith: load)
            let candidate = PendingProgressionState(
                ruleID: recommendation.ruleID,
                sourceWorkoutID: recommendation.workoutID,
                action: try recommendation.action(),
                cadence: recommendation.cadence,
                scope: recommendation.scope,
                state: proposedState,
                sourceWeekIndex: sourceProgress.weekIndex,
                sourceWorkoutIndex: sourceProgress.workoutIndex,
                sourceBlockIndex: sourceBlockIndex(for: sourceProgress, in: run),
                createdAt: .now
            )
            pending.removeAll {
                $0.ruleID == candidate.ruleID
                    && $0.sourceWorkoutID == candidate.sourceWorkoutID
                    && $0.cadence == candidate.cadence
                    && $0.scope == candidate.scope
            }
            pending.append(candidate)
            state.pendingProgressionData = try JSONEncoder().encode(pending)
        }
    }

    private static func proposedState(
        for recommendation: PlanProgressionRecommendationRecord,
        overridingLoadWith load: Double?
    ) -> ProgressionEvaluationState {
        ProgressionEvaluationState(
            currentLoad: load ?? recommendation.proposedLoad,
            repetitionOffset: recommendation.proposedRepetitionOffset,
            setCountOffset: recommendation.proposedSetCountOffset,
            durationOffset: recommendation.proposedDurationOffset,
            distanceOffset: recommendation.proposedDistanceOffset,
            restDurationOffset: recommendation.proposedRestDurationOffset,
            caloriesOffset: recommendation.proposedCaloriesOffset,
            currentStageID: recommendation.proposedStageID,
            currentVariationExerciseID: recommendation.proposedVariationExerciseID,
            currentWaveIndex: recommendation.proposedWaveIndex,
            currentBlockIndex: recommendation.proposedBlockIndex,
            trainingMax: recommendation.proposedTrainingMax,
            estimatedOneRepMax: recommendation.proposedEstimatedOneRepMax,
            actualOneRepMax: recommendation.proposedActualOneRepMax,
            isDeloading: recommendation.proposedIsDeloading
        )
    }

    private static func sourceBlockIndex(
        for progress: PlanWorkoutProgress,
        in run: PlanRun
    ) -> Int {
        let sourceWeek = progress.sourceWeekIndex ?? progress.weekIndex
        return run.plan?.orderedBlocks.firstIndex(where: {
            $0.orderedWeeks.contains { $0.weekIndex == sourceWeek }
        }) ?? 0
    }

    private static func removePending(
        for recommendation: PlanProgressionRecommendationRecord,
        from state: PlanExerciseProgressionState
    ) {
        guard let data = state.pendingProgressionData,
              let pending = try? JSONDecoder().decode([PendingProgressionState].self, from: data) else {
            return
        }
        let remaining = pending.filter {
            !($0.ruleID == recommendation.ruleID
                && $0.sourceWorkoutID == recommendation.workoutID
                && $0.cadence == recommendation.cadence
                && $0.scope == recommendation.scope)
        }
        state.pendingProgressionData = try? JSONEncoder().encode(remaining)
    }
}
#endif

import Foundation

#if !GYMTRACKER_EXTENSION
/// Applies automatic run-level progression actions after the completed workout
/// has been linked to its `PlanRun`. It only changes unfinished progress;
/// completed History and the immutable workout that produced the action are
/// deliberately out of scope.
enum PlanProgressionTransitionService {
    /// A recommendation is not merely explanatory: once the user accepts it,
    /// its structural action follows the exact same scope and cadence rules as
    /// an automatic policy. The caller queues the proposed numeric state when
    /// this returns `false`; this method deliberately never makes a future
    /// transition happen early.
    @discardableResult
    static func applyAcceptedRecommendation(
        _ recommendation: PlanProgressionRecommendationRecord,
        progressionKey: String,
        sourceProgress: PlanWorkoutProgress,
        in run: PlanRun
    ) -> Bool {
        guard isDue(recommendation, sourceProgress: sourceProgress, in: run) else {
            return false
        }
        let changed = apply(
            try? recommendation.action(),
            scope: recommendation.scope,
            progressionKey: progressionKey,
            sourceProgress: sourceProgress,
            in: run
        )
        if changed { PlanCoordinator.refreshAvailability(for: run) }
        return changed
    }

    /// This is shared with recommendation acceptance so a manual decision
    /// cannot bypass a rule's declared future boundary.
    static func isDue(
        _ recommendation: PlanProgressionRecommendationRecord,
        sourceProgress: PlanWorkoutProgress,
        in run: PlanRun
    ) -> Bool {
        switch recommendation.cadence {
        case .immediately, .nextSet, .nextExerciseOccurrence, .nextWorkout:
            return true
        case .nextWeek:
            return run.currentWeekIndex > sourceProgress.weekIndex
                || recommendation.performance()?.weekCompleted == true
                    && run.currentWeekIndex != sourceProgress.weekIndex
        case .nextWave:
            return run.currentWeekIndex > sourceProgress.weekIndex
                || (run.currentWeekIndex == sourceProgress.weekIndex
                    && run.currentWorkoutIndex > sourceProgress.workoutIndex)
                || recommendation.performance()?.waveCompleted == true
        case .nextBlock:
            let sourceBlock = sourceBlockWeekIndices(for: sourceProgress, in: run)
            return !sourceBlock.contains(run.currentWeekIndex)
                || recommendation.performance()?.blockCompleted == true
        case .nextCycle:
            return run.status == .completed
                || recommendation.performance()?.cycleCompleted == true
        }
    }

    @discardableResult
    static func applyAutomaticTransitions(
        _ results: [PlanExerciseProgressionResult],
        sourceProgress: PlanWorkoutProgress,
        in run: PlanRun
    ) -> Bool {
        let automaticResults = results.map { result in
            (
                progressionKey: result.progressionKey,
                recommendations: result.recommendations.filter {
                    $0.applicationMode == .automatic && isDueAtCompletion($0)
                }
            )
        }
        var changed = false

        for result in automaticResults {
            for recommendation in result.recommendations {
                changed = apply(
                    recommendation.action,
                    scope: recommendation.scope,
                    progressionKey: result.progressionKey,
                    sourceProgress: sourceProgress,
                    in: run
                ) || changed
                if run.status == .completed { return true }
            }
        }

        if changed {
            PlanCoordinator.refreshAvailability(for: run)
        }
        return changed
    }

    /// Applies structural actions stored with due cadence state. The caller
    /// invokes this before `applyDueStates` clears those records.
    @discardableResult
    static func applyDuePendingTransitions(
        sourceProgress: PlanWorkoutProgress? = nil,
        in run: PlanRun,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Bool {
        guard run.status == .active else { return false }
        var changed = false
        for state in run.progressionStates {
            guard let data = state.pendingProgressionData,
                  let pending = try? decoder.decode([PendingProgressionState].self, from: data) else {
                continue
            }
            for candidate in pending where PlanProgressionCadenceService.isDue(candidate, in: run) {
                guard let action = candidate.action else { continue }
                guard let origin = sourceProgress ?? originProgress(for: candidate, in: run) else { continue }
                changed = apply(
                    action,
                    scope: candidate.scope,
                    progressionKey: state.progressionKey,
                    sourceProgress: origin,
                    in: run
                ) || changed
                if run.status == .completed { return true }
            }
        }
        if changed { PlanCoordinator.refreshAvailability(for: run) }
        return changed
    }

    static func isExerciseEnded(_ progressionKey: String, in run: PlanRun) -> Bool {
        endedExerciseKeys(in: run).contains(progressionKey)
    }

    private static func isDueAtCompletion(_ recommendation: ProgressionRecommendation) -> Bool {
        switch recommendation.cadence {
        case .immediately, .nextSet, .nextExerciseOccurrence, .nextWorkout:
            return true
        case .nextWeek:
            return recommendation.performance.weekCompleted
        case .nextWave:
            return recommendation.performance.waveCompleted
        case .nextBlock:
            return recommendation.performance.blockCompleted
        case .nextCycle:
            return recommendation.performance.cycleCompleted
        }
    }

    private static func apply(
        _ action: ProgressionAction?,
        scope: ProgressionScope,
        progressionKey: String,
        sourceProgress: PlanWorkoutProgress,
        in run: PlanRun
    ) -> Bool {
        guard let action else { return false }
        switch action {
        case .advanceWeek where scope == .week || scope == .programRun:
            return skipUnfinished(
                run.orderedWorkoutProgress.filter { $0.weekIndex == sourceProgress.weekIndex },
                reason: "Advanced by program rule"
            )
        case .advanceBlock where scope == .block || scope == .programRun:
            let blockWeeks = sourceBlockWeekIndices(for: sourceProgress, in: run)
            return skipUnfinished(
                run.orderedWorkoutProgress.filter { blockWeeks.contains($0.weekIndex) },
                reason: "Advanced by program rule"
            )
        case .repeatWeek where scope == .week || scope == .programRun:
            return PlanCoordinator.repeatWeek(containing: sourceProgress, in: run)
        case .restartBlock where scope == .block || scope == .programRun:
            return PlanCoordinator.restartBlock(containing: sourceProgress, in: run)
        case .endExercise:
            return endExercise(progressionKey, in: run)
        case .endProgram:
            let testDayProgress: PlanWorkoutProgress?
            if run.plan?.programCompletionPolicy == .offerTestDay {
                testDayProgress = run.orderedWorkoutProgress.first { progress in
                    progress.status != .completed
                        && progress.status != .skipped
                        && run.plan?.orderedWeeks
                            .flatMap(\.orderedPlannedWorkouts)
                            .first(where: { $0.id == progress.plannedWorkoutID })?.isTestDay == true
                }
            } else {
                testDayProgress = nil
            }
            let skipped = skipUnfinished(
                run.orderedWorkoutProgress.filter { $0.id != testDayProgress?.id },
                reason: "Ended by program rule"
            )
            if let testDayProgress {
                testDayProgress.status = .available
                testDayProgress.skipReason = nil
                run.status = .testDayAvailable
                run.endDate = .now
                run.updatedAt = .now
                return skipped || testDayProgress.status == .available
            }
            let changedStatus = run.status != .completed
            run.status = .completed
            run.endDate = .now
            run.updatedAt = .now
            return skipped || changedStatus
        default:
            return false
        }
    }

    private static func endExercise(_ progressionKey: String, in run: PlanRun) -> Bool {
        var keys = endedExerciseKeys(in: run)
        guard keys.insert(progressionKey).inserted else { return false }
        run.endedProgressionKeysData = try? JSONEncoder().encode(keys)
        run.updatedAt = .now
        return true
    }

    private static func endedExerciseKeys(in run: PlanRun) -> Set<String> {
        guard let data = run.endedProgressionKeysData,
              let keys = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return keys
    }

    private static func sourceBlockWeekIndices(for progress: PlanWorkoutProgress, in run: PlanRun) -> Set<Int> {
        guard let block = run.plan?.orderedBlocks.first(where: {
            $0.orderedWeeks.contains { $0.weekIndex == (progress.sourceWeekIndex ?? progress.weekIndex) }
        }) else {
            return [progress.weekIndex]
        }
        return Set(block.orderedWeeks.map(\.weekIndex))
    }

    private static func originProgress(
        for pending: PendingProgressionState,
        in run: PlanRun
    ) -> PlanWorkoutProgress? {
        if let workoutID = pending.sourceWorkoutID,
           let linked = run.orderedWorkoutProgress.first(where: { $0.completedWorkout?.id == workoutID }) {
            return linked
        }
        return run.orderedWorkoutProgress.first {
            $0.weekIndex == pending.sourceWeekIndex
                && $0.workoutIndex == pending.sourceWorkoutIndex
        }
    }

    private static func skipUnfinished(_ progress: [PlanWorkoutProgress], reason: String) -> Bool {
        var changed = false
        for item in progress where item.status == .upcoming || item.status == .available {
            item.status = .skipped
            item.completedAt = .now
            item.skipReason = reason
            changed = true
        }
        return changed
    }
}
#endif

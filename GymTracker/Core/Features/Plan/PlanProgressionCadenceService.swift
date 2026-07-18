import Foundation

#if !GYMTRACKER_EXTENSION
/// Promotes automatic progression that has crossed its declared cadence
/// boundary. Evaluation writes future state once from immutable workout
/// evidence; this service is the only place that turns it into mutable run
/// state. Keeping that boundary explicit prevents a relaunch or a second
/// snapshot from applying the same outcome twice.
enum PlanProgressionCadenceService {
    @discardableResult
    static func applyDueStates(in run: PlanRun, decoder: JSONDecoder = JSONDecoder(), encoder: JSONEncoder = JSONEncoder()) -> Bool {
        var changed = false
        for persisted in run.progressionStates {
            guard let data = persisted.pendingProgressionData,
                  let pending = try? decoder.decode([PendingProgressionState].self, from: data) else {
                continue
            }

            let ordered = pending.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.ruleID?.uuidString ?? "" < rhs.ruleID?.uuidString ?? ""
            }
            let due = ordered.filter { isDue($0, in: run) }
            guard !due.isEmpty else { continue }

            for candidate in due {
                apply(candidate.state, to: persisted)
            }
            let remaining = ordered.filter { !isDue($0, in: run) }
            persisted.pendingProgressionData = remaining.isEmpty ? nil : try? encoder.encode(remaining)
            changed = true
        }
        return changed
    }

    static func projectedState(
        for persisted: PlanExerciseProgressionState,
        in run: PlanRun,
        decoder: JSONDecoder = JSONDecoder()
    ) -> ProgressionEvaluationState {
        var state = state(from: persisted)
        guard let data = persisted.pendingProgressionData,
              let pending = try? decoder.decode([PendingProgressionState].self, from: data) else {
            return state
        }
        for candidate in pending.sorted(by: { $0.createdAt < $1.createdAt }) where isDue(candidate, in: run) {
            state = candidate.state
        }
        return state
    }

    static func state(from persisted: PlanExerciseProgressionState) -> ProgressionEvaluationState {
        ProgressionEvaluationState(
            currentLoad: persisted.currentLoad,
            repetitionOffset: persisted.repetitionOffset,
            setCountOffset: persisted.setCountOffset,
            durationOffset: persisted.durationOffset,
            distanceOffset: persisted.distanceOffset,
            restDurationOffset: persisted.restDurationOffset,
            caloriesOffset: persisted.caloriesOffset,
            currentStageID: persisted.currentStageID,
            currentVariationExerciseID: persisted.currentVariationExerciseID,
            currentWaveIndex: persisted.currentWaveIndex ?? 0,
            currentBlockIndex: persisted.currentBlockIndex ?? 0,
            trainingMax: persisted.trainingMax,
            estimatedOneRepMax: persisted.estimatedOneRepMax,
            actualOneRepMax: persisted.actualOneRepMax,
            failureCount: persisted.failureCount,
            successCount: persisted.successCount,
            previousAMRAPRepetitions: persisted.previousAMRAPRepetitions,
            previousActualRPE: persisted.previousActualRPE,
            previousActualRIR: persisted.previousActualRIR,
            isDeloading: persisted.isDeloading,
            velocityBaseline: persisted.velocityBaseline
        )
    }

    static func apply(_ state: ProgressionEvaluationState, to persisted: PlanExerciseProgressionState) {
        persisted.currentLoad = state.currentLoad
        persisted.repetitionOffset = state.repetitionOffset
        persisted.setCountOffset = state.setCountOffset
        persisted.durationOffset = state.durationOffset
        persisted.distanceOffset = state.distanceOffset
        persisted.restDurationOffset = state.restDurationOffset
        persisted.caloriesOffset = state.caloriesOffset
        persisted.currentStageID = state.currentStageID
        persisted.currentVariationExerciseID = state.currentVariationExerciseID
        persisted.currentWaveIndex = state.currentWaveIndex
        persisted.currentBlockIndex = state.currentBlockIndex
        persisted.trainingMax = state.trainingMax
        persisted.estimatedOneRepMax = state.estimatedOneRepMax
        persisted.actualOneRepMax = state.actualOneRepMax
        persisted.failureCount = state.failureCount
        persisted.successCount = state.successCount
        persisted.previousAMRAPRepetitions = state.previousAMRAPRepetitions
        persisted.previousActualRPE = state.previousActualRPE
        persisted.previousActualRIR = state.previousActualRIR
        persisted.velocityBaseline = state.velocityBaseline
        persisted.isDeloading = state.isDeloading
    }

    static func isDue(_ pending: PendingProgressionState, in run: PlanRun) -> Bool {
        let current = (run.currentWeekIndex, run.currentWorkoutIndex)
        let source = (pending.sourceWeekIndex, pending.sourceWorkoutIndex)
        switch pending.cadence {
        case .immediately, .nextSet, .nextExerciseOccurrence, .nextWorkout:
            return true
        case .nextWeek:
            return current.0 > source.0
        case .nextWave:
            return current.0 > source.0 || (current.0 == source.0 && current.1 > source.1)
        case .nextBlock:
            let currentBlock = run.plan?.orderedBlocks.firstIndex(where: { $0.orderedWeeks.contains { $0.weekIndex == current.0 } }) ?? 0
            return currentBlock > pending.sourceBlockIndex
        case .nextCycle:
            return run.status == .completed
        }
    }
}
#endif

import Foundation

#if !GYMTRACKER_EXTENSION
/// Stable identity for mutable progression state. The exposure key remains
/// part of every address so a week-level bench rule cannot accidentally alter
/// the independently programmed volume or technique bench exposure.
struct ProgressionStateAddress: Codable, Hashable {
    var progressionKey: String
    var scope: ProgressionScope
    var ownerKey: String
}

/// Resolves mutable progression state without putting scheduling identity into
/// `ProgramDefinition`. A plan recipe stays reusable; only a concrete run
/// decides which week, workout, block, or cycle owns a scoped value.
enum PlanProgressionStateService {
    static func stateForEvaluation(
        scope: ProgressionScope,
        plannedExercise: PlannedExercise,
        sourceProgress: PlanWorkoutProgress?,
        sourceBlockIndex: Int,
        cadence: ProgressionCadence,
        in run: PlanRun
    ) -> PlanExerciseProgressionState {
        let address = evaluationAddress(
            scope: scope,
            plannedExercise: plannedExercise,
            sourceProgress: sourceProgress,
            sourceBlockIndex: sourceBlockIndex,
            cadence: cadence,
            in: run
        )
        if let existing = run.progressionStates.first(where: { matches($0, address: address) }) {
            return existing
        }

        let seed = effectiveState(for: plannedExercise, in: run)
            ?? run.progressionStates.first(where: {
                $0.progressionKey == plannedExercise.progressionKey && Self.scope(of: $0) == .exerciseExposure
            })
        let created = copy(seed, for: address)
        run.progressionStates.append(created)
        return created
    }

    /// The state applied while snapshotting a future workout. A scoped state
    /// only participates when its owner matches the run's current position;
    /// otherwise its values cannot leak into another week/block/workout.
    static func effectiveState(
        for plannedExercise: PlannedExercise,
        in run: PlanRun
    ) -> PlanExerciseProgressionState? {
        let addresses = ProgressionScope.allCases.map {
            currentAddress(scope: $0, plannedExercise: plannedExercise, in: run)
        }
        let matchesByScope = addresses.compactMap { address in
            run.progressionStates.first(where: { matches($0, address: address) })
        }
        return matchesByScope.min { scopePriority(scope(of: $0)) < scopePriority(scope(of: $1)) }
            ?? run.progressionStates.first(where: {
                $0.progressionKey == plannedExercise.progressionKey
                    && scope(of: $0) == .exerciseExposure
            })
    }

    static func currentAddress(
        scope: ProgressionScope,
        plannedExercise: PlannedExercise,
        in run: PlanRun
    ) -> ProgressionStateAddress {
        let currentBlock = blockIndex(forWeek: run.currentWeekIndex, in: run)
        return ProgressionStateAddress(
            progressionKey: plannedExercise.progressionKey,
            scope: scope,
            ownerKey: ownerKey(
                scope: scope,
                plannedExercise: plannedExercise,
                weekIndex: run.currentWeekIndex,
                workoutIndex: run.currentWorkoutIndex,
                blockIndex: currentBlock,
                run: run
            )
        )
    }

    private static func evaluationAddress(
        scope: ProgressionScope,
        plannedExercise: PlannedExercise,
        sourceProgress: PlanWorkoutProgress?,
        sourceBlockIndex: Int,
        cadence: ProgressionCadence,
        in run: PlanRun
    ) -> ProgressionStateAddress {
        let sourceWeek = sourceProgress?.weekIndex ?? run.currentWeekIndex
        let sourceWorkout = sourceProgress?.workoutIndex ?? run.currentWorkoutIndex
        let targetWeek = sourceWeek + (scope == .week && cadence == .nextWeek ? 1 : 0)
        let targetWorkout = sourceWorkout + (scope == .workout && cadence == .nextWorkout ? 1 : 0)
        let targetBlock = sourceBlockIndex + (scope == .block && cadence == .nextBlock ? 1 : 0)
        return ProgressionStateAddress(
            progressionKey: plannedExercise.progressionKey,
            scope: scope,
            ownerKey: ownerKey(
                scope: scope,
                plannedExercise: plannedExercise,
                weekIndex: targetWeek,
                workoutIndex: targetWorkout,
                blockIndex: targetBlock,
                run: run
            )
        )
    }

    private static func ownerKey(
        scope: ProgressionScope,
        plannedExercise: PlannedExercise,
        weekIndex: Int,
        workoutIndex: Int,
        blockIndex: Int,
        run: PlanRun
    ) -> String {
        switch scope {
        case .set:
            // Per-set mutable execution is owned by the active-workout event
            // pipeline. Until that pipeline evaluates next-set rules, this is
            // a stable plan-set namespace rather than an exercise-wide value.
            return "set:\(plannedExercise.id.uuidString)"
        case .plannedExercise:
            return "planned:\(plannedExercise.id.uuidString)"
        case .exerciseExposure:
            return plannedExercise.progressionKey
        case .workout:
            return "workout:\(weekIndex):\(workoutIndex)"
        case .week:
            return "week:\(weekIndex)"
        case .block:
            return "block:\(blockIndex)"
        case .cycle:
            // A restarted run starts a new PlanRun; the run identity is the
            // stable cycle boundary until repeat-cycle UI is introduced.
            return "cycle:\(run.id.uuidString)"
        case .programRun:
            return "run:\(run.id.uuidString)"
        }
    }

    private static func matches(
        _ state: PlanExerciseProgressionState,
        address: ProgressionStateAddress
    ) -> Bool {
        guard state.progressionKey == address.progressionKey, scope(of: state) == address.scope else {
            return false
        }
        let owner = state.scopeOwnerKey.isEmpty && scope(of: state) == .exerciseExposure
            ? state.progressionKey
            : state.scopeOwnerKey
        return owner == address.ownerKey
    }

    private static func scope(of state: PlanExerciseProgressionState) -> ProgressionScope {
        ProgressionScope(rawValue: state.scopeRaw) ?? .exerciseExposure
    }

    private static func scopePriority(_ scope: ProgressionScope) -> Int {
        switch scope {
        case .set: 0
        case .plannedExercise: 1
        case .workout: 2
        case .week: 3
        case .block: 4
        case .cycle: 5
        case .programRun: 6
        case .exerciseExposure: 7
        }
    }

    private static func blockIndex(forWeek weekIndex: Int, in run: PlanRun) -> Int {
        run.plan?.orderedBlocks.firstIndex(where: {
            $0.orderedWeeks.contains { $0.weekIndex == weekIndex }
        }) ?? 0
    }

    private static func copy(
        _ source: PlanExerciseProgressionState?,
        for address: ProgressionStateAddress
    ) -> PlanExerciseProgressionState {
        PlanExerciseProgressionState(
            progressionKey: address.progressionKey,
            scopeRaw: address.scope.rawValue,
            scopeOwnerKey: address.ownerKey,
            currentLoad: source?.currentLoad,
            currentLoadType: source?.currentLoadType,
            repetitionOffset: source?.repetitionOffset ?? 0,
            setCountOffset: source?.setCountOffset ?? 0,
            durationOffset: source?.durationOffset ?? 0,
            distanceOffset: source?.distanceOffset ?? 0,
            restDurationOffset: source?.restDurationOffset ?? 0,
            caloriesOffset: source?.caloriesOffset ?? 0,
            currentStageID: source?.currentStageID,
            currentVariationExerciseID: source?.currentVariationExerciseID,
            trainingMax: source?.trainingMax,
            estimatedOneRepMax: source?.estimatedOneRepMax,
            actualOneRepMax: source?.actualOneRepMax,
            failureCount: source?.failureCount ?? 0,
            successCount: source?.successCount ?? 0,
            currentWaveIndex: source?.currentWaveIndex,
            currentBlockIndex: source?.currentBlockIndex,
            previousAMRAPRepetitions: source?.previousAMRAPRepetitions,
            previousActualRPE: source?.previousActualRPE,
            previousActualRIR: source?.previousActualRIR,
            lastCompletedOccurrence: source?.lastCompletedOccurrence,
            lastSuccessfulLoad: source?.lastSuccessfulLoad,
            isDeloading: source?.isDeloading ?? false,
            lastAppliedSetID: source?.lastAppliedSetID,
            appliedProgressionEventsData: source?.appliedProgressionEventsData
        )
    }
}
#endif

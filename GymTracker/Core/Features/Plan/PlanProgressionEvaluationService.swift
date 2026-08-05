import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

struct PlanExerciseProgressionResult {
    let progressionKey: String
    let recommendations: [ProgressionRecommendation]
}

private struct ScopedRuleGroup: Hashable {
    var scope: ProgressionScope
    var cadence: ProgressionCadence

    var sortKey: String { "\(scope.rawValue):\(cadence.rawValue)" }
}

private struct AppliedProgressionEvent: Codable, Hashable {
    var workoutID: UUID
    var cadence: ProgressionCadence
}

enum PlanProgressionEvaluationService {
    /// Evaluates only rules captured on the workout snapshot. This keeps a
    /// completed workout stable if its source plan is edited later.
    static func evaluateAndApply(
        workout: Workout,
        run: PlanRun,
        modelContext: ModelContext? = nil
    ) throws -> [PlanExerciseProgressionResult] {
        // Earlier occurrences may have crossed a cadence boundary while the
        // app was not running. Promote them before using state as formula
        // input for this immutable completion event.
        _ = PlanProgressionCadenceService.applyDueStates(in: run)
        var results: [PlanExerciseProgressionResult] = []
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let plannedExercises = run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .flatMap(\.orderedPlannedExercises) ?? []
        let plannedByID = Dictionary(uniqueKeysWithValues: plannedExercises.map { ($0.id, $0) })
        let sourceProgress = run.orderedWorkoutProgress.first { $0.completedWorkout?.id == workout.id }
        let occurrenceWeekIndex = sourceProgress?.weekIndex ?? run.currentWeekIndex
        let sourceWeekIndex = sourceProgress?.sourceWeekIndex ?? occurrenceWeekIndex
        let sourceWorkoutIndex = sourceProgress?.workoutIndex ?? run.currentWorkoutIndex
        let sourceBlockIndex = blockIndex(forWeek: sourceWeekIndex, in: run)
        let weekCompleted = isWeekCompleted(occurrenceWeekIndex, in: run, including: workout)
        let blockCompleted = isBlockCompleted(sourceBlockIndex, in: run, including: workout)
        let cycleProgress = run.orderedWorkoutProgress.filter { progress in
            guard run.plan?.programCompletionPolicy == .offerTestDay else { return true }
            return run.plan?.orderedWeeks
                .flatMap(\.orderedPlannedWorkouts)
                .first(where: { $0.id == progress.plannedWorkoutID })?.isTestDay != true
        }
        let cycleCompleted = !cycleProgress.isEmpty
            && cycleProgress.allSatisfy { isCompleted($0, including: workout) }
        var formulaContext = FormulaResolutionContext()
        let effectiveStates = plannedExercises.reduce(into: [String: PlanExerciseProgressionState]()) { result, planned in
            if let state = PlanProgressionStateService.effectiveState(for: planned, in: run) {
                result[planned.progressionKey] = state
            }
        }
        for state in effectiveStates.values {
            if let trainingMax = state.trainingMax { formulaContext.trainingMaxByExposure[state.progressionKey] = trainingMax }
            if let e1RM = state.estimatedOneRepMax { formulaContext.estimatedOneRepMaxByExposure[state.progressionKey] = e1RM }
            if let actualOneRepMax = state.actualOneRepMax { formulaContext.actualOneRepMaxByExposure[state.progressionKey] = actualOneRepMax }
            if let load = state.currentLoad { formulaContext.valuesByExposure[state.progressionKey] = load }
            if let baseline = state.velocityBaseline { formulaContext.velocityBaselineByExposure[state.progressionKey] = baseline }
        }
        for progress in run.orderedWorkoutProgress
            .filter({ $0.status == .completed })
            .sorted(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }) {
            guard let completedWorkout = progress.completedWorkout else { continue }
            for entry in completedWorkout.orderedExercises {
                guard let key = entry.progressionKey else { continue }
                let completedSets = entry.orderedSets.filter(\.done)
                guard !completedSets.isEmpty else { continue }
                var metrics: [ProgressionMetric: Double] = [:]
                let repetitions = completedSets.reduce(0) { $0 + Double($1.repetitions) }
                // Route through `VolumeCalculator`, the single source of truth
                // for weight × reps → training volume, rather than a local
                // formula: `ExerciseSet.weightType` is stored per set, so a
                // unit change mid-plan (or a unilateral/per-hand exercise)
                // would otherwise silently disagree with History/Analytics.
                // `.kg` is the target unit because it is this domain's
                // canonical unit elsewhere (`trainingMax`, `estimatedOneRepMax`,
                // and `ExerciseSet.prescribedReferenceValue` are all documented
                // as kilograms).
                let volume = completedSets.reduce(Double(0)) { partial, set in
                    partial + Double(VolumeCalculator.setVolume(
                        weight: set.weight,
                        weightType: set.weightType,
                        repetitions: set.repetitions,
                        semantics: entry.loggingSemanticsSnapshot,
                        in: .kg
                    ))
                }
                metrics[.load] = completedSets.last.map { Double($0.weight) }
                metrics[.repetitions] = repetitions / Double(completedSets.count)
                metrics[.setCount] = Double(completedSets.count)
                metrics[.totalRepetitions] = repetitions
                metrics[.totalVolume] = volume
                if let amrap = completedSets.last(where: { $0.prescribedSetType == .amrap }) {
                    metrics[.amrapRepetitions] = Double(amrap.repetitions)
                }
                metrics[.duration] = completedSets.compactMap(\.duration).reduce(0, +)
                metrics[.distance] = completedSets
                    .compactMap { WorkoutDistancePolicy.meters(of: $0).map(Double.init) }
                    .reduce(0, +)
                metrics[.calories] = completedSets.compactMap(\.calories).reduce(0, +)
                if let rpe = completedSets.compactMap(\.rpe).average { metrics[.rpe] = rpe }
                if let rir = completedSets.compactMap(\.rir).map(Double.init).average { metrics[.rir] = rir }
                formulaContext.completedMetricsByExposure[key] = metrics
                let topSets = completedSets.filter { $0.prescribedSetType == .topSet }
                let dailyMaximums = completedSets.filter { $0.prescribedSetType == .dailyMaximum }
                if let top = topSets.last?.weight { formulaContext.completedTopSetByExposure[key] = Double(top) }
                if let maximum = dailyMaximums.last?.weight { formulaContext.dailyMaximumByExposure[key] = Double(maximum) }
            }
        }

        for entry in workout.orderedExercises {
            guard
                let plannedID = entry.sourcePlannedExerciseID,
                let plannedExercise = plannedByID[plannedID],
                let rulesData = entry.prescriptionRulesData,
                let rules = try? decoder.decode([ProgressionRuleDefinition].self, from: rulesData),
                !rules.isEmpty
            else { continue }
            // A substitution is a distinct exposure unless the plan explicitly
            // opts into sharing progression state. Performed history still
            // retains the original planned exercise and selected substitute.
            if entry.selectedSubstituteExerciseIDSnapshot != nil,
               !entry.substitutionSharesProgressionState {
                continue
            }

            let fallbackState = PlanProgressionStateService.effectiveState(
                for: plannedExercise,
                in: run
            ) ?? PlanExerciseProgressionState(progressionKey: plannedExercise.progressionKey)
            let performance = performance(
                for: entry,
                workout: workout,
                run: run,
                plannedExercise: plannedExercise,
                state: fallbackState,
                weekCompleted: weekCompleted,
                blockCompleted: blockCompleted,
                cycleCompleted: cycleCompleted
            )
            let automaticCadences = eligibleCadences(
                weekCompleted: weekCompleted,
                waveCompleted: performance.waveCompleted,
                blockCompleted: blockCompleted,
                cycleCompleted: cycleCompleted
            )
            // Same-session cadences are evaluated while the set is completed;
            // evaluating them again from the completed-workout snapshot would
            // double-apply an automatic action or duplicate a recommendation.
            let groupedRules = Dictionary(grouping: rules.filter {
                $0.isEnabled && $0.cadence != .immediately && $0.cadence != .nextSet
            }) {
                ScopedRuleGroup(scope: $0.scope, cadence: $0.cadence)
            }
            var entryRecommendations: [ProgressionRecommendation] = []
            for (group, groupRules) in groupedRules.sorted(by: { $0.key.sortKey < $1.key.sortKey }) {
                let state = PlanProgressionStateService.stateForEvaluation(
                    scope: group.scope,
                    plannedExercise: plannedExercise,
                    sourceProgress: sourceProgress,
                    sourceBlockIndex: sourceBlockIndex,
                    cadence: group.cadence,
                    in: run
                )
                // Completion can be retried after a relaunch or a failed save.
                // Scoped records each carry their own immutable workout marker.
                guard !hasApplied(workout.id, cadence: group.cadence, on: state) else { continue }
                var evaluationState = ProgramProgressionEvaluator.state(
                    afterRecording: performance,
                    from: PlanProgressionCadenceService.state(from: state)
                )
                let result = try ProgramProgressionEvaluator.evaluate(
                    rules: groupRules,
                    performance: performance,
                    state: evaluationState,
                    formulaContext: formulaContext,
                    variationLadder: plannedExercise.variationLadderData
                        .flatMap { try? decoder.decode([UUID].self, from: $0) } ?? [],
                    stageDefinitions: plannedExercise.progressionStagesData
                        .flatMap { try? decoder.decode(ProgramStageConfiguration.self, from: $0) }?.stages ?? [],
                    automaticCadences: automaticCadences
                )
                evaluationState = result.state
                PlanProgressionCadenceService.apply(evaluationState, to: state)
                state.lastCompletedOccurrence = workout.endTime ?? Date.now
                state.lastSuccessfulLoad = performance.didFail ? state.lastSuccessfulLoad : entry.sets.last(where: { $0.done })?.weight.doubleValue
                state.isDeloading = evaluationState.isDeloading
                state.lastAppliedOutcomeID = workout.id
                recordApplied(workout.id, cadence: group.cadence, on: state)
                var pending = result.deferredStates
                for index in pending.indices {
                    pending[index].sourceWorkoutID = workout.id
                    pending[index].sourceWeekIndex = occurrenceWeekIndex
                    pending[index].sourceWorkoutIndex = sourceWorkoutIndex
                    pending[index].sourceBlockIndex = sourceBlockIndex
                }
                state.pendingProgressionData = try mergedPendingStates(
                    existingData: state.pendingProgressionData,
                    additions: pending,
                    supersededRecommendations: result.recommendations.filter {
                        $0.applicationMode == .automatic && automaticCadences.contains($0.cadence)
                    },
                    decoder: decoder,
                    encoder: encoder
                )
                entryRecommendations.append(contentsOf: result.recommendations)
            }
            results.append(PlanExerciseProgressionResult(
                progressionKey: plannedExercise.progressionKey,
                recommendations: entryRecommendations
            ))
            if let modelContext {
                for recommendation in entryRecommendations {
                    let scopedState = PlanProgressionStateService.stateForEvaluation(
                        scope: recommendation.scope,
                        plannedExercise: plannedExercise,
                        sourceProgress: sourceProgress,
                        sourceBlockIndex: sourceBlockIndex,
                        cadence: recommendation.cadence,
                        in: run
                    )
                    let record = try PlanProgressionRecommendationRecord(
                        recommendation: recommendation,
                        planRunID: run.id,
                        workoutID: workout.id,
                        scopeOwnerKey: scopedState.scopeOwnerKey,
                        proposedLoadUnit: plannedExercise.suggestedLoadType,
                        isResolvedOverride: recommendation.applicationMode == .automatic
                            && !automaticCadences.contains(recommendation.cadence) ? false : nil
                    )
                    record.progressionKey = plannedExercise.progressionKey
                    modelContext.insert(record)
                }
            }
        }
        return results
    }

    private static func mergedPendingStates(
        existingData: Data?,
        additions: [PendingProgressionState],
        supersededRecommendations: [ProgressionRecommendation],
        decoder: JSONDecoder,
        encoder: JSONEncoder
    ) throws -> Data? {
        let existing = (existingData.flatMap { try? decoder.decode([PendingProgressionState].self, from: $0) } ?? []).filter { candidate in
            !supersededRecommendations.contains {
                candidate.ruleID == $0.ruleID
                    && candidate.cadence == $0.cadence
                    && candidate.scope == $0.scope
            }
        }
        let merged = (existing + additions).reduce(into: [PendingProgressionState]()) { result, candidate in
            let duplicate = result.firstIndex {
                $0.sourceWorkoutID == candidate.sourceWorkoutID
                    && $0.ruleID == candidate.ruleID
                    && $0.cadence == candidate.cadence
                    && $0.scope == candidate.scope
            }
            if let duplicate { result[duplicate] = candidate } else { result.append(candidate) }
        }
        return merged.isEmpty ? nil : try encoder.encode(merged)
    }

    private static func hasApplied(
        _ workoutID: UUID,
        cadence: ProgressionCadence,
        on state: PlanExerciseProgressionState
    ) -> Bool {
        let events = state.appliedProgressionEventsData.flatMap {
            try? JSONDecoder().decode(Set<AppliedProgressionEvent>.self, from: $0)
        } ?? []
        return events.contains(AppliedProgressionEvent(workoutID: workoutID, cadence: cadence))
    }

    private static func recordApplied(
        _ workoutID: UUID,
        cadence: ProgressionCadence,
        on state: PlanExerciseProgressionState
    ) {
        var events = state.appliedProgressionEventsData.flatMap {
            try? JSONDecoder().decode(Set<AppliedProgressionEvent>.self, from: $0)
        } ?? []
        events.insert(AppliedProgressionEvent(workoutID: workoutID, cadence: cadence))
        state.appliedProgressionEventsData = try? JSONEncoder().encode(events)
    }

    static func performance(
        for entry: ExerciseEntry,
        workout: Workout,
        run: PlanRun,
        plannedExercise: PlannedExercise,
        state: PlanExerciseProgressionState,
        weekCompleted: Bool,
        blockCompleted: Bool,
        cycleCompleted: Bool,
        isPartialOccurrence: Bool = false
    ) -> ProgressionPerformance {
        // Warm-up and explicitly ineligible sets are preserved in the
        // workout snapshot, but do not decide whether an exposure progressed.
        // This mirrors the template progression path and lets an Olympic
        // attempt program use quality without counting bar-only warm-ups.
        let sets = entry.orderedSets.filter {
            $0.prescribedSetType != .warmup
                && $0.setType != .warmup
                && $0.prescribedProgressionEligible != false
        }
        let requiredSets = sets.filter { $0.isPrescribedOptional != true }.count
        let requiredRepetitions = sets.filter { $0.isPrescribedOptional != true }.reduce(0) { total, set in
            total + (set.prescribedRepetitions ?? set.prescribedRepRangeMinimum ?? 0)
        }
        let completedSets = sets.filter(\.done)
        let completedRepetitions = completedSets.reduce(0) { $0 + Int($1.repetitions) }
        let upperBoundSets = sets.filter { set in
            guard set.done else { return false }
            if let ceiling = set.prescribedRepRangeMaximum { return Int(set.repetitions) >= ceiling }
            if let exact = set.prescribedRepetitions { return Int(set.repetitions) >= exact }
            return false
        }.count
        // See the matching comment above `evaluateAndApply`'s volume computation:
        // route through `VolumeCalculator` instead of a local weight × reps
        // formula so this agrees with History/Analytics regardless of
        // per-set unit or laterality. `.kg` is this domain's canonical unit.
        let totalVolume = completedSets.reduce(Double(0)) { partial, set in
            partial + Double(VolumeCalculator.setVolume(
                weight: set.weight,
                weightType: set.weightType,
                repetitions: set.repetitions,
                semantics: entry.loggingSemanticsSnapshot,
                in: .kg
            ))
        }
        let completedCalories = completedSets.compactMap(\.calories).reduce(0, +)
        let actualRPE = completedSets.compactMap { $0.rpe }.average
        let actualRIR = completedSets.compactMap { $0.rir }
            .map(Double.init)
            .average
            .map { Int($0.rounded()) }
        let meanVelocity = completedSets.compactMap(\.meanVelocity).average
        let targetVelocitySets = completedSets.filter { $0.prescribedVelocityMinimum != nil || $0.prescribedVelocityMaximum != nil }
        let targetVelocityMinimum = targetVelocitySets.compactMap(\.prescribedVelocityMinimum).average
        let targetVelocityMaximum = targetVelocitySets.compactMap(\.prescribedVelocityMaximum).average
        let velocityBelowZoneCount = targetVelocitySets.filter { set in
            guard let velocity = set.meanVelocity, let minimum = set.prescribedVelocityMinimum else { return false }
            return velocity < minimum
        }.count
        let qualitySets = completedSets.compactMap(\.liftQuality)
        let successfulAttemptRatio = qualitySets.isEmpty ? nil : Double(qualitySets.filter { $0 == .excellent || $0 == .acceptable }.count) / Double(qualitySets.count)
        let missedAttempt = qualitySets.contains(.missed)
        let consecutiveMissedAttempts = completedSets.reversed().prefix {
            $0.olympicAttemptOutcome == .missed
        }.count
        let completedRequiredSets = completedSets.filter { $0.isPrescribedOptional != true }
        let requiredCompleted = completedRequiredSets.count >= requiredSets
        let amrapRepetitions = completedSets.last(where: { $0.prescribedSetType == .amrap }).map { Int($0.repetitions) }
        let waveCount = (try? JSONDecoder().decode([ProgramWaveDefinition].self, from: plannedExercise.progressionWavesData ?? Data()))?.count ?? 0
        let waveCompleted = waveCount > 0 && requiredCompleted
        return ProgressionPerformance(
            requiredSets: requiredSets,
            completedSets: completedRequiredSets.count,
            requiredRepetitions: requiredRepetitions,
            completedRepetitions: completedRepetitions,
            upperBoundSets: upperBoundSets,
            totalVolume: totalVolume,
            completedCalories: completedCalories,
            amrapRepetitions: amrapRepetitions,
            targetRPE: entry.prescribedRPE,
            actualRPE: actualRPE,
            targetRIR: entry.prescribedRIR,
            actualRIR: actualRIR,
            successfulAttemptRatio: successfulAttemptRatio,
            consecutiveMissedAttempts: consecutiveMissedAttempts,
            technicalQualityReached: !qualitySets.isEmpty && qualitySets.allSatisfy { $0 == .excellent || $0 == .acceptable },
            workoutCompleted: entry.workout?.status == .completed,
            weekCompleted: weekCompleted,
            waveCompleted: waveCompleted,
            blockCompleted: blockCompleted,
            cycleCompleted: cycleCompleted,
            scheduledDateReached: run.orderedWorkoutProgress.first(where: { $0.completedWorkout?.id == workout.id })?.scheduledDate.map { Date.now >= $0 } ?? false,
            // A partial event is not a failed workout merely because future
            // prescribed sets are still incomplete. Failure counters remain
            // occurrence-level and are updated at workout completion.
            didFail: isPartialOccurrence ? missedAttempt : !requiredCompleted || missedAttempt,
            meanVelocity: meanVelocity,
            targetVelocityMinimum: targetVelocityMinimum,
            targetVelocityMaximum: targetVelocityMaximum,
            velocityBelowZoneCount: velocityBelowZoneCount
        )
    }

    private static func eligibleCadences(
        weekCompleted: Bool,
        waveCompleted: Bool,
        blockCompleted: Bool,
        cycleCompleted: Bool
    ) -> Set<ProgressionCadence> {
        var result: Set<ProgressionCadence> = [
            .immediately,
            .nextSet,
            .nextExerciseOccurrence,
            .nextWorkout
        ]
        if weekCompleted { result.insert(.nextWeek) }
        if waveCompleted { result.insert(.nextWave) }
        if blockCompleted { result.insert(.nextBlock) }
        if cycleCompleted { result.insert(.nextCycle) }
        return result
    }

    private static func blockIndex(forWeek weekIndex: Int, in run: PlanRun) -> Int {
        run.plan?.orderedBlocks.firstIndex(where: { $0.orderedWeeks.contains { $0.weekIndex == weekIndex } }) ?? 0
    }

    private static func isWeekCompleted(_ weekIndex: Int, in run: PlanRun, including workout: Workout) -> Bool {
        let progress = run.orderedWorkoutProgress.filter { $0.weekIndex == weekIndex }
        return !progress.isEmpty && progress.allSatisfy { isCompleted($0, including: workout) }
    }

    private static func isBlockCompleted(_ blockIndex: Int, in run: PlanRun, including workout: Workout) -> Bool {
        guard let block = run.plan?.orderedBlocks[safe: blockIndex] else { return false }
        let weekIndices = Set(block.orderedWeeks.map(\.weekIndex))
        let progress = run.orderedWorkoutProgress.filter {
            weekIndices.contains($0.sourceWeekIndex ?? $0.weekIndex)
        }
        return !progress.isEmpty && progress.allSatisfy { isCompleted($0, including: workout) }
    }

    private static func isCompleted(_ progress: PlanWorkoutProgress, including workout: Workout) -> Bool {
        progress.status == .completed || progress.plannedWorkoutID == workout.sourcePlannedWorkoutID
    }
}

private extension Array where Element == Double {
    var average: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}

private extension Float {
    var doubleValue: Double { Double(self) }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif

import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

struct PlanExerciseProgressionResult {
    let progressionKey: String
    let recommendations: [ProgressionRecommendation]
}

enum PlanProgressionEvaluationService {
    /// Evaluates only rules captured on the workout snapshot. This keeps a
    /// completed workout stable if its source plan is edited later.
    static func evaluateAndApply(
        workout: Workout,
        run: PlanRun,
        modelContext: ModelContext? = nil
    ) throws -> [PlanExerciseProgressionResult] {
        var results: [PlanExerciseProgressionResult] = []
        let decoder = JSONDecoder()
        let plannedExercises = run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .flatMap(\.orderedPlannedExercises) ?? []
        let plannedByID = Dictionary(uniqueKeysWithValues: plannedExercises.map { ($0.id, $0) })
        let stateByKey = Dictionary(uniqueKeysWithValues: run.progressionStates.map { ($0.progressionKey, $0) })
        var formulaContext = FormulaResolutionContext()
        for state in run.progressionStates {
            if let trainingMax = state.trainingMax { formulaContext.trainingMaxByExposure[state.progressionKey] = trainingMax }
            if let e1RM = state.estimatedOneRepMax { formulaContext.estimatedOneRepMaxByExposure[state.progressionKey] = e1RM }
            if let actualOneRepMax = state.actualOneRepMax { formulaContext.actualOneRepMaxByExposure[state.progressionKey] = actualOneRepMax }
            if let load = state.currentLoad { formulaContext.valuesByExposure[state.progressionKey] = load }
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
                let volume = completedSets.reduce(0) { $0 + Double($1.repetitions) * Double($1.weight) }
                metrics[.load] = completedSets.last.map { Double($0.weight) }
                metrics[.repetitions] = repetitions / Double(completedSets.count)
                metrics[.setCount] = Double(completedSets.count)
                metrics[.totalRepetitions] = repetitions
                metrics[.totalVolume] = volume
                metrics[.duration] = completedSets.compactMap(\.duration).reduce(0, +)
                metrics[.distance] = completedSets.compactMap { $0.distance.map(Double.init) }.reduce(0, +)
                metrics[.calories] = completedSets.compactMap(\.calories).reduce(0, +)
                if let rpe = completedSets.compactMap(\.rpe).map(Double.init).average { metrics[.rpe] = rpe }
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
                !rules.isEmpty,
                let state = stateByKey[plannedExercise.progressionKey]
            else { continue }
            // A substitution is a distinct exposure unless the plan explicitly
            // opts into sharing progression state. Performed history still
            // retains the original planned exercise and selected substitute.
            if entry.selectedSubstituteExerciseIDSnapshot != nil,
               !entry.substitutionSharesProgressionState {
                continue
            }

            let performance = performance(for: entry)
            var evaluationState = ProgressionEvaluationState(
                currentLoad: state.currentLoad,
                repetitionOffset: state.repetitionOffset,
                setCountOffset: state.setCountOffset,
                durationOffset: state.durationOffset,
                distanceOffset: state.distanceOffset,
                restDurationOffset: state.restDurationOffset,
                caloriesOffset: state.caloriesOffset,
                currentStageID: state.currentStageID,
                currentVariationExerciseID: state.currentVariationExerciseID,
                currentWaveIndex: state.currentWaveIndex ?? 0,
                currentBlockIndex: state.currentBlockIndex ?? 0,
                trainingMax: state.trainingMax,
                estimatedOneRepMax: state.estimatedOneRepMax,
                actualOneRepMax: state.actualOneRepMax,
                failureCount: state.failureCount + (performance.didFail ? 1 : 0),
                successCount: state.successCount + (performance.didFail ? 0 : 1),
                previousAMRAPRepetitions: performance.amrapRepetitions,
                previousActualRPE: performance.actualRPE,
                previousActualRIR: performance.actualRIR,
                isDeloading: state.isDeloading
            )
            let result = try ProgramProgressionEvaluator.evaluate(
                rules: rules,
                performance: performance,
                state: evaluationState,
                formulaContext: formulaContext
            )
            evaluationState = result.state
            state.currentLoad = evaluationState.currentLoad
            state.repetitionOffset = evaluationState.repetitionOffset
            state.setCountOffset = evaluationState.setCountOffset
            state.durationOffset = evaluationState.durationOffset
            state.distanceOffset = evaluationState.distanceOffset
            state.restDurationOffset = evaluationState.restDurationOffset
            state.caloriesOffset = evaluationState.caloriesOffset
            state.currentStageID = evaluationState.currentStageID
            state.currentVariationExerciseID = evaluationState.currentVariationExerciseID
            state.currentWaveIndex = evaluationState.currentWaveIndex
            state.currentBlockIndex = evaluationState.currentBlockIndex
            state.trainingMax = evaluationState.trainingMax
            state.estimatedOneRepMax = evaluationState.estimatedOneRepMax
            state.actualOneRepMax = evaluationState.actualOneRepMax
            state.failureCount = evaluationState.failureCount
            state.successCount = evaluationState.successCount
            state.previousAMRAPRepetitions = evaluationState.previousAMRAPRepetitions
            state.previousActualRPE = evaluationState.previousActualRPE
            state.previousActualRIR = evaluationState.previousActualRIR
            state.lastCompletedOccurrence = workout.endTime ?? Date.now
            state.lastSuccessfulLoad = performance.didFail ? state.lastSuccessfulLoad : entry.sets.last(where: { $0.done })?.weight.doubleValue
            state.isDeloading = evaluationState.isDeloading
            results.append(PlanExerciseProgressionResult(
                progressionKey: plannedExercise.progressionKey,
                recommendations: result.recommendations
            ))
            if let modelContext {
                for recommendation in result.recommendations {
                    let record = try PlanProgressionRecommendationRecord(
                        recommendation: recommendation,
                        planRunID: run.id,
                        workoutID: workout.id
                    )
                    record.progressionKey = plannedExercise.progressionKey
                    modelContext.insert(record)
                }
            }
        }
        return results
    }

    private static func performance(for entry: ExerciseEntry) -> ProgressionPerformance {
        let sets = entry.orderedSets
        let requiredSets = entry.prescribedSets ?? sets.count
        let requiredRepetitions = sets.reduce(0) { total, set in
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
        let totalVolume = completedSets.reduce(0) { $0 + Double($1.repetitions) * Double($1.weight) }
        let completedCalories = completedSets.compactMap(\.calories).reduce(0, +)
        let actualRPE = completedSets.compactMap { $0.rpe }.map(Double.init).average
        let actualRIR = completedSets.compactMap { $0.rir }.map(Double.init).average
        let qualitySets = completedSets.compactMap(\.liftQuality)
        let successfulAttemptRatio = qualitySets.isEmpty ? nil : Double(qualitySets.filter { $0 == .excellent || $0 == .acceptable }.count) / Double(qualitySets.count)
        let missedAttempt = qualitySets.contains(.missed)
        let optionalSets = sets.filter { $0.isPrescribedOptional == true }
        let requiredCompleted = completedSets.count + optionalSets.count >= requiredSets
        let amrapRepetitions = completedSets.last(where: { $0.prescribedSetType == .amrap }).map { Int($0.repetitions) }
        return ProgressionPerformance(
            requiredSets: requiredSets,
            completedSets: requiredCompleted ? requiredSets : completedSets.count,
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
            technicalQualityReached: !qualitySets.isEmpty && qualitySets.allSatisfy { $0 == .excellent || $0 == .acceptable },
            workoutCompleted: entry.workout?.status == .completed,
            didFail: !requiredCompleted || missedAttempt
        )
    }
}

private extension Array where Element == Double {
    var average: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}

private extension Float {
    var doubleValue: Double { Double(self) }
}
#endif

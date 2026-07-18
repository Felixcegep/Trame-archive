import Foundation

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
        run: PlanRun
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
            if let load = state.currentLoad { formulaContext.valuesByExposure[state.progressionKey] = load }
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

            let performance = performance(for: entry)
            var evaluationState = ProgressionEvaluationState(
                currentLoad: state.currentLoad,
                repetitionOffset: state.repetitionOffset,
                setCountOffset: state.setCountOffset,
                currentStageID: state.currentStageID,
                currentVariationExerciseID: state.currentVariationExerciseID,
                trainingMax: state.trainingMax,
                estimatedOneRepMax: state.estimatedOneRepMax,
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
            state.currentStageID = evaluationState.currentStageID
            state.currentVariationExerciseID = evaluationState.currentVariationExerciseID
            state.trainingMax = evaluationState.trainingMax
            state.estimatedOneRepMax = evaluationState.estimatedOneRepMax
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
        let actualRPE = completedSets.compactMap { $0.rpe }.map(Double.init).average
        let actualRIR = completedSets.compactMap { $0.rir }.map(Double.init).average
        let optionalSets = sets.filter { $0.isPrescribedOptional == true }
        let requiredCompleted = completedSets.count + optionalSets.count >= requiredSets
        return ProgressionPerformance(
            requiredSets: requiredSets,
            completedSets: requiredCompleted ? requiredSets : completedSets.count,
            requiredRepetitions: requiredRepetitions,
            completedRepetitions: completedRepetitions,
            upperBoundSets: upperBoundSets,
            totalVolume: totalVolume,
            amrapRepetitions: nil,
            targetRPE: entry.prescribedRPE,
            actualRPE: actualRPE,
            targetRIR: entry.prescribedRIR,
            actualRIR: actualRIR,
            workoutCompleted: entry.workout?.status == .completed,
            didFail: !requiredCompleted
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

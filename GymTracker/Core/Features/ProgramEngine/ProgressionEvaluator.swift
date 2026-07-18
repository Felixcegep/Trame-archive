import Foundation

#if !GYMTRACKER_EXTENSION

struct ProgressionPerformance: Hashable {
    var requiredSets: Int = 0
    var completedSets: Int = 0
    var requiredRepetitions: Int = 0
    var completedRepetitions: Int = 0
    var upperBoundSets: Int = 0
    var totalVolume: Double = 0
    var amrapRepetitions: Int?
    var targetRPE: Double?
    var actualRPE: Double?
    var targetRIR: Int?
    var actualRIR: Int?
    var successfulAttemptRatio: Double?
    var technicalQualityReached: Bool = false
    var workoutCompleted: Bool = false
    var weekCompleted: Bool = false
    var waveCompleted: Bool = false
    var blockCompleted: Bool = false
    var cycleCompleted: Bool = false
    var scheduledDateReached: Bool = false
    var manualApproval: Bool = false
    var didFail: Bool = false
}

struct ProgressionEvaluationState: Hashable {
    var currentLoad: Double? = nil
    var repetitionOffset: Int = 0
    var setCountOffset: Int = 0
    var currentStageID: String? = nil
    var currentVariationExerciseID: UUID? = nil
    var trainingMax: Double? = nil
    var estimatedOneRepMax: Double? = nil
    var failureCount: Int = 0
    var successCount: Int = 0
    var previousAMRAPRepetitions: Int?
    var previousActualRPE: Double?
    var previousActualRIR: Double?
    var isDeloading: Bool = false
}

struct ProgressionRecommendation: Hashable, Identifiable {
    let id: UUID
    let ruleID: UUID
    let action: ProgressionAction
    let cadence: ProgressionCadence
    let scope: ProgressionScope
    let reason: String
    let applicationMode: ProgressionApplicationMode
    let proposedState: ProgressionEvaluationState
}

struct ProgressionEvaluationResult: Hashable {
    let state: ProgressionEvaluationState
    let recommendations: [ProgressionRecommendation]
}

enum ProgressionEvaluationError: Error, Equatable {
    case formula(FormulaResolutionError)
    case invalidAction(String)
}

enum ProgramProgressionEvaluator {
    static func evaluate(
        rules: [ProgressionRuleDefinition],
        performance: ProgressionPerformance,
        state: ProgressionEvaluationState,
        formulaContext: FormulaResolutionContext = FormulaResolutionContext(),
        variationLadder: [UUID] = []
    ) throws -> ProgressionEvaluationResult {
        var nextState = state
        var recommendations: [ProgressionRecommendation] = []
        let orderedRules = rules.filter(\.isEnabled).sorted {
            $0.priority == $1.priority ? $0.id.uuidString < $1.id.uuidString : $0.priority > $1.priority
        }

        for rule in orderedRules {
            let triggered = matches(rule.trigger, performance: performance, state: nextState)
            let action: ProgressionAction?
            let reason: String
            if triggered {
                action = rule.successAction
                reason = successReason(for: rule.trigger, performance: performance)
            } else if performance.didFail {
                action = rule.failureAction
                reason = "The prescribed performance was not completed."
            } else {
                action = nil
                reason = ""
            }
            guard let action else { continue }

            var proposedState = nextState
            try apply(action, to: &proposedState, formulaContext: formulaContext, variationLadder: variationLadder)
            let recommendation = ProgressionRecommendation(
                id: UUID(),
                ruleID: rule.id,
                action: action,
                cadence: rule.cadence,
                scope: rule.scope,
                reason: reason,
                applicationMode: rule.applicationMode,
                proposedState: proposedState
            )
            recommendations.append(recommendation)
            if rule.applicationMode == .automatic {
                nextState = proposedState
            }
        }
        return ProgressionEvaluationResult(state: nextState, recommendations: recommendations)
    }

    private static func matches(
        _ trigger: ProgressionTrigger,
        performance: ProgressionPerformance,
        state: ProgressionEvaluationState
    ) -> Bool {
        switch trigger {
        case .allRequiredSetsCompleted:
            return performance.requiredSets > 0 && performance.completedSets >= performance.requiredSets
        case .allRequiredRepetitionsCompleted:
            return performance.requiredRepetitions > 0 && performance.completedRepetitions >= performance.requiredRepetitions
        case .allSetsReachedUpperRepBound:
            return performance.requiredSets > 0 && performance.upperBoundSets >= performance.requiredSets
        case .totalRepetitionsReached(let target): return performance.completedRepetitions >= target
        case .totalVolumeReached(let target): return performance.totalVolume >= target
        case .amrapResultReached(let target): return (performance.amrapRepetitions ?? 0) >= target
        case .extraRepetitionsCompleted(let target):
            guard let amrap = performance.amrapRepetitions else { return false }
            return amrap - performance.requiredRepetitions >= target
        case .targetRPEMatched(let tolerance):
            guard let target = performance.targetRPE, let actual = performance.actualRPE else { return false }
            return abs(actual - target) <= tolerance
        case .actualRPEBelowTarget(let tolerance):
            guard let target = performance.targetRPE, let actual = performance.actualRPE else { return false }
            return actual <= target - tolerance
        case .actualRPEAboveTarget(let tolerance):
            guard let target = performance.targetRPE, let actual = performance.actualRPE else { return false }
            return actual >= target + tolerance
        case .targetRIRMatched(let tolerance):
            guard let target = performance.targetRIR, let actual = performance.actualRIR else { return false }
            return abs(actual - target) <= tolerance
        case .failureCountReached(let target): return state.failureCount >= target
        case .successfulAttemptRatioReached(let target): return (performance.successfulAttemptRatio ?? 0) >= target
        case .technicalQualityReached: return performance.technicalQualityReached
        case .workoutCompleted: return performance.workoutCompleted
        case .weekCompleted: return performance.weekCompleted
        case .waveCompleted: return performance.waveCompleted
        case .blockCompleted: return performance.blockCompleted
        case .cycleCompleted: return performance.cycleCompleted
        case .scheduledDateReached: return performance.scheduledDateReached
        case .manualApproval: return performance.manualApproval
        }
    }

    private static func apply(
        _ action: ProgressionAction,
        to state: inout ProgressionEvaluationState,
        formulaContext: FormulaResolutionContext,
        variationLadder: [UUID]
    ) throws {
        switch action {
        case .addLoad(let amount): state.currentLoad = (state.currentLoad ?? 0) + amount
        case .reduceLoad(let amount): state.currentLoad = max(0, (state.currentLoad ?? 0) - amount)
        case .addLoadPercentage(let percentage): state.currentLoad = (state.currentLoad ?? 0) * (1 + percentage)
        case .reduceLoadPercentage(let percentage): state.currentLoad = (state.currentLoad ?? 0) * (1 - percentage)
        case .addRepetitions(let amount): state.repetitionOffset += amount
        case .reduceRepetitions(let amount): state.repetitionOffset = max(0, state.repetitionOffset - amount)
        case .addSets(let amount): state.setCountOffset += amount
        case .reduceSets(let amount): state.setCountOffset = max(0, state.setCountOffset - amount)
        case .repeatPrescription, .noChange, .generateRecommendation:
            break
        case .updateTrainingMax(let formula): state.trainingMax = try resolve(formula, context: formulaContext)
        case .updateEstimatedOneRepMax(let formula): state.estimatedOneRepMax = try resolve(formula, context: formulaContext)
        case .changeStage(let stage): state.currentStageID = stage
        case .advanceExerciseVariation:
            guard !variationLadder.isEmpty else { throw ProgressionEvaluationError.invalidAction("Variation ladder is empty.") }
            guard let current = state.currentVariationExerciseID,
                  let index = variationLadder.firstIndex(of: current) else {
                state.currentVariationExerciseID = variationLadder.first
                return
            }
            state.currentVariationExerciseID = variationLadder[min(index + 1, variationLadder.count - 1)]
        case .regressExerciseVariation:
            guard !variationLadder.isEmpty else { throw ProgressionEvaluationError.invalidAction("Variation ladder is empty.") }
            guard let current = state.currentVariationExerciseID,
                  let index = variationLadder.firstIndex(of: current) else {
                state.currentVariationExerciseID = variationLadder.first
                return
            }
            state.currentVariationExerciseID = variationLadder[max(index - 1, 0)]
        case .advanceWeek, .repeatWeek, .advanceWave, .advanceBlock, .restartBlock, .endExercise, .endProgram, .startDeload:
            state.isDeloading = action == .startDeload
        }
    }

    private static func resolve(_ formula: ProgressionFormula, context: FormulaResolutionContext) throws -> Double {
        do { return try ProgramFormulaResolver.resolve(formula, context: context) }
        catch let error as FormulaResolutionError { throw ProgressionEvaluationError.formula(error) }
    }

    private static func successReason(for trigger: ProgressionTrigger, performance: ProgressionPerformance) -> String {
        switch trigger {
        case .allSetsReachedUpperRepBound: return "Every required set reached the upper rep bound."
        case .allRequiredSetsCompleted: return "All required sets were completed."
        case .allRequiredRepetitionsCompleted: return "All required repetitions were completed."
        case .totalRepetitionsReached(let target): return "The total repetition target of \(target) was reached."
        case .amrapResultReached(let target): return "The AMRAP result reached at least \(target) repetitions."
        case .extraRepetitionsCompleted(let target): return "The AMRAP set exceeded its target by \(target) repetitions."
        case .targetRPEMatched: return "Actual RPE matched the target."
        case .actualRPEBelowTarget: return "Actual RPE was below the target."
        case .actualRPEAboveTarget: return "Actual RPE was above the target."
        case .targetRIRMatched: return "Actual RIR matched the target."
        case .failureCountReached(let target): return "Failure count reached \(target)."
        case .totalVolumeReached(let target): return "Total volume reached \(target)."
        case .successfulAttemptRatioReached(let target): return "Successful attempt ratio reached \(target * 100)%."
        case .technicalQualityReached: return "Technical quality requirement was reached."
        case .workoutCompleted: return "The workout was completed."
        case .weekCompleted: return "The week was completed."
        case .waveCompleted: return "The wave was completed."
        case .blockCompleted: return "The block was completed."
        case .cycleCompleted: return "The cycle was completed."
        case .scheduledDateReached: return "The scheduled date was reached."
        case .manualApproval: return "The user approved this progression."
        }
    }
}
#endif

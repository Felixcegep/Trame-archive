import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated struct ProgressionPerformance: Codable, Hashable {
    var requiredSets: Int = 0
    var completedSets: Int = 0
    var requiredRepetitions: Int = 0
    var completedRepetitions: Int = 0
    var upperBoundSets: Int = 0
    var firstSetReachedUpperBound: Bool = false
    var totalVolume: Double = 0
    var completedCalories: Double = 0
    var amrapRepetitions: Int?
    var targetRPE: Double?
    var actualRPE: Double?
    var targetRIR: Int?
    var actualRIR: Int?
    var successfulAttemptRatio: Double?
    /// Optional for compatibility with recommendation evidence encoded before
    /// attempt-aware progression existed.
    var consecutiveMissedAttempts: Int?
    var technicalQualityReached: Bool = false
    var workoutCompleted: Bool = false
    var weekCompleted: Bool = false
    var waveCompleted: Bool = false
    var blockCompleted: Bool = false
    var cycleCompleted: Bool = false
    var scheduledDateReached: Bool = false
    var manualApproval: Bool = false
    var didFail: Bool = false
    var meanVelocity: Double?
    var targetVelocityMinimum: Double?
    var targetVelocityMaximum: Double?
    var velocityBelowZoneCount: Int = 0
}

nonisolated struct ProgressionEvaluationState: Codable, Hashable {
    var currentLoad: Double? = nil
    var repetitionOffset: Int = 0
    var setCountOffset: Int = 0
    var durationOffset: TimeInterval = 0
    var distanceOffset: Double = 0
    var restDurationOffset: Int = 0
    var caloriesOffset: Double = 0
    var currentStageID: String? = nil
    var currentVariationExerciseID: UUID? = nil
    var currentWaveIndex: Int = 0
    var currentBlockIndex: Int = 0
    var trainingMax: Double? = nil
    var estimatedOneRepMax: Double? = nil
    var actualOneRepMax: Double? = nil
    var failureCount: Int = 0
    var successCount: Int = 0
    var previousAMRAPRepetitions: Int?
    var previousActualRPE: Double?
    var previousActualRIR: Double?
    var isDeloading: Bool = false
    var velocityBaseline: Double?
}

nonisolated struct ProgressionRecommendation: Hashable, Identifiable {
    let id: UUID
    let ruleID: UUID
    let action: ProgressionAction
    let cadence: ProgressionCadence
    let scope: ProgressionScope
    let reason: String
    /// Stable, localized receipt reason captured when the rule is evaluated.
    /// `reason` remains the legacy provenance string for rows created before
    /// this structured key existed; receipts never need to render it.
    let reasonKey: String?
    let applicationMode: ProgressionApplicationMode
    let proposedState: ProgressionEvaluationState
    /// Immutable evidence from the completed occurrence that caused this
    /// recommendation. It makes the decision explainable after source edits.
    let performance: ProgressionPerformance
    /// The rule definition's `version` at the moment this recommendation was
    /// built. `nil` means the version was not captured (for example
    /// recommendations constructed before this field existed); it is never
    /// inferred into a fabricated default.
    let ruleVersion: Int?

    init(
        id: UUID,
        ruleID: UUID,
        action: ProgressionAction,
        cadence: ProgressionCadence,
        scope: ProgressionScope,
        reason: String,
        reasonKey: String? = nil,
        applicationMode: ProgressionApplicationMode,
        proposedState: ProgressionEvaluationState,
        performance: ProgressionPerformance,
        ruleVersion: Int? = nil
    ) {
        self.id = id
        self.ruleID = ruleID
        self.action = action
        self.cadence = cadence
        self.scope = scope
        self.reason = reason
        self.reasonKey = reasonKey
        self.applicationMode = applicationMode
        self.proposedState = proposedState
        self.performance = performance
        self.ruleVersion = ruleVersion
    }
}

/// A deterministic future state that is not eligible for the current
/// occurrence yet. It is encoded onto the mutable run state so a later
/// snapshot can apply it without re-evaluating completed History.
nonisolated struct PendingProgressionState: Codable, Hashable {
    /// The rule and completed workout that produced this state. Optional fields
    /// keep pending state written by earlier app versions decodable.
    var ruleID: UUID? = nil
    var sourceWorkoutID: UUID? = nil
    /// Structural actions (advance/repeat/end) must wait beside their state
    /// until the same cadence boundary; otherwise a deferred recommendation
    /// could change the run before its load/state is eligible.
    var action: ProgressionAction? = nil
    var cadence: ProgressionCadence
    var scope: ProgressionScope
    var state: ProgressionEvaluationState
    var sourceWeekIndex: Int
    var sourceWorkoutIndex: Int
    var sourceBlockIndex: Int
    var createdAt: Date
}

nonisolated struct ProgressionEvaluationResult: Hashable {
    let state: ProgressionEvaluationState
    let recommendations: [ProgressionRecommendation]
    let deferredStates: [PendingProgressionState]
}

nonisolated enum ProgressionEvaluationError: Error, Equatable {
    case formula(FormulaResolutionError)
    case invalidAction(String)
}

nonisolated enum ProgramProgressionEvaluator {
    /// Records the outcome of one completed exposure before its rules are
    /// evaluated. `failureCount` is intentionally consecutive: a successful
    /// occurrence resets the miss streak, so a "third failure" rule means
    /// three failures in a row rather than three failures over the entire
    /// lifetime of a program run.
    static func state(
        afterRecording performance: ProgressionPerformance,
        from state: ProgressionEvaluationState
    ) -> ProgressionEvaluationState {
        var result = state
        result.failureCount = performance.didFail ? state.failureCount + 1 : 0
        result.successCount += performance.didFail ? 0 : 1
        result.previousAMRAPRepetitions = performance.amrapRepetitions
        result.previousActualRPE = performance.actualRPE
        result.previousActualRIR = performance.actualRIR.map(Double.init)
        return result
    }

    static func evaluate(
        rules: [ProgressionRuleDefinition],
        performance: ProgressionPerformance,
        state: ProgressionEvaluationState,
        formulaContext: FormulaResolutionContext = FormulaResolutionContext(),
        variationLadder: [UUID] = [],
        stageDefinitions: [ProgramStageDefinition] = [],
        automaticCadences: Set<ProgressionCadence> = Set(ProgressionCadence.allCases)
    ) throws -> ProgressionEvaluationResult {
        var nextState = state
        var recommendations: [ProgressionRecommendation] = []
        // Keep every deferred rule. Several rules may deliberately share a
        // cadence (for example add load and advance a week); each action must
        // survive, while each later rule still sees the state composed by the
        // earlier one at that same boundary.
        var deferredStates: [(ruleID: UUID, action: ProgressionAction, cadence: ProgressionCadence, scope: ProgressionScope, state: ProgressionEvaluationState)] = []
        let orderedRules = rules.filter(\.isEnabled).sorted {
            $0.priority == $1.priority ? $0.id.uuidString < $1.id.uuidString : $0.priority > $1.priority
        }
        // Failure ladders commonly contain thresholds for stage 1, stage 2,
        // and deload. Once a higher threshold is reached, lower thresholds
        // must not also fire in the same occurrence or a later stage would be
        // overwritten by an earlier one. Rules at the selected threshold can
        // still compose normally with one another.
        let highestReachedFailureThreshold = orderedRules.compactMap { rule -> Int? in
            guard case .failureCountReached(let threshold) = rule.trigger,
                  state.failureCount >= threshold else { return nil }
            return threshold
        }.max()

        for rule in orderedRules {
            if let highestReachedFailureThreshold,
               case .failureCountReached(let threshold) = rule.trigger,
               threshold != highestReachedFailureThreshold {
                continue
            }
            let triggered = matches(rule.trigger, performance: performance, state: nextState)
            let action: ProgressionAction?
            let reason: String
            let reasonKey: String?
            if triggered {
                action = rule.successAction
                reason = successReason(for: rule.trigger, performance: performance, state: nextState)
                reasonKey = "progression.receipt.reason.triggerSatisfied"
            } else if performance.didFail {
                action = rule.failureAction
                reason = "The prescribed performance was not completed."
                reasonKey = "progression.receipt.reason.prescriptionNotCompleted"
            } else {
                action = nil
                reason = ""
                reasonKey = nil
            }
            guard let action else { continue }

            var proposedState = nextState
            if rule.applicationMode == .automatic,
               !automaticCadences.contains(rule.cadence),
                let deferred = deferredStates.last(where: { $0.cadence == rule.cadence }) {
                proposedState = deferred.state
            }
            do {
                try apply(
                    action,
                    to: &proposedState,
                    formulaContext: formulaContext,
                    variationLadder: variationLadder,
                    stageDefinitions: stageDefinitions
                )
            } catch ProgressionEvaluationError.formula(let error) {
                guard case .missingSource = error else {
                    throw ProgressionEvaluationError.formula(error)
                }
                // A formula that references data this run does not have yet
                // (for example a velocity baseline before intake or the first
                // probe set) must not abort the whole evaluation: the rule
                // simply cannot fire on this occurrence.
                continue
            }
            let recommendation = ProgressionRecommendation(
                id: UUID(),
                ruleID: rule.id,
                action: action,
                cadence: rule.cadence,
                scope: rule.scope,
                reason: reason,
                reasonKey: reasonKey,
                applicationMode: rule.applicationMode,
                proposedState: proposedState,
                performance: performance,
                ruleVersion: rule.version
            )
            recommendations.append(recommendation)
            if rule.applicationMode == .automatic {
                if automaticCadences.contains(rule.cadence) {
                    nextState = proposedState
                } else {
                    deferredStates.append((rule.id, action, rule.cadence, rule.scope, proposedState))
                }
            }
        }
        return ProgressionEvaluationResult(
            state: nextState,
            recommendations: recommendations,
            deferredStates: deferredStates.map { value in
                PendingProgressionState(
                    ruleID: value.ruleID,
                    sourceWorkoutID: nil,
                    action: value.action,
                    cadence: value.cadence,
                    scope: value.scope,
                    state: value.state,
                    sourceWeekIndex: 0,
                    sourceWorkoutIndex: 0,
                    sourceBlockIndex: 0,
                    createdAt: .now
                )
            }
        )
    }

    private static func matches(
        _ trigger: ProgressionTrigger,
        performance: ProgressionPerformance,
        state: ProgressionEvaluationState
    ) -> Bool {
        switch trigger {
        case .allOf(let triggers):
            return !triggers.isEmpty && triggers.allSatisfy { matches($0, performance: performance, state: state) }
        case .anyOf(let triggers):
            return !triggers.isEmpty && triggers.contains { matches($0, performance: performance, state: state) }
        case .allRequiredSetsCompleted:
            return performance.requiredSets > 0 && performance.completedSets >= performance.requiredSets
        case .allRequiredRepetitionsCompleted:
            return performance.requiredRepetitions > 0 && performance.completedRepetitions >= performance.requiredRepetitions
        case .allSetsReachedUpperRepBound:
            return performance.requiredSets > 0 && performance.upperBoundSets >= performance.requiredSets
        case .firstSetReachedUpperRepBound:
            return performance.firstSetReachedUpperBound
        case .atStage(let stageID):
            return state.currentStageID == stageID
        case .totalRepetitionsReached(let target): return performance.completedRepetitions >= target
        case .totalCaloriesReached(let target): return performance.completedCalories >= target
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
        case .consecutiveMissedAttemptsReached(let target):
            return (performance.consecutiveMissedAttempts ?? 0) >= target
        case .successfulAttemptRatioReached(let target): return (performance.successfulAttemptRatio ?? 0) >= target
        case .technicalQualityReached: return performance.technicalQualityReached
        case .workoutCompleted: return performance.workoutCompleted
        case .weekCompleted: return performance.weekCompleted
        case .waveCompleted: return performance.waveCompleted
        case .blockCompleted: return performance.blockCompleted
        case .cycleCompleted: return performance.cycleCompleted
        case .scheduledDateReached: return performance.scheduledDateReached
        case .manualApproval: return performance.manualApproval
        case .velocityBelowBaseline(let delta):
            guard let velocity = performance.meanVelocity, let baseline = state.velocityBaseline else { return false }
            return velocity <= baseline - delta
        case .velocityAboveBaseline(let delta):
            guard let velocity = performance.meanVelocity, let baseline = state.velocityBaseline else { return false }
            return velocity >= baseline + delta
        case .velocityInTargetZone:
            guard let velocity = performance.meanVelocity,
                  let minimum = performance.targetVelocityMinimum,
                  let maximum = performance.targetVelocityMaximum else { return false }
            return velocity >= minimum && velocity <= maximum
        case .velocityBelowZoneCount(let count):
            return performance.velocityBelowZoneCount >= count
        }
    }

    private static func apply(
        _ action: ProgressionAction,
        to state: inout ProgressionEvaluationState,
        formulaContext: FormulaResolutionContext,
        variationLadder: [UUID],
        stageDefinitions: [ProgramStageDefinition]
    ) throws {
        switch action {
        case .addLoad(let amount): state.currentLoad = (state.currentLoad ?? 0) + amount
        case .reduceLoad(let amount): state.currentLoad = max(0, (state.currentLoad ?? 0) - amount)
        case .addLoadPercentage(let percentage): state.currentLoad = (state.currentLoad ?? 0) * (1 + percentage)
        case .reduceLoadPercentage(let percentage): state.currentLoad = (state.currentLoad ?? 0) * (1 - percentage)
        // Assisted-bodyweight prescriptions use the same persisted load slot
        // for assistance. Increasing assistance makes the movement easier;
        // reducing it is the progression action.
        case .addAssistance(let amount): state.currentLoad = (state.currentLoad ?? 0) + max(0, amount)
        case .reduceAssistance(let amount): state.currentLoad = max(0, (state.currentLoad ?? 0) - max(0, amount))
        case .addRepetitions(let amount): state.repetitionOffset += amount
        case .reduceRepetitions(let amount): state.repetitionOffset -= max(0, amount)
        case .addSets(let amount): state.setCountOffset += amount
        case .reduceSets(let amount): state.setCountOffset -= max(0, amount)
        case .addDuration(let amount): state.durationOffset += max(0, amount)
        case .reduceDuration(let amount): state.durationOffset -= max(0, amount)
        case .addDistance(let amount): state.distanceOffset += max(0, amount)
        case .reduceDistance(let amount): state.distanceOffset -= max(0, amount)
        case .addRestDuration(let amount): state.restDurationOffset += max(0, amount)
        case .reduceRestDuration(let amount): state.restDurationOffset -= max(0, amount)
        case .addCalories(let amount): state.caloriesOffset += max(0, amount)
        case .reduceCalories(let amount): state.caloriesOffset -= max(0, amount)
        case .repeatPrescription, .noChange, .generateRecommendation:
            break
        case .updateTrainingMax(let formula): state.trainingMax = try resolve(formula, context: formulaContext)
        case .updateEstimatedOneRepMax(let formula): state.estimatedOneRepMax = try resolve(formula, context: formulaContext)
        case .updateActualOneRepMax(let formula): state.actualOneRepMax = try resolve(formula, context: formulaContext)
        case .updateVelocityBaseline(let formula): state.velocityBaseline = try resolve(formula, context: formulaContext)
        case .changeStage(let stage):
            if stageDefinitions.first(where: { $0.stageID == stage })?.carriesLoad == false {
                state.currentLoad = nil
            }
            state.currentStageID = stage
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
        case .advanceWeek, .repeatWeek, .endExercise, .endProgram:
            break
        case .advanceWave:
            state.currentWaveIndex += 1
        case .advanceBlock:
            state.currentBlockIndex += 1
            state.currentWaveIndex = 0
        case .restartBlock:
            state.currentWaveIndex = 0
        case .startDeload:
            state.isDeloading = action == .startDeload
        case .resetFailureCount:
            state.failureCount = 0
        case .resetProgressionOffsets:
            state.repetitionOffset = 0
            state.setCountOffset = 0
            state.durationOffset = 0
            state.distanceOffset = 0
            state.restDurationOffset = 0
            state.caloriesOffset = 0
        }
    }

    private static func resolve(_ formula: ProgressionFormula, context: FormulaResolutionContext) throws -> Double {
        do { return try ProgramFormulaResolver.resolve(formula, context: context) }
        catch let error as FormulaResolutionError { throw ProgressionEvaluationError.formula(error) }
    }

    private static func successReason(
        for trigger: ProgressionTrigger,
        performance: ProgressionPerformance,
        state: ProgressionEvaluationState
    ) -> String {
        switch trigger {
        case .allOf(let triggers):
            return triggers.map { successReason(for: $0, performance: performance, state: state) }.joined(separator: " And ")
        case .anyOf(let triggers):
            let matchedReasons = triggers.compactMap { child -> String? in
                guard matches(child, performance: performance, state: state) else { return nil }
                return successReason(for: child, performance: performance, state: state)
            }
            return matchedReasons.joined(separator: " Or ")
        case .allSetsReachedUpperRepBound: return "Every required set reached the upper rep bound."
        case .firstSetReachedUpperRepBound: return "The first set reached the upper rep bound."
        case .atStage(let stageID): return "The current stage is \(stageID)."
        case .allRequiredSetsCompleted: return "All required sets were completed."
        case .allRequiredRepetitionsCompleted: return "All required repetitions were completed."
        case .totalRepetitionsReached(let target): return "The total repetition target of \(target) was reached."
        case .totalCaloriesReached(let target): return "The total calorie target of \(target) was reached."
        case .amrapResultReached(let target): return "The AMRAP result reached at least \(target) repetitions."
        case .extraRepetitionsCompleted(let target): return "The AMRAP set exceeded its target by \(target) repetitions."
        case .targetRPEMatched: return "Actual RPE matched the target."
        case .actualRPEBelowTarget: return "Actual RPE was below the target."
        case .actualRPEAboveTarget: return "Actual RPE was above the target."
        case .targetRIRMatched: return "Actual RIR matched the target."
        case .failureCountReached(let target): return "Failure count reached \(target)."
        case .consecutiveMissedAttemptsReached(let target):
            return "Consecutive missed attempts reached \(target)."
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
        case .velocityBelowBaseline(let delta): return "Mean velocity was at least \(delta) m/s below baseline."
        case .velocityAboveBaseline(let delta): return "Mean velocity was at least \(delta) m/s above baseline."
        case .velocityInTargetZone: return "Mean velocity was inside the prescribed target zone."
        case .velocityBelowZoneCount(let count): return "Velocity fell below the target zone for \(count) sets."
        }
    }
}
#endif

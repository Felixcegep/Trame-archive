import SwiftUI

#if !GYMTRACKER_EXTENSION

struct RuleTriggerEditor: View {
    @Binding var trigger: ProgressionTrigger

    var body: some View {
        Group {
            Picker("Trigger", selection: triggerKindBinding) {
                ForEach(ProgramBuilderTriggerKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if triggerUsesThreshold {
                TextField("Threshold", text: thresholdBinding)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private var triggerKind: ProgramBuilderTriggerKind {
        switch trigger {
        case .allOf: return .allOf
        case .anyOf: return .anyOf
        case .allRequiredSetsCompleted: return .allRequiredSetsCompleted
        case .allRequiredRepetitionsCompleted: return .allRequiredRepetitionsCompleted
        case .allSetsReachedUpperRepBound: return .allSetsReachedUpperRepBound
        case .firstSetReachedUpperRepBound: return .firstSetReachedUpperRepBound
        case .atStage: return .atStage
        case .totalRepetitionsReached: return .totalRepetitionsReached
        case .totalCaloriesReached: return .totalCaloriesReached
        case .totalVolumeReached: return .totalVolumeReached
        case .amrapResultReached: return .amrapResultReached
        case .extraRepetitionsCompleted: return .extraRepetitionsCompleted
        case .targetRPEMatched: return .targetRPEMatched
        case .actualRPEBelowTarget: return .actualRPEBelowTarget
        case .actualRPEAboveTarget: return .actualRPEAboveTarget
        case .targetRIRMatched: return .targetRIRMatched
        case .failureCountReached: return .failureCountReached
        case .consecutiveMissedAttemptsReached: return .consecutiveMissedAttemptsReached
        case .technicalQualityReached: return .technicalQualityReached
        case .workoutCompleted: return .workoutCompleted
        case .weekCompleted: return .weekCompleted
        case .waveCompleted: return .waveCompleted
        case .blockCompleted: return .blockCompleted
        case .cycleCompleted: return .cycleCompleted
        case .scheduledDateReached: return .scheduledDateReached
        case .manualApproval: return .manualApproval
        case .successfulAttemptRatioReached: return .successfulAttemptRatioReached
        case .velocityBelowBaseline, .velocityAboveBaseline, .velocityInTargetZone, .velocityBelowZoneCount:
            return .manualApproval
        }
    }

    private var triggerKindBinding: Binding<ProgramBuilderTriggerKind> {
        Binding(
            get: { triggerKind },
            set: { kind in
                switch kind {
                case .allOf: trigger = .allOf([.allRequiredSetsCompleted])
                case .anyOf: trigger = .anyOf([.allRequiredSetsCompleted])
                case .allRequiredSetsCompleted: trigger = .allRequiredSetsCompleted
                case .allRequiredRepetitionsCompleted: trigger = .allRequiredRepetitionsCompleted
                case .allSetsReachedUpperRepBound: trigger = .allSetsReachedUpperRepBound
                case .firstSetReachedUpperRepBound: trigger = .firstSetReachedUpperRepBound
                case .atStage: trigger = .atStage("stage-1")
                case .totalRepetitionsReached: trigger = .totalRepetitionsReached(25)
                case .totalCaloriesReached: trigger = .totalCaloriesReached(100)
                case .totalVolumeReached: trigger = .totalVolumeReached(1_000)
                case .amrapResultReached: trigger = .amrapResultReached(10)
                case .extraRepetitionsCompleted: trigger = .extraRepetitionsCompleted(2)
                case .targetRPEMatched: trigger = .targetRPEMatched(tolerance: 0.5)
                case .actualRPEBelowTarget: trigger = .actualRPEBelowTarget(tolerance: 1)
                case .actualRPEAboveTarget: trigger = .actualRPEAboveTarget(tolerance: 1)
                case .targetRIRMatched: trigger = .targetRIRMatched(tolerance: 1)
                case .failureCountReached: trigger = .failureCountReached(3)
                case .consecutiveMissedAttemptsReached: trigger = .consecutiveMissedAttemptsReached(3)
                case .technicalQualityReached: trigger = .technicalQualityReached
                case .workoutCompleted: trigger = .workoutCompleted
                case .weekCompleted: trigger = .weekCompleted
                case .waveCompleted: trigger = .waveCompleted
                case .blockCompleted: trigger = .blockCompleted
                case .cycleCompleted: trigger = .cycleCompleted
                case .scheduledDateReached: trigger = .scheduledDateReached
                case .manualApproval: trigger = .manualApproval
                case .successfulAttemptRatioReached: trigger = .successfulAttemptRatioReached(0.9)
                }
            }
        )
    }

    private var triggerUsesThreshold: Bool {
        switch trigger {
        case .totalRepetitionsReached, .totalCaloriesReached, .totalVolumeReached,
                .amrapResultReached, .extraRepetitionsCompleted, .targetRPEMatched,
                .actualRPEBelowTarget, .actualRPEAboveTarget, .targetRIRMatched,
                .failureCountReached, .consecutiveMissedAttemptsReached,
                .successfulAttemptRatioReached:
            return true
        default:
            return false
        }
    }

    private var thresholdBinding: Binding<String> {
        Binding(
            get: {
                switch trigger {
                case .totalRepetitionsReached(let value), .amrapResultReached(let value),
                        .extraRepetitionsCompleted(let value), .failureCountReached(let value),
                        .consecutiveMissedAttemptsReached(let value),
                        .targetRIRMatched(let value): return String(value)
                case .totalCaloriesReached(let value), .totalVolumeReached(let value),
                        .targetRPEMatched(let value), .actualRPEBelowTarget(let value),
                        .actualRPEAboveTarget(let value), .successfulAttemptRatioReached(let value): return String(value)
                default: return ""
                }
            },
            set: { value in
                switch trigger {
                case .totalRepetitionsReached: trigger = .totalRepetitionsReached(max(1, Int(value) ?? 1))
                case .totalCaloriesReached: trigger = .totalCaloriesReached(max(0, Double(value) ?? 0))
                case .totalVolumeReached: trigger = .totalVolumeReached(max(0, Double(value) ?? 0))
                case .amrapResultReached: trigger = .amrapResultReached(max(0, Int(value) ?? 0))
                case .extraRepetitionsCompleted: trigger = .extraRepetitionsCompleted(max(0, Int(value) ?? 0))
                case .targetRPEMatched: trigger = .targetRPEMatched(tolerance: max(0, Double(value) ?? 0))
                case .actualRPEBelowTarget: trigger = .actualRPEBelowTarget(tolerance: max(0, Double(value) ?? 0))
                case .actualRPEAboveTarget: trigger = .actualRPEAboveTarget(tolerance: max(0, Double(value) ?? 0))
                case .targetRIRMatched: trigger = .targetRIRMatched(tolerance: max(0, Int(value) ?? 0))
                case .failureCountReached: trigger = .failureCountReached(max(1, Int(value) ?? 1))
                case .consecutiveMissedAttemptsReached:
                    trigger = .consecutiveMissedAttemptsReached(max(1, Int(value) ?? 1))
                case .successfulAttemptRatioReached: trigger = .successfulAttemptRatioReached(min(1, max(0, Double(value) ?? 0.9)))
                default: break
                }
            }
        )
    }
}

struct RuleActionEditor: View {
    @Binding var successAction: ProgressionAction
    @Binding var failureAction: ProgressionAction?

    var body: some View {
        Group {
            Picker("On success", selection: successActionKindBinding) {
                ForEach(ProgramBuilderActionKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if actionUsesValue {
                TextField("Action value", text: actionValueBinding)
                    .keyboardType(.decimalPad)
            }
            Toggle("Use failure action", isOn: hasFailureActionBinding)
            if failureAction != nil {
                Picker("On failure", selection: failureActionKindBinding) {
                    ForEach(ProgramBuilderActionKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                if failureActionUsesValue {
                    TextField("Failure action value", text: failureActionValueBinding)
                        .keyboardType(.decimalPad)
                }
            }
        }
    }

    private var successActionKind: ProgramBuilderActionKind {
        actionKind(successAction)
    }

    private var successActionKindBinding: Binding<ProgramBuilderActionKind> {
        Binding(
            get: { successActionKind },
            set: { kind in
                successAction = defaultAction(for: kind)
            }
        )
    }

    private var actionUsesValue: Bool {
        actionUsesValue(successAction)
    }

    private var actionValueBinding: Binding<String> {
        Binding(
            get: { actionValue(successAction) },
            set: { successAction = actionSettingValue(successAction, value: $0) }
        )
    }

    private var hasFailureActionBinding: Binding<Bool> {
        Binding(
            get: { failureAction != nil },
            set: { enabled in
                failureAction = enabled ? .repeatPrescription : nil
            }
        )
    }

    private var failureActionKindBinding: Binding<ProgramBuilderActionKind> {
        Binding(
            get: { failureAction.map(actionKind) ?? .repeatPrescription },
            set: { failureAction = defaultAction(for: $0) }
        )
    }

    private var failureActionUsesValue: Bool {
        guard let failureAction = failureAction else { return false }
        return actionUsesValue(failureAction)
    }

    private var failureActionValueBinding: Binding<String> {
        Binding(
            get: { failureAction.map(actionValue) ?? "" },
            set: { value in
                guard let action = failureAction else { return }
                failureAction = actionSettingValue(action, value: value)
            }
        )
    }

    private func actionKind(_ action: ProgressionAction) -> ProgramBuilderActionKind {
        switch action {
        case .addLoad: return .addLoad
        case .reduceLoad: return .reduceLoad
        case .addLoadPercentage: return .addLoadPercentage
        case .reduceLoadPercentage: return .reduceLoadPercentage
        case .addAssistance: return .addAssistance
        case .reduceAssistance: return .reduceAssistance
        case .addRepetitions: return .addRepetitions
        case .reduceRepetitions: return .reduceRepetitions
        case .addSets: return .addSets
        case .reduceSets: return .reduceSets
        case .addDuration: return .addDuration
        case .reduceDuration: return .reduceDuration
        case .addDistance: return .addDistance
        case .reduceDistance: return .reduceDistance
        case .addRestDuration: return .addRestDuration
        case .reduceRestDuration: return .reduceRestDuration
        case .addCalories: return .addCalories
        case .reduceCalories: return .reduceCalories
        case .updateTrainingMax: return .updateTrainingMax
        case .updateEstimatedOneRepMax: return .updateEstimatedOneRepMax
        case .updateActualOneRepMax: return .updateActualOneRepMax
        case .updateVelocityBaseline: return .updateTrainingMax
        case .repeatPrescription: return .repeatPrescription
        case .changeStage: return .changeStage
        case .advanceExerciseVariation: return .advanceExerciseVariation
        case .regressExerciseVariation: return .regressExerciseVariation
        case .advanceWeek: return .advanceWeek
        case .repeatWeek: return .repeatWeek
        case .advanceWave: return .advanceWave
        case .advanceBlock: return .advanceBlock
        case .restartBlock: return .restartBlock
        case .startDeload: return .startDeload
        case .resetFailureCount: return .resetFailureCount
        case .resetProgressionOffsets: return .resetProgressionOffsets
        case .endExercise: return .endExercise
        case .endProgram: return .endProgram
        case .generateRecommendation: return .generateRecommendation
        case .noChange: return .noChange
        }
    }

    private func defaultAction(for kind: ProgramBuilderActionKind) -> ProgressionAction {
        switch kind {
        case .addLoad: return .addLoad(2.5)
        case .reduceLoad: return .reduceLoad(2.5)
        case .addLoadPercentage: return .addLoadPercentage(0.025)
        case .reduceLoadPercentage: return .reduceLoadPercentage(0.025)
        case .addAssistance: return .addAssistance(5)
        case .reduceAssistance: return .reduceAssistance(5)
        case .addRepetitions: return .addRepetitions(1)
        case .reduceRepetitions: return .reduceRepetitions(1)
        case .addSets: return .addSets(1)
        case .reduceSets: return .reduceSets(1)
        case .addDuration: return .addDuration(30)
        case .reduceDuration: return .reduceDuration(30)
        case .addDistance: return .addDistance(50)
        case .reduceDistance: return .reduceDistance(50)
        case .addRestDuration: return .addRestDuration(15)
        case .reduceRestDuration: return .reduceRestDuration(15)
        case .addCalories: return .addCalories(10)
        case .reduceCalories: return .reduceCalories(10)
        case .updateTrainingMax: return .updateTrainingMax(.source(.constant(100)))
        case .updateEstimatedOneRepMax: return .updateEstimatedOneRepMax(.source(.constant(100)))
        case .updateActualOneRepMax: return .updateActualOneRepMax(.source(.constant(100)))
        case .repeatPrescription: return .repeatPrescription
        case .changeStage: return .changeStage("next")
        case .advanceExerciseVariation: return .advanceExerciseVariation
        case .regressExerciseVariation: return .regressExerciseVariation
        case .advanceWeek: return .advanceWeek
        case .repeatWeek: return .repeatWeek
        case .advanceWave: return .advanceWave
        case .advanceBlock: return .advanceBlock
        case .restartBlock: return .restartBlock
        case .startDeload: return .startDeload
        case .resetFailureCount: return .resetFailureCount
        case .resetProgressionOffsets: return .resetProgressionOffsets
        case .endExercise: return .endExercise
        case .endProgram: return .endProgram
        case .generateRecommendation: return .generateRecommendation
        case .noChange: return .noChange
        }
    }

    private func actionUsesValue(_ action: ProgressionAction) -> Bool {
        switch action {
        case .addLoad, .reduceLoad, .addLoadPercentage, .reduceLoadPercentage,
                .addAssistance, .reduceAssistance, .addRepetitions, .reduceRepetitions,
                .addSets, .reduceSets, .addDuration, .reduceDuration, .addDistance,
                .reduceDistance, .addRestDuration, .reduceRestDuration, .addCalories,
                .reduceCalories, .changeStage:
            return true
        default:
            return false
        }
    }

    private func actionValue(_ action: ProgressionAction) -> String {
        switch action {
        case .addLoad(let value), .reduceLoad(let value), .addLoadPercentage(let value),
                .reduceLoadPercentage(let value), .addAssistance(let value), .reduceAssistance(let value),
                .addDuration(let value), .reduceDuration(let value), .addDistance(let value),
                .reduceDistance(let value), .addCalories(let value), .reduceCalories(let value): return String(value)
        case .addRepetitions(let value), .reduceRepetitions(let value), .addSets(let value),
                .reduceSets(let value), .addRestDuration(let value), .reduceRestDuration(let value): return String(value)
        case .changeStage(let value): return value
        default: return ""
        }
    }

    private func actionSettingValue(_ action: ProgressionAction, value: String) -> ProgressionAction {
        switch action {
        case .addLoad: return .addLoad(max(0, Double(value) ?? 0))
        case .reduceLoad: return .reduceLoad(max(0, Double(value) ?? 0))
        case .addLoadPercentage: return .addLoadPercentage(max(0, Double(value) ?? 0))
        case .reduceLoadPercentage: return .reduceLoadPercentage(max(0, Double(value) ?? 0))
        case .addAssistance: return .addAssistance(max(0, Double(value) ?? 0))
        case .reduceAssistance: return .reduceAssistance(max(0, Double(value) ?? 0))
        case .addRepetitions: return .addRepetitions(max(0, Int(value) ?? 0))
        case .reduceRepetitions: return .reduceRepetitions(max(0, Int(value) ?? 0))
        case .addSets: return .addSets(max(0, Int(value) ?? 0))
        case .reduceSets: return .reduceSets(max(0, Int(value) ?? 0))
        case .addDuration: return .addDuration(max(0, Double(value) ?? 0))
        case .reduceDuration: return .reduceDuration(max(0, Double(value) ?? 0))
        case .addDistance: return .addDistance(max(0, Double(value) ?? 0))
        case .reduceDistance: return .reduceDistance(max(0, Double(value) ?? 0))
        case .addRestDuration: return .addRestDuration(max(0, Int(value) ?? 0))
        case .reduceRestDuration: return .reduceRestDuration(max(0, Int(value) ?? 0))
        case .addCalories: return .addCalories(max(0, Double(value) ?? 0))
        case .reduceCalories: return .reduceCalories(max(0, Double(value) ?? 0))
        case .changeStage: return .changeStage(value)
        default: return action
        }
    }
}

struct RuleFormulaEditor: View {
    @Binding var formula: ProgressionFormula?

    var body: some View {
        Group {
            Picker("Formula", selection: formulaKindBinding) {
                ForEach(ProgramBuilderFormulaKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if formulaNeedsExposureKey {
                TextField("Formula exposure key", text: formulaExposureKeyBinding)
            }
            if formulaNeedsConstant {
                TextField("Formula constant", text: formulaConstantBinding)
                    .keyboardType(.decimalPad)
            }
            if formula != nil {
                Menu("Compose formula", systemImage: AppIcon.progression) {
                    Button("Multiply by 0.90") {
                        compose { .multiply($0, .source(.constant(0.90))) }
                    }
                    Button("Add 2.5") {
                        compose { .add($0, .source(.constant(2.5))) }
                    }
                    Button("Clamp 0–100") {
                        compose { .clamp(value: $0, minimum: 0, maximum: 100) }
                    }
                    Button("Round to 2.5") {
                        compose { .round($0, rule: .nearestIncrement(2.5)) }
                    }
                    Button("Reset to source") {
                        if case .some(.source(let source)) = formula {
                            formula = .source(source)
                        }
                    }
                }
                .font(AppFont.caption)
            }
        }
    }

    private var formulaKind: ProgramBuilderFormulaKind {
        guard let formula else { return .none }
        guard case .source(let source) = formula else { return .constant }
        switch source {
        case .constant: return .constant
        case .trainingMax: return .trainingMax
        case .estimatedOneRepMax: return .estimatedOneRepMax
        case .actualOneRepMax: return .actualOneRepMax
        case .previousOccurrence: return .previousOccurrence
        case .previousSuccessfulSet: return .previousSuccessfulSet
        case .completedTopSet: return .completedTopSet
        case .dailyMaximum: return .dailyMaximum
        case .anotherExposure: return .anotherExposure
        case .completedMetric: return .completedMetric
        case .velocityBaseline: return .anotherExposure
        }
    }

    private var formulaKindBinding: Binding<ProgramBuilderFormulaKind> {
        Binding(
            get: { formulaKind },
            set: { kind in
                switch kind {
                case .none: formula = nil
                case .constant: formula = .source(.constant(1))
                case .trainingMax: formula = .source(.trainingMax(exposureKey: ""))
                case .estimatedOneRepMax: formula = .source(.estimatedOneRepMax(exposureKey: ""))
                case .actualOneRepMax: formula = .source(.actualOneRepMax(exposureKey: ""))
                case .previousOccurrence: formula = .source(.previousOccurrence(exposureKey: ""))
                case .previousSuccessfulSet: formula = .source(.previousSuccessfulSet(exposureKey: ""))
                case .completedTopSet: formula = .source(.completedTopSet(exposureKey: ""))
                case .dailyMaximum: formula = .source(.dailyMaximum(exposureKey: ""))
                case .anotherExposure: formula = .source(.anotherExposure(exposureKey: ""))
                case .completedMetric: formula = .source(.completedMetric(exposureKey: "", metric: .load))
                }
            }
        )
    }

    private var formulaNeedsExposureKey: Bool {
        switch formulaKind {
        case .trainingMax, .estimatedOneRepMax, .actualOneRepMax, .previousOccurrence,
                .previousSuccessfulSet, .completedTopSet, .dailyMaximum, .anotherExposure,
                .completedMetric:
            return true
        default:
            return false
        }
    }

    private var formulaNeedsConstant: Bool {
        formulaKind == .constant
    }

    private var formulaExposureKeyBinding: Binding<String> {
        Binding(
            get: {
                guard case .source(let source)? = formula else { return "" }
                switch source {
                case .trainingMax(let key), .estimatedOneRepMax(let key), .actualOneRepMax(let key),
                        .previousOccurrence(let key), .previousSuccessfulSet(let key), .completedTopSet(let key),
                        .dailyMaximum(let key), .anotherExposure(let key), .completedMetric(let key, _):
                    return key
                case .velocityBaseline(let key):
                    return key
                case .constant:
                    return ""
                }
            },
            set: { value in
                guard case .source(let source)? = formula else { return }
                switch source {
                case .trainingMax: formula = .source(.trainingMax(exposureKey: value))
                case .estimatedOneRepMax: formula = .source(.estimatedOneRepMax(exposureKey: value))
                case .actualOneRepMax: formula = .source(.actualOneRepMax(exposureKey: value))
                case .previousOccurrence: formula = .source(.previousOccurrence(exposureKey: value))
                case .previousSuccessfulSet: formula = .source(.previousSuccessfulSet(exposureKey: value))
                case .completedTopSet: formula = .source(.completedTopSet(exposureKey: value))
                case .dailyMaximum: formula = .source(.dailyMaximum(exposureKey: value))
                case .anotherExposure: formula = .source(.anotherExposure(exposureKey: value))
                case .completedMetric(_, let metric): formula = .source(.completedMetric(exposureKey: value, metric: metric))
                case .velocityBaseline: formula = .source(.velocityBaseline(exposureKey: value))
                case .constant: break
                }
            }
        )
    }

    private var formulaConstantBinding: Binding<String> {
        Binding(
            get: {
                guard case .source(.constant(let value))? = formula else { return "" }
                return String(value)
            },
            set: { value in
                formula = .source(.constant(Double(value) ?? 0))
            }
        )
    }

    private func compose(_ transform: (ProgressionFormula) -> ProgressionFormula) {
        guard let existing = formula else { return }
        formula = transform(existing)
    }
}

#endif

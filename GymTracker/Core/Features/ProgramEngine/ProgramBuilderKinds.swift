import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgramBuilderTriggerKind: String, CaseIterable, Identifiable {
    case allOf
    case anyOf
    case allRequiredSetsCompleted
    case allRequiredRepetitionsCompleted
    case allSetsReachedUpperRepBound
    case firstSetReachedUpperRepBound
    case atStage
    case totalRepetitionsReached
    case totalCaloriesReached
    case totalVolumeReached
    case amrapResultReached
    case extraRepetitionsCompleted
    case targetRPEMatched
    case actualRPEBelowTarget
    case actualRPEAboveTarget
    case targetRIRMatched
    case failureCountReached
    case consecutiveMissedAttemptsReached
    case technicalQualityReached
    case workoutCompleted
    case weekCompleted
    case waveCompleted
    case blockCompleted
    case cycleCompleted
    case scheduledDateReached
    case manualApproval
    case successfulAttemptRatioReached

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allOf: return "All conditions"
        case .anyOf: return "Any condition"
        case .allRequiredSetsCompleted: return "All required sets"
        case .allRequiredRepetitionsCompleted: return "All required repetitions"
        case .allSetsReachedUpperRepBound: return "All sets reach upper reps"
        case .firstSetReachedUpperRepBound: return "First set reaches upper reps"
        case .atStage: return "Current stage"
        case .totalRepetitionsReached: return "Total repetitions"
        case .totalCaloriesReached: return "Total calories"
        case .totalVolumeReached: return "Total volume"
        case .amrapResultReached: return "AMRAP result"
        case .extraRepetitionsCompleted: return "Extra AMRAP repetitions"
        case .targetRPEMatched: return "Target RPE matched"
        case .actualRPEBelowTarget: return "RPE below target"
        case .actualRPEAboveTarget: return "RPE above target"
        case .targetRIRMatched: return "Target RIR matched"
        case .failureCountReached: return "Failure count"
        case .consecutiveMissedAttemptsReached: return "Consecutive missed attempts"
        case .technicalQualityReached: return "Technical quality"
        case .workoutCompleted: return "Workout completed"
        case .weekCompleted: return "Week completed"
        case .waveCompleted: return "Wave completed"
        case .blockCompleted: return "Block completed"
        case .cycleCompleted: return "Cycle completed"
        case .scheduledDateReached: return "Scheduled date reached"
        case .manualApproval: return "Manual approval"
        case .successfulAttemptRatioReached: return "Successful attempt ratio"
        }
    }
}

enum ProgramBuilderActionKind: String, CaseIterable, Identifiable {
    case addLoad
    case reduceLoad
    case addLoadPercentage
    case reduceLoadPercentage
    case addAssistance
    case reduceAssistance
    case addRepetitions
    case reduceRepetitions
    case addSets
    case reduceSets
    case addDuration
    case reduceDuration
    case addDistance
    case reduceDistance
    case addRestDuration
    case reduceRestDuration
    case addCalories
    case reduceCalories
    case updateTrainingMax
    case updateEstimatedOneRepMax
    case updateActualOneRepMax
    case repeatPrescription
    case changeStage
    case advanceExerciseVariation
    case regressExerciseVariation
    case advanceWeek
    case repeatWeek
    case advanceWave
    case advanceBlock
    case restartBlock
    case startDeload
    case resetFailureCount
    case resetProgressionOffsets
    case endExercise
    case endActiveDailyMaximumAndGenerateBackOffs
    case endProgram
    case generateRecommendation
    case noChange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addLoad: return "Add load"
        case .reduceLoad: return "Reduce load"
        case .addLoadPercentage: return "Add load percentage"
        case .reduceLoadPercentage: return "Reduce load percentage"
        case .addAssistance: return "Add assistance"
        case .reduceAssistance: return "Reduce assistance"
        case .addRepetitions: return "Add repetitions"
        case .reduceRepetitions: return "Reduce repetitions"
        case .addSets: return "Add sets"
        case .reduceSets: return "Reduce sets"
        case .addDuration: return "Add duration"
        case .reduceDuration: return "Reduce duration"
        case .addDistance: return "Add distance"
        case .reduceDistance: return "Reduce distance"
        case .addRestDuration: return "Add rest duration"
        case .reduceRestDuration: return "Reduce rest duration"
        case .addCalories: return "Add calories"
        case .reduceCalories: return "Reduce calories"
        case .updateTrainingMax: return "Update Training Max"
        case .updateEstimatedOneRepMax: return "Update estimated 1RM"
        case .updateActualOneRepMax: return "Update actual 1RM"
        case .repeatPrescription: return "Repeat prescription"
        case .changeStage: return "Change stage"
        case .advanceExerciseVariation: return "Advance variation"
        case .regressExerciseVariation: return "Regress variation"
        case .advanceWeek: return "Advance week"
        case .repeatWeek: return "Repeat week"
        case .advanceWave: return "Advance wave"
        case .advanceBlock: return "Advance block"
        case .restartBlock: return "Restart block"
        case .startDeload: return "Start deload"
        case .resetFailureCount: return "Reset failure count"
        case .resetProgressionOffsets: return "Reset progression offsets"
        case .endExercise: return "End exercise"
        case .endActiveDailyMaximumAndGenerateBackOffs:
            return "End daily maximum and generate back-offs"
        case .endProgram: return "End program"
        case .generateRecommendation: return "Generate recommendation"
        case .noChange: return "No change"
        }
    }
}

enum ProgramBuilderFormulaKind: String, CaseIterable, Identifiable {
    case none
    case constant
    case trainingMax
    case estimatedOneRepMax
    case actualOneRepMax
    case previousOccurrence
    case previousSuccessfulSet
    case completedTopSet
    case dailyMaximum
    case anotherExposure
    case completedMetric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No formula"
        case .constant: return "Constant"
        case .trainingMax: return "Training Max"
        case .estimatedOneRepMax: return "Estimated 1RM"
        case .actualOneRepMax: return "Actual 1RM"
        case .previousOccurrence: return "Previous occurrence"
        case .previousSuccessfulSet: return "Previous successful set"
        case .completedTopSet: return "Completed top set"
        case .dailyMaximum: return "Daily maximum"
        case .anotherExposure: return "Another exposure"
        case .completedMetric: return "Completed metric"
        }
    }
}

#endif

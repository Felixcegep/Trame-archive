import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated enum FormulaSource: Codable, Hashable {
    case constant(Double)
    case trainingMax(exposureKey: String)
    case estimatedOneRepMax(exposureKey: String)
    case actualOneRepMax(exposureKey: String)
    case previousOccurrence(exposureKey: String)
    case previousSuccessfulSet(exposureKey: String)
    case completedTopSet(exposureKey: String)
    case dailyMaximum(exposureKey: String)
    case anotherExposure(exposureKey: String)
    case completedMetric(exposureKey: String, metric: ProgressionMetric)
    case velocityBaseline(exposureKey: String)
}

nonisolated indirect enum ProgressionFormula: Codable, Hashable {
    case source(FormulaSource)
    case add(ProgressionFormula, ProgressionFormula)
    case subtract(ProgressionFormula, ProgressionFormula)
    case multiply(ProgressionFormula, ProgressionFormula)
    case divide(ProgressionFormula, ProgressionFormula)
    case minimum(ProgressionFormula, ProgressionFormula)
    case maximum(ProgressionFormula, ProgressionFormula)
    case clamp(value: ProgressionFormula, minimum: Double, maximum: Double)
    case round(ProgressionFormula, rule: LoadRoundingRule)
}

nonisolated enum ProgressionMetric: String, Codable, CaseIterable, Hashable {
    case load
    case repetitions
    case setCount
    case totalRepetitions
    case totalVolume
    case percentage
    case trainingMax
    case estimatedOneRepMax
    case rpe
    case rir
    case duration
    case distance
    case pace
    case calories
    case restDuration
    case assistance
    case exerciseVariation
    case technicalQuality
    case successfulAttempts
    case amrapRepetitions
    case meanVelocity
}

nonisolated indirect enum ProgressionTrigger: Codable, Hashable {
    case allOf([ProgressionTrigger])
    case anyOf([ProgressionTrigger])
    case allRequiredSetsCompleted
    case allRequiredRepetitionsCompleted
    case allSetsReachedUpperRepBound
    case firstSetReachedUpperRepBound
    case atStage(String)
    case totalRepetitionsReached(Int)
    case totalCaloriesReached(Double)
    case totalVolumeReached(Double)
    case amrapResultReached(Int)
    case extraRepetitionsCompleted(Int)
    case targetRPEMatched(tolerance: Double)
    case actualRPEBelowTarget(tolerance: Double)
    case actualRPEAboveTarget(tolerance: Double)
    case targetRIRMatched(tolerance: Int)
    case failureCountReached(Int)
    /// Consecutive missed parent attempts inside the current exercise
    /// occurrence. Unlike `failureCountReached`, this does not span workouts.
    case consecutiveMissedAttemptsReached(Int)
    case successfulAttemptRatioReached(Double)
    case technicalQualityReached
    case workoutCompleted
    case weekCompleted
    case waveCompleted
    case blockCompleted
    case cycleCompleted
    case scheduledDateReached
    case manualApproval
    case velocityBelowBaseline(delta: Double)
    case velocityAboveBaseline(delta: Double)
    case velocityInTargetZone
    case velocityBelowZoneCount(Int)
}

nonisolated enum ProgressionAction: Codable, Hashable {
    case addLoad(Double)
    case reduceLoad(Double)
    case addLoadPercentage(Double)
    case reduceLoadPercentage(Double)
    case addAssistance(Double)
    case reduceAssistance(Double)
    case addRepetitions(Int)
    case reduceRepetitions(Int)
    case addSets(Int)
    case reduceSets(Int)
    case addDuration(TimeInterval)
    case reduceDuration(TimeInterval)
    case addDistance(Double)
    case reduceDistance(Double)
    case addRestDuration(Int)
    case reduceRestDuration(Int)
    case addCalories(Double)
    case reduceCalories(Double)
    case updateTrainingMax(ProgressionFormula)
    case updateEstimatedOneRepMax(ProgressionFormula)
    case updateActualOneRepMax(ProgressionFormula)
    case updateVelocityBaseline(ProgressionFormula)
    case repeatPrescription
    case changeStage(String)
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
    /// Ends only the still-unperformed daily-maximum attempts in the active
    /// exercise occurrence, then creates the authored number of back-off
    /// prescriptions from the best successful parent attempt. This action is
    /// recommendation-only and has meaning only while that workout is active.
    case endActiveDailyMaximumAndGenerateBackOffs(
        setCount: Int,
        repetitions: Int,
        percentage: Double
    )
    case endProgram
    case generateRecommendation
    case noChange
}

nonisolated enum ProgressionCadence: String, Codable, CaseIterable, Hashable {
    case immediately
    case nextSet
    case nextExerciseOccurrence
    case nextWorkout
    case nextWeek
    case nextWave
    case nextBlock
    case nextCycle
}

nonisolated enum ProgressionScope: String, Codable, CaseIterable, Hashable {
    case set
    case plannedExercise
    case exerciseExposure
    case workout
    case week
    case block
    case cycle
    case programRun
}

nonisolated enum ProgressionApplicationMode: String, Codable, CaseIterable, Hashable {
    case automatic
    case recommendation
}

nonisolated struct ProgressionRuleDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var version: Int
    var metric: ProgressionMetric
    var trigger: ProgressionTrigger
    var successAction: ProgressionAction
    var failureAction: ProgressionAction?
    var cadence: ProgressionCadence
    var scope: ProgressionScope
    var formula: ProgressionFormula?
    var priority: Int
    var applicationMode: ProgressionApplicationMode
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        version: Int = 1,
        metric: ProgressionMetric,
        trigger: ProgressionTrigger,
        successAction: ProgressionAction,
        failureAction: ProgressionAction? = nil,
        cadence: ProgressionCadence,
        scope: ProgressionScope,
        formula: ProgressionFormula? = nil,
        priority: Int = 0,
        applicationMode: ProgressionApplicationMode = .recommendation,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.version = version
        self.metric = metric
        self.trigger = trigger
        self.successAction = successAction
        self.failureAction = failureAction
        self.cadence = cadence
        self.scope = scope
        self.formula = formula
        self.priority = priority
        self.applicationMode = applicationMode
        self.isEnabled = isEnabled
    }
}

#endif

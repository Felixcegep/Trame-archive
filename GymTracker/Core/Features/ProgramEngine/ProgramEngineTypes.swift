import Foundation

#if !GYMTRACKER_EXTENSION

// MARK: - Prescriptions

enum ProgramSetRole: String, Codable, CaseIterable, Hashable {
    case warmup
    case working
    case topSet
    case backOff
    case amrap
    case dropSet
    case technique
    case dailyMaximum
    case test
    case recovery
}

struct RepComponent: Codable, Hashable {
    var exerciseID: UUID
    var repetitions: Int
}

indirect enum RepPrescription: Codable, Hashable {
    case fixed(Int)
    case range(minimum: Int, maximum: Int)
    case amrap(minimum: Int?, maximum: Int?)
    case sequence([RepComponent])
    case duration(seconds: Double?)
    case distance(meters: Double?)
    case calories(Double?)
    case open
}

enum LoadReferenceKind: String, Codable, CaseIterable, Hashable {
    case manual
    case fixedLoad
    case exerciseOneRepMax
    case estimatedOneRepMax
    case trainingMax
    case referenceExercise
    case previousWorkout
    case previousSuccessfulSet
    case previousOccurrence
    case topSet
    case dailyMaximum
    case anotherPlannedExercise
}

struct LoadReference: Codable, Hashable {
    var kind: LoadReferenceKind
    var exerciseID: UUID?
    var exposureKey: String?

    init(
        kind: LoadReferenceKind,
        exerciseID: UUID? = nil,
        exposureKey: String? = nil
    ) {
        self.kind = kind
        self.exerciseID = exerciseID
        self.exposureKey = exposureKey
    }
}

enum LoadRoundingRule: Codable, Hashable {
    case none
    case nearestIncrement(Double)
    case floorToIncrement(Double)
    case ceilingToIncrement(Double)
    case nearestAvailable([Double])
}

struct LoadPrescription: Codable, Hashable {
    var reference: LoadReference
    var fixedValue: Double?
    var percentage: Double?
    var absoluteOffset: Double
    var percentageOffset: Double?
    var minimum: Double?
    var maximum: Double?
    var rounding: LoadRoundingRule

    init(
        reference: LoadReference = LoadReference(kind: .manual),
        fixedValue: Double? = nil,
        percentage: Double? = nil,
        absoluteOffset: Double = 0,
        percentageOffset: Double? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        rounding: LoadRoundingRule = .none
    ) {
        self.reference = reference
        self.fixedValue = fixedValue
        self.percentage = percentage
        self.absoluteOffset = absoluteOffset
        self.percentageOffset = percentageOffset
        self.minimum = minimum
        self.maximum = maximum
        self.rounding = rounding
    }
}

struct SetPrescriptionDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var role: ProgramSetRole
    var repetitions: RepPrescription
    var load: LoadPrescription
    var targetRPE: Double?
    var targetRIR: Int?
    var restSeconds: Int?
    var tempo: String?
    var isOptional: Bool
    var progressionEligible: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        role: ProgramSetRole = .working,
        repetitions: RepPrescription,
        load: LoadPrescription = LoadPrescription(),
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        restSeconds: Int? = nil,
        tempo: String? = nil,
        isOptional: Bool = false,
        progressionEligible: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.role = role
        self.repetitions = repetitions
        self.load = load
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.restSeconds = restSeconds
        self.tempo = tempo
        self.isOptional = isOptional
        self.progressionEligible = progressionEligible
        self.notes = notes
    }
}

// MARK: - Formulas and progression rules

enum FormulaSource: Codable, Hashable {
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
}

indirect enum ProgressionFormula: Codable, Hashable {
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

enum ProgressionMetric: String, Codable, CaseIterable, Hashable {
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
}

enum ProgressionTrigger: Codable, Hashable {
    case allRequiredSetsCompleted
    case allRequiredRepetitionsCompleted
    case allSetsReachedUpperRepBound
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
    case successfulAttemptRatioReached(Double)
    case technicalQualityReached
    case workoutCompleted
    case weekCompleted
    case waveCompleted
    case blockCompleted
    case cycleCompleted
    case scheduledDateReached
    case manualApproval
}

enum ProgressionAction: Codable, Hashable {
    case addLoad(Double)
    case reduceLoad(Double)
    case addLoadPercentage(Double)
    case reduceLoadPercentage(Double)
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
    case endProgram
    case generateRecommendation
    case noChange
}

enum ProgressionCadence: String, Codable, CaseIterable, Hashable {
    case immediately
    case nextSet
    case nextExerciseOccurrence
    case nextWorkout
    case nextWeek
    case nextWave
    case nextBlock
    case nextCycle
}

enum ProgressionScope: String, Codable, CaseIterable, Hashable {
    case set
    case plannedExercise
    case exerciseExposure
    case workout
    case week
    case block
    case cycle
    case programRun
}

enum ProgressionApplicationMode: String, Codable, CaseIterable, Hashable {
    case automatic
    case recommendation
}

struct ProgressionRuleDefinition: Codable, Hashable, Identifiable {
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

// MARK: - Versioned program payload

struct ProgramDefinitionPayload: Codable, Hashable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var templateVersion: Int
    var name: String
    var description: String?
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var durationWeeks: Int
    var supportedDaysPerWeek: [Int]
    var scheduleMode: PlanScheduleMode
    var scheduleIntervalDays: Int
    var requiredEquipment: [EquipmentType]
    var blocks: [ProgramBlockDefinition]

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        templateVersion: Int = 1,
        name: String,
        description: String? = nil,
        goal: PlanGoal = .generalStrength,
        experienceLevel: PlanExperienceLevel = .beginner,
        durationWeeks: Int,
        supportedDaysPerWeek: [Int],
        scheduleMode: PlanScheduleMode = .fixedWeekdays,
        scheduleIntervalDays: Int = 1,
        requiredEquipment: [EquipmentType] = [],
        blocks: [ProgramBlockDefinition]
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.templateVersion = templateVersion
        self.name = name
        self.description = description
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.durationWeeks = durationWeeks
        self.supportedDaysPerWeek = supportedDaysPerWeek
        self.scheduleMode = scheduleMode
        self.scheduleIntervalDays = max(1, scheduleIntervalDays)
        self.requiredEquipment = requiredEquipment
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, templateVersion, name, description, goal,
             experienceLevel, durationWeeks, supportedDaysPerWeek,
             scheduleMode, scheduleIntervalDays, requiredEquipment, blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        templateVersion = try container.decode(Int.self, forKey: .templateVersion)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        goal = try container.decode(PlanGoal.self, forKey: .goal)
        experienceLevel = try container.decode(PlanExperienceLevel.self, forKey: .experienceLevel)
        durationWeeks = try container.decode(Int.self, forKey: .durationWeeks)
        supportedDaysPerWeek = try container.decode([Int].self, forKey: .supportedDaysPerWeek)
        scheduleMode = try container.decodeIfPresent(PlanScheduleMode.self, forKey: .scheduleMode) ?? .fixedWeekdays
        scheduleIntervalDays = max(1, try container.decodeIfPresent(Int.self, forKey: .scheduleIntervalDays) ?? 1)
        requiredEquipment = try container.decodeIfPresent([EquipmentType].self, forKey: .requiredEquipment) ?? []
        blocks = try container.decode([ProgramBlockDefinition].self, forKey: .blocks)
    }
}

struct ProgramBlockDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var phaseType: PlanPhaseType
    var weeks: [ProgramWeekDefinition]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        name: String,
        phaseType: PlanPhaseType = .accumulation,
        weeks: [ProgramWeekDefinition]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.phaseType = phaseType
        self.weeks = weeks
    }
}

struct ProgramWeekDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var weekIndex: Int
    var name: String?
    var workouts: [ProgramWorkoutDefinition]

    init(
        id: UUID = UUID(),
        weekIndex: Int,
        name: String? = nil,
        workouts: [ProgramWorkoutDefinition]
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.name = name
        self.workouts = workouts
    }
}

struct ProgramWorkoutDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var dayOffset: Int
    var role: String
    var plannedExercises: [ProgramExerciseDefinition]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        name: String,
        dayOffset: Int,
        role: String = "strength",
        plannedExercises: [ProgramExerciseDefinition]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.dayOffset = dayOffset
        self.role = role
        self.plannedExercises = plannedExercises
    }
}

struct ProgramWaveDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String?
    var plannedSets: [SetPrescriptionDefinition]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        name: String? = nil,
        plannedSets: [SetPrescriptionDefinition]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.plannedSets = plannedSets
    }
}

struct ProgramExerciseDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var exerciseID: UUID
    var exposureKey: String
    var orderIndex: Int
    var isOptional: Bool
    var plannedSets: [SetPrescriptionDefinition]
    var waves: [ProgramWaveDefinition]
    var progressionRules: [ProgressionRuleDefinition]
    var alternativeExerciseIDs: [UUID]
    var initialLoad: Double?
    var initialTrainingMax: Double?
    var initialEstimatedOneRepMax: Double?
    var initialActualOneRepMax: Double?

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exposureKey: String,
        orderIndex: Int,
        isOptional: Bool = false,
        plannedSets: [SetPrescriptionDefinition],
        waves: [ProgramWaveDefinition] = [],
        progressionRules: [ProgressionRuleDefinition] = [],
        alternativeExerciseIDs: [UUID] = [],
        initialLoad: Double? = nil,
        initialTrainingMax: Double? = nil,
        initialEstimatedOneRepMax: Double? = nil,
        initialActualOneRepMax: Double? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exposureKey = exposureKey
        self.orderIndex = orderIndex
        self.isOptional = isOptional
        self.plannedSets = plannedSets
        self.waves = waves
        self.progressionRules = progressionRules
        self.alternativeExerciseIDs = alternativeExerciseIDs
        self.initialLoad = initialLoad
        self.initialTrainingMax = initialTrainingMax
        self.initialEstimatedOneRepMax = initialEstimatedOneRepMax
        self.initialActualOneRepMax = initialActualOneRepMax
    }
}

// MARK: - Validation

struct ProgramValidationIssue: Codable, Hashable, Identifiable {
    enum Code: String, Codable, Hashable {
        case invalidSchemaVersion
        case emptyName
        case invalidDuration
        case invalidSchedule
        case emptyBlocks
        case emptyWeeks
        case emptyWorkouts
        case invalidDayOffset
        case emptyWorkout
        case emptyExposureKey
        case emptySetPrescription
        case invalidSetOrder
        case invalidRepRange
        case invalidRest
        case invalidRPE
        case invalidRIR
        case invalidPrescriptionValue
        case invalidLoadReference
        case invalidPercentage
        case invalidFormula
        case duplicateIdentifier
        case duplicateExposureKey
        case formulaCycle
    }

    var id: UUID = UUID()
    var path: String
    var code: Code
    var message: String
}

enum ProgramDefinitionValidator {
    static func validate(_ definition: ProgramDefinitionPayload) -> [ProgramValidationIssue] {
        var issues: [ProgramValidationIssue] = []
        func add(_ path: String, _ code: ProgramValidationIssue.Code, _ message: String) {
            issues.append(ProgramValidationIssue(path: path, code: code, message: message))
        }

        if definition.schemaVersion < 1 { add("schemaVersion", .invalidSchemaVersion, "Schema version must be positive.") }
        if definition.templateVersion < 1 { add("templateVersion", .invalidSchemaVersion, "Template version must be positive.") }
        if definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("name", .emptyName, "A program name is required.") }
        if definition.durationWeeks < 1 { add("durationWeeks", .invalidDuration, "A program must contain at least one week.") }
        if definition.supportedDaysPerWeek.isEmpty || definition.supportedDaysPerWeek.contains(where: { $0 < 1 || $0 > 7 }) {
            add("supportedDaysPerWeek", .invalidSchedule, "Supported days must be between one and seven.")
        }
        if definition.scheduleIntervalDays < 1 {
            add("scheduleIntervalDays", .invalidSchedule, "Schedule interval must be at least one day.")
        }
        if definition.blocks.isEmpty { add("blocks", .emptyBlocks, "A program must contain a block.") }

        var identifiers = Set<UUID>()
        var formulaSources: [String: Set<String>] = [:]
        func checkID(_ id: UUID, _ path: String) {
            if !identifiers.insert(id).inserted { add(path, .duplicateIdentifier, "Identifier is used more than once.") }
        }
        for (blockIndex, block) in definition.blocks.enumerated() {
            let blockPath = "blocks[\(blockIndex)]"
            checkID(block.id, blockPath)
            if block.weeks.isEmpty { add(blockPath, .emptyWeeks, "A block must contain a week.") }
            var weekOrders = Set<Int>()
            for (weekIndex, week) in block.weeks.enumerated() {
                let weekPath = "\(blockPath).weeks[\(weekIndex)]"
                checkID(week.id, weekPath)
                if !weekOrders.insert(week.weekIndex).inserted { add("\(weekPath).weekIndex", .invalidSetOrder, "Week indices must be unique within a block.") }
                if week.workouts.isEmpty { add(weekPath, .emptyWorkouts, "A week must contain a workout.") }
                var workoutOrders = Set<Int>()
                for (workoutIndex, workout) in week.workouts.enumerated() {
                    let workoutPath = "\(weekPath).workouts[\(workoutIndex)]"
                    checkID(workout.id, workoutPath)
                    if !workoutOrders.insert(workout.orderIndex).inserted { add("\(workoutPath).orderIndex", .invalidSetOrder, "Workout order indices must be unique within a week.") }
                    var workoutExposures = Set<String>()
                    if workout.dayOffset < 0 || workout.dayOffset > 6 { add("\(workoutPath).dayOffset", .invalidDayOffset, "Day offset must be between zero and six.") }
                    if workout.plannedExercises.isEmpty { add(workoutPath, .emptyWorkout, "A workout must contain an exercise.") }
                    for (exerciseIndex, exercise) in workout.plannedExercises.enumerated() {
                        let exercisePath = "\(workoutPath).exercises[\(exerciseIndex)]"
                        checkID(exercise.id, exercisePath)
                        if exercise.exposureKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            add("\(exercisePath).exposureKey", .emptyExposureKey, "Every planned exposure needs a stable key.")
                        } else if !workoutExposures.insert(exercise.exposureKey).inserted {
                            add("\(exercisePath).exposureKey", .duplicateExposureKey, "Exposure keys must be unique within a program definition.")
                        }
                        if exercise.plannedSets.isEmpty && exercise.waves.isEmpty { add(exercisePath, .emptySetPrescription, "An exercise must contain a set prescription or wave.") }
                        var setOrders = Set<Int>()
                        for (setIndex, set) in exercise.plannedSets.enumerated() {
                            let setPath = "\(exercisePath).sets[\(setIndex)]"
                            checkID(set.id, setPath)
                            if set.orderIndex < 0 { add("\(setPath).orderIndex", .invalidSetOrder, "Set order must not be negative.") }
                            if !setOrders.insert(set.orderIndex).inserted { add("\(setPath).orderIndex", .invalidSetOrder, "Set order indices must be unique within an exercise.") }
                            validateRep(set.repetitions, setPath, add)
                            if let rest = set.restSeconds, rest < 0 { add("\(setPath).restSeconds", .invalidRest, "Rest cannot be negative.") }
                            if let rpe = set.targetRPE, rpe < 0 || rpe > 10 { add("\(setPath).targetRPE", .invalidRPE, "RPE must be between zero and ten.") }
                            if let rir = set.targetRIR, rir < 0 || rir > 10 { add("\(setPath).targetRIR", .invalidRIR, "RIR must be between zero and ten.") }
                            validateLoad(set.load, "\(setPath).load", add)
                        }
                        if !exercise.waves.isEmpty {
                            var waveOrders = Set<Int>()
                            var waveSetCount: Int?
                            for (waveIndex, wave) in exercise.waves.enumerated() {
                                let wavePath = "\(exercisePath).waves[\(waveIndex)]"
                                checkID(wave.id, wavePath)
                                if !waveOrders.insert(wave.orderIndex).inserted { add("\(wavePath).orderIndex", .invalidSetOrder, "Wave order indices must be unique within an exercise.") }
                                if wave.plannedSets.isEmpty { add(wavePath, .emptySetPrescription, "A wave must contain a set prescription.") }
                                if let waveSetCount, waveSetCount != wave.plannedSets.count {
                                    add(wavePath, .invalidSetOrder, "All waves for one exercise must contain the same number of sets.")
                                } else {
                                    waveSetCount = wave.plannedSets.count
                                }
                                var waveSetOrders = Set<Int>()
                                for (setIndex, set) in wave.plannedSets.enumerated() {
                                    let setPath = "\(wavePath).sets[\(setIndex)]"
                                    checkID(set.id, setPath)
                                    if set.orderIndex < 0 { add("\(setPath).orderIndex", .invalidSetOrder, "Set order must not be negative.") }
                                    if !waveSetOrders.insert(set.orderIndex).inserted { add("\(setPath).orderIndex", .invalidSetOrder, "Set order indices must be unique within a wave.") }
                                    validateRep(set.repetitions, setPath, add)
                                    if let rest = set.restSeconds, rest < 0 { add("\(setPath).restSeconds", .invalidRest, "Rest cannot be negative.") }
                                    if let rpe = set.targetRPE, rpe < 0 || rpe > 10 { add("\(setPath).targetRPE", .invalidRPE, "RPE must be between zero and ten.") }
                                    if let rir = set.targetRIR, rir < 0 || rir > 10 { add("\(setPath).targetRIR", .invalidRIR, "RIR must be between zero and ten.") }
                                    validateLoad(set.load, "\(setPath).load", add)
                                }
                            }
                        }
                        for (ruleIndex, rule) in exercise.progressionRules.enumerated() {
                            if let formula = rule.formula {
                                var sources = Set<String>()
                                collectSources(formula, into: &sources)
                                formulaSources[exercise.exposureKey, default: []].formUnion(sources)
                            }
                            if rule.version < 1 { add("\(exercisePath).rules[\(ruleIndex)].version", .invalidSchemaVersion, "Rule version must be positive.") }
                        }
                    }
                }
            }
        }

        if hasCycle(in: formulaSources) {
            add("progressionRules", .formulaCycle, "Formula references contain a cycle.")
        }
        return issues
    }

    private static func validateRep(
        _ prescription: RepPrescription,
        _ path: String,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        switch prescription {
        case .fixed(let repetitions):
            if repetitions < 1 { add(path, .invalidRepRange, "Fixed repetitions must be positive.") }
        case .range(let minimum, let maximum):
            if minimum < 1 || maximum < minimum { add(path, .invalidRepRange, "Rep range is invalid.") }
        case .amrap(let minimum, let maximum):
            if let minimum, minimum < 0 { add(path, .invalidRepRange, "AMRAP minimum cannot be negative.") }
            if let maximum, maximum < (minimum ?? 0) { add(path, .invalidRepRange, "AMRAP maximum cannot be below its minimum.") }
        case .sequence(let components):
            if components.isEmpty || components.contains(where: { $0.repetitions < 1 }) { add(path, .invalidRepRange, "A sequence needs positive repetitions.") }
        case .duration(let seconds):
            if let seconds, !seconds.isFinite || seconds <= 0 { add(path, .invalidPrescriptionValue, "Duration must be a positive finite value.") }
        case .distance(let meters):
            if let meters, !meters.isFinite || meters <= 0 { add(path, .invalidPrescriptionValue, "Distance must be a positive finite value.") }
        case .calories(let calories):
            if let calories, !calories.isFinite || calories <= 0 { add(path, .invalidPrescriptionValue, "Calories must be a positive finite value.") }
        case .open:
            break
        }
    }

    private static func validateLoad(
        _ load: LoadPrescription,
        _ path: String,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        switch load.reference.kind {
        case .trainingMax, .estimatedOneRepMax, .previousWorkout, .previousSuccessfulSet,
                .previousOccurrence, .topSet, .dailyMaximum, .anotherPlannedExercise:
            if load.reference.exposureKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                add("(path).reference", .invalidLoadReference, "This load reference requires an exposure key.")
            }
        case .exerciseOneRepMax, .referenceExercise:
            if load.reference.exerciseID == nil && load.reference.exposureKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                add("(path).reference", .invalidLoadReference, "This load reference requires an exercise or exposure key.")
            }
        case .manual, .fixedLoad:
            break
        }
        if let percentage = load.percentage, percentage < 0 || percentage > 3 {
            add("\(path).percentage", .invalidPercentage, "Percentage must be between zero and three.")
        }
        if let percentage = load.percentageOffset, percentage < -3 || percentage > 3 {
            add("\(path).percentageOffset", .invalidPercentage, "Percentage offset must be between negative three and three.")
        }
        if let minimum = load.minimum, let maximum = load.maximum, minimum > maximum {
            add(path, .invalidPercentage, "Load minimum cannot exceed maximum.")
        }
    }

    private static func collectSources(_ formula: ProgressionFormula, into sources: inout Set<String>) {
        switch formula {
        case .source(let source):
            switch source {
            case .trainingMax(let key), .estimatedOneRepMax(let key), .actualOneRepMax(let key),
                    .previousOccurrence(let key), .previousSuccessfulSet(let key), .completedTopSet(let key),
                    .dailyMaximum(let key), .anotherExposure(let key):
                sources.insert(key)
            case .constant, .completedMetric:
                break
            }
        case .add(let lhs, let rhs), .subtract(let lhs, let rhs), .multiply(let lhs, let rhs),
                .divide(let lhs, let rhs), .minimum(let lhs, let rhs), .maximum(let lhs, let rhs):
            collectSources(lhs, into: &sources)
            collectSources(rhs, into: &sources)
        case .clamp(let value, _, _), .round(let value, _):
            collectSources(value, into: &sources)
        }
    }

    private static func hasCycle(in graph: [String: Set<String>]) -> Bool {
        var visiting = Set<String>()
        var visited = Set<String>()
        func visit(_ node: String) -> Bool {
            if visiting.contains(node) { return true }
            if visited.contains(node) { return false }
            visiting.insert(node)
            for dependency in graph[node] ?? [] where graph[dependency] != nil {
                if visit(dependency) { return true }
            }
            visiting.remove(node)
            visited.insert(node)
            return false
        }
        return graph.keys.contains(where: visit)
    }
}
#endif

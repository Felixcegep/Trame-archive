import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated struct ProgramIntakeInput: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case oneRepMax
        case estimatedOneRepMaxReps
        case trainingMax
        case startingLoad
        case startingVariation
        case probeVelocity
    }

    var exposureKey: String
    var kind: Kind
    var isRequired: Bool
    var defaultPercentOfMax: Double?

    init(
        exposureKey: String,
        kind: Kind,
        isRequired: Bool = true,
        defaultPercentOfMax: Double? = nil
    ) {
        self.exposureKey = exposureKey
        self.kind = kind
        self.isRequired = isRequired
        self.defaultPercentOfMax = defaultPercentOfMax
    }
}

nonisolated enum MissedWorkoutPolicy: String, Codable, Hashable {
    case shiftSequence
    case skipAndContinue
}

nonisolated enum CompletionPolicy: Codable, Hashable {
    case end
    case offerRestart(carryState: Bool)
    case offerTestDay
}

/// Capability identifiers are intentionally strings in persisted payloads so a
/// newer library can describe requirements to an older app without decoding a
/// newer Swift enum case.
nonisolated enum EngineCapabilities {
    static let compositeTriggers = "compositeTriggers"
    static let stages = "stages"
    static let waves = "waves"
    static let variationLadders = "variationLadders"
    static let amrapRepetitions = "amrapRepetitions"
    static let velocity = "velocity"

    static let current: Set<String> = [
        compositeTriggers, stages, waves, variationLadders, amrapRepetitions, velocity
    ]

    static func missing(from requiredCapabilities: [String]) -> Set<String> {
        Set(requiredCapabilities).subtracting(current)
    }
}

nonisolated struct ProgramDefinitionPayload: Codable, Hashable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var templateVersion: Int
    var programKey: String
    var name: String
    var description: String?
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var durationWeeks: Int
    var supportedDaysPerWeek: [Int]
    var scheduleMode: PlanScheduleMode
    var scheduleIntervalDays: Int
    var requiredEquipment: [EquipmentType]
    var prerequisites: [String]
    var warnings: [String]
    var isExperimental: Bool
    var intakeInputs: [ProgramIntakeInput]
    var missedWorkoutPolicy: MissedWorkoutPolicy
    var completionPolicy: CompletionPolicy
    var requiredCapabilities: [String]
    var blocks: [ProgramBlockDefinition]

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        templateVersion: Int = 1,
        programKey: String = "",
        name: String,
        description: String? = nil,
        goal: PlanGoal = .generalStrength,
        experienceLevel: PlanExperienceLevel = .beginner,
        durationWeeks: Int,
        supportedDaysPerWeek: [Int],
        scheduleMode: PlanScheduleMode = .fixedWeekdays,
        scheduleIntervalDays: Int = 1,
        requiredEquipment: [EquipmentType] = [],
        prerequisites: [String] = [],
        warnings: [String] = [],
        isExperimental: Bool = false,
        intakeInputs: [ProgramIntakeInput] = [],
        missedWorkoutPolicy: MissedWorkoutPolicy = .shiftSequence,
        completionPolicy: CompletionPolicy = .end,
        requiredCapabilities: [String] = [],
        blocks: [ProgramBlockDefinition]
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.templateVersion = templateVersion
        self.programKey = programKey
        self.name = name
        self.description = description
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.durationWeeks = durationWeeks
        self.supportedDaysPerWeek = supportedDaysPerWeek
        self.scheduleMode = scheduleMode
        self.scheduleIntervalDays = max(1, scheduleIntervalDays)
        self.requiredEquipment = requiredEquipment
        self.prerequisites = prerequisites
        self.warnings = warnings
        self.isExperimental = isExperimental
        self.intakeInputs = intakeInputs
        self.missedWorkoutPolicy = missedWorkoutPolicy
        self.completionPolicy = completionPolicy
        self.requiredCapabilities = requiredCapabilities
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, templateVersion, programKey, name, description, goal,
             experienceLevel, durationWeeks, supportedDaysPerWeek,
             scheduleMode, scheduleIntervalDays, requiredEquipment, prerequisites,
             warnings, isExperimental, intakeInputs, missedWorkoutPolicy,
             completionPolicy, requiredCapabilities, blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        templateVersion = try container.decode(Int.self, forKey: .templateVersion)
        programKey = try container.decodeIfPresent(String.self, forKey: .programKey) ?? ""
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        goal = try container.decode(PlanGoal.self, forKey: .goal)
        experienceLevel = try container.decode(PlanExperienceLevel.self, forKey: .experienceLevel)
        durationWeeks = try container.decode(Int.self, forKey: .durationWeeks)
        supportedDaysPerWeek = try container.decode([Int].self, forKey: .supportedDaysPerWeek)
        scheduleMode = try container.decodeIfPresent(PlanScheduleMode.self, forKey: .scheduleMode) ?? .fixedWeekdays
        scheduleIntervalDays = max(1, try container.decodeIfPresent(Int.self, forKey: .scheduleIntervalDays) ?? 1)
        requiredEquipment = try container.decodeIfPresent([EquipmentType].self, forKey: .requiredEquipment) ?? []
        prerequisites = try container.decodeIfPresent([String].self, forKey: .prerequisites) ?? []
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        isExperimental = try container.decodeIfPresent(Bool.self, forKey: .isExperimental) ?? false
        intakeInputs = try container.decodeIfPresent([ProgramIntakeInput].self, forKey: .intakeInputs) ?? []
        missedWorkoutPolicy = try container.decodeIfPresent(MissedWorkoutPolicy.self, forKey: .missedWorkoutPolicy) ?? .shiftSequence
        completionPolicy = try container.decodeIfPresent(CompletionPolicy.self, forKey: .completionPolicy) ?? .end
        requiredCapabilities = try container.decodeIfPresent([String].self, forKey: .requiredCapabilities) ?? []
        blocks = try container.decode([ProgramBlockDefinition].self, forKey: .blocks)
    }
}

nonisolated struct ProgramBlockDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var phaseType: PlanPhaseType
    var deloadVolumeReductionPercent: Int?
    var deloadIntensityReductionPercent: Int?
    var weeks: [ProgramWeekDefinition]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        name: String,
        phaseType: PlanPhaseType = .accumulation,
        deloadVolumeReductionPercent: Int? = nil,
        deloadIntensityReductionPercent: Int? = nil,
        weeks: [ProgramWeekDefinition]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.phaseType = phaseType
        self.deloadVolumeReductionPercent = deloadVolumeReductionPercent
        self.deloadIntensityReductionPercent = deloadIntensityReductionPercent
        self.weeks = weeks
    }
}

nonisolated struct ProgramWeekDefinition: Codable, Hashable, Identifiable {
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

nonisolated struct ProgramWorkoutDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var dayOffset: Int
    var role: String
    var isOptional: Bool
    var plannedExercises: [ProgramExerciseDefinition]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        name: String,
        dayOffset: Int,
        role: String = "strength",
        isOptional: Bool = false,
        plannedExercises: [ProgramExerciseDefinition]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.dayOffset = dayOffset
        self.role = role
        self.isOptional = isOptional
        self.plannedExercises = plannedExercises
    }

    private enum CodingKeys: String, CodingKey {
        case id, orderIndex, name, dayOffset, role, isOptional, plannedExercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        name = try container.decode(String.self, forKey: .name)
        dayOffset = try container.decode(Int.self, forKey: .dayOffset)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "strength"
        isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false
        plannedExercises = try container.decode([ProgramExerciseDefinition].self, forKey: .plannedExercises)
    }
}

nonisolated struct ProgramWaveDefinition: Codable, Hashable, Identifiable {
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

nonisolated struct ProgramStageDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var stageID: String
    var name: String?
    var plannedSets: [SetPrescriptionDefinition]
    var carriesLoad: Bool

    init(
        id: UUID = UUID(),
        stageID: String,
        name: String? = nil,
        plannedSets: [SetPrescriptionDefinition],
        carriesLoad: Bool = true
    ) {
        self.id = id
        self.stageID = stageID
        self.name = name
        self.plannedSets = plannedSets
        self.carriesLoad = carriesLoad
    }
}

nonisolated struct ProgramStageConfiguration: Codable, Hashable {
    var stages: [ProgramStageDefinition]
    var initialStageID: String
}

nonisolated struct AutomaticDeloadDefinition: Codable, Hashable {
    var volumeReductionPercent: Int
    var intensityReductionPercent: Int

    init(volumeReductionPercent: Int = 50, intensityReductionPercent: Int = 10) {
        self.volumeReductionPercent = min(90, max(0, volumeReductionPercent))
        self.intensityReductionPercent = min(90, max(0, intensityReductionPercent))
    }
}

nonisolated struct ProgramExerciseDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var exerciseID: UUID
    var exposureKey: String
    var orderIndex: Int
    var isOptional: Bool
    var plannedSets: [SetPrescriptionDefinition]
    var waves: [ProgramWaveDefinition]
    var stages: [ProgramStageDefinition]
    var initialStageID: String?
    var progressionRules: [ProgressionRuleDefinition]
    var alternativeExerciseIDs: [UUID]
    var variationExerciseIDs: [UUID]?
    var initialVariationExerciseID: UUID?
    var initialVelocityBaseline: Double?
    var initialLoad: Double?
    var initialTrainingMax: Double?
    var initialEstimatedOneRepMax: Double?
    var initialActualOneRepMax: Double?
    var automaticDeload: AutomaticDeloadDefinition?
    var warmupScheme: WarmupSchemeDefinition?

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exposureKey: String,
        orderIndex: Int,
        isOptional: Bool = false,
        plannedSets: [SetPrescriptionDefinition],
        waves: [ProgramWaveDefinition] = [],
        stages: [ProgramStageDefinition] = [],
        initialStageID: String? = nil,
        progressionRules: [ProgressionRuleDefinition] = [],
        alternativeExerciseIDs: [UUID] = [],
        variationExerciseIDs: [UUID]? = nil,
        initialVariationExerciseID: UUID? = nil,
        initialVelocityBaseline: Double? = nil,
        initialLoad: Double? = nil,
        initialTrainingMax: Double? = nil,
        initialEstimatedOneRepMax: Double? = nil,
        initialActualOneRepMax: Double? = nil,
        automaticDeload: AutomaticDeloadDefinition? = nil,
        warmupScheme: WarmupSchemeDefinition? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exposureKey = exposureKey
        self.orderIndex = orderIndex
        self.isOptional = isOptional
        self.plannedSets = plannedSets
        self.waves = waves
        self.stages = stages
        self.initialStageID = initialStageID
        self.progressionRules = progressionRules
        self.alternativeExerciseIDs = alternativeExerciseIDs
        self.variationExerciseIDs = variationExerciseIDs
        self.initialVariationExerciseID = initialVariationExerciseID
        self.initialVelocityBaseline = initialVelocityBaseline
        self.initialLoad = initialLoad
        self.initialTrainingMax = initialTrainingMax
        self.initialEstimatedOneRepMax = initialEstimatedOneRepMax
        self.initialActualOneRepMax = initialActualOneRepMax
        self.automaticDeload = automaticDeload
        self.warmupScheme = warmupScheme
    }
}

#endif

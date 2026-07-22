import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated enum ProgramSetRole: String, Codable, CaseIterable, Hashable {
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

nonisolated struct RepComponent: Codable, Hashable {
    var exerciseID: UUID
    var repetitions: Int
    /// Copied when the component is authored or compiled so completed history
    /// does not depend on the current exercise-library name.
    var exerciseNameSnapshot: String?

    init(exerciseID: UUID, repetitions: Int, exerciseNameSnapshot: String? = nil) {
        self.exerciseID = exerciseID
        self.repetitions = repetitions
        self.exerciseNameSnapshot = exerciseNameSnapshot
    }
}

nonisolated indirect enum RepPrescription: Codable, Hashable {
    case fixed(Int)
    case range(minimum: Int, maximum: Int)
    case amrap(minimum: Int?, maximum: Int?)
    case sequence([RepComponent])
    case duration(seconds: Double?)
    case distance(meters: Double?)
    case calories(Double?)
    case open
}

nonisolated enum LoadReferenceKind: String, Codable, CaseIterable, Hashable {
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

nonisolated struct LoadReference: Codable, Hashable {
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

nonisolated enum LoadRoundingRule: Codable, Hashable {
    case none
    case nearestIncrement(Double)
    case floorToIncrement(Double)
    case ceilingToIncrement(Double)
    case nearestAvailable([Double])
}

nonisolated struct LoadPrescription: Codable, Hashable {
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

nonisolated struct SetPrescriptionDefinition: Codable, Hashable, Identifiable {
    struct VelocityPrescription: Codable, Hashable {
        var targetMinimum: Double?
        var targetMaximum: Double?
        var lossStopPercent: Double?
        var isProbe: Bool

        init(targetMinimum: Double? = nil, targetMaximum: Double? = nil, lossStopPercent: Double? = nil, isProbe: Bool = false) {
            self.targetMinimum = targetMinimum
            self.targetMaximum = targetMaximum
            self.lossStopPercent = lossStopPercent
            self.isProbe = isProbe
        }
    }
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
    var velocity: VelocityPrescription?
    /// Defers a back-off set until its top-set or daily-maximum load reference
    /// exists in the active workout. Existing explicit back-off sets retain
    /// their current eager snapshot behavior.
    var generatesAfterSourceCompletion: Bool

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
        notes: String? = nil,
        velocity: VelocityPrescription? = nil,
        generatesAfterSourceCompletion: Bool = false
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
        self.velocity = velocity
        self.generatesAfterSourceCompletion = generatesAfterSourceCompletion
    }

    private enum CodingKeys: String, CodingKey {
        case id, orderIndex, role, repetitions, load, targetRPE, targetRIR
        case restSeconds, tempo, isOptional, progressionEligible, notes
        case generatesAfterSourceCompletion, velocity
    }

    /// Program definitions predate deferred back-off generation. Decode its
    /// opt-in flag defensively so an existing export remains a valid eager
    /// prescription rather than failing to import.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        orderIndex = try values.decode(Int.self, forKey: .orderIndex)
        role = try values.decode(ProgramSetRole.self, forKey: .role)
        repetitions = try values.decode(RepPrescription.self, forKey: .repetitions)
        load = try values.decode(LoadPrescription.self, forKey: .load)
        targetRPE = try values.decodeIfPresent(Double.self, forKey: .targetRPE)
        targetRIR = try values.decodeIfPresent(Int.self, forKey: .targetRIR)
        restSeconds = try values.decodeIfPresent(Int.self, forKey: .restSeconds)
        tempo = try values.decodeIfPresent(String.self, forKey: .tempo)
        isOptional = try values.decode(Bool.self, forKey: .isOptional)
        progressionEligible = try values.decode(Bool.self, forKey: .progressionEligible)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        velocity = try values.decodeIfPresent(VelocityPrescription.self, forKey: .velocity)
        generatesAfterSourceCompletion = try values.decodeIfPresent(
            Bool.self,
            forKey: .generatesAfterSourceCompletion
        ) ?? false
    }
}

nonisolated struct WarmupStepDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var percentage: Double
    var repetitions: Int
    var restSeconds: Int?

    init(id: UUID = UUID(), percentage: Double, repetitions: Int, restSeconds: Int? = nil) {
        self.id = id
        self.percentage = min(1, max(0, percentage))
        self.repetitions = max(1, repetitions)
        self.restSeconds = restSeconds.map { max(0, $0) }
    }
}

nonisolated struct WarmupSchemeDefinition: Codable, Hashable {
    var steps: [WarmupStepDefinition]

    init(steps: [WarmupStepDefinition]) {
        self.steps = steps
    }
}

#endif

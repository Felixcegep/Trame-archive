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

/// Optional technical context for one Olympic-lifting parent attempt. The
/// performed load and result remain on the parent `ExerciseSet`; ordered lift
/// evidence remains in its `ComplexComponentResult` children.
nonisolated struct OlympicAttemptPrescription: Codable, Hashable {
    var technicalPurpose: OlympicTechnicalPurpose?
    var startPosition: OlympicStartPosition?
    var targetQuality: LiftQuality?

    init(
        technicalPurpose: OlympicTechnicalPurpose? = nil,
        startPosition: OlympicStartPosition? = nil,
        targetQuality: LiftQuality? = nil
    ) {
        self.technicalPurpose = technicalPurpose
        self.startPosition = startPosition
        self.targetQuality = targetQuality
    }
}

nonisolated enum OlympicTechnicalPurpose: String, Codable, CaseIterable, Hashable {
    case positionalStrength
    case turnover
    case receivingPosition
    case pullUnder
    case jerkTiming
    case competitionPractice
    case technicalAssessment

    var title: String {
        switch self {
        case .positionalStrength: "Positional strength"
        case .turnover: "Turnover"
        case .receivingPosition: "Receiving position"
        case .pullUnder: "Pull under"
        case .jerkTiming: "Jerk timing"
        case .competitionPractice: "Competition practice"
        case .technicalAssessment: "Technical assessment"
        }
    }
}

nonisolated enum OlympicStartPosition: String, Codable, CaseIterable, Hashable {
    case floor
    case belowKnee
    case knee
    case aboveKnee
    case hang
    case blocks

    var title: String {
        switch self {
        case .floor: "Floor"
        case .belowKnee: "Below knee"
        case .knee: "Knee"
        case .aboveKnee: "Above knee"
        case .hang: "Hang"
        case .blocks: "Blocks"
        }
    }
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
    /// Optional authored completion semantics. `nil` preserves the exact
    /// legacy `TrackingType` rule at execution time.
    var completionRule: MetricCompletionRule?
    /// Present only when this set is one shared Olympic attempt. Older
    /// definitions decode it as `nil` and preserve their existing behavior.
    var olympicAttempt: OlympicAttemptPrescription?
    /// New program prescriptions keep targets in this immutable definition
    /// snapshot and leave performed duration/distance/calories empty. Legacy
    /// decoded definitions default to `false` to preserve their prior active
    /// workout behavior byte-for-byte.
    var separatesPerformedEvidence: Bool
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
        completionRule: MetricCompletionRule? = nil,
        olympicAttempt: OlympicAttemptPrescription? = nil,
        separatesPerformedEvidence: Bool = true,
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
        self.completionRule = completionRule
        self.olympicAttempt = olympicAttempt
        self.separatesPerformedEvidence = separatesPerformedEvidence
        self.generatesAfterSourceCompletion = generatesAfterSourceCompletion
    }

    private enum CodingKeys: String, CodingKey {
        case id, orderIndex, role, repetitions, load, targetRPE, targetRIR
        case restSeconds, tempo, isOptional, progressionEligible, notes
        case generatesAfterSourceCompletion, velocity, completionRule, olympicAttempt
        case separatesPerformedEvidence, completionTargetMetrics
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
        completionRule = try values.decodeIfPresent(MetricCompletionRule.self, forKey: .completionRule)
        olympicAttempt = try values.decodeIfPresent(OlympicAttemptPrescription.self, forKey: .olympicAttempt)
        separatesPerformedEvidence = try values.decodeIfPresent(
            Bool.self,
            forKey: .separatesPerformedEvidence
        ) ?? false
        generatesAfterSourceCompletion = try values.decodeIfPresent(
            Bool.self,
            forKey: .generatesAfterSourceCompletion
        ) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(orderIndex, forKey: .orderIndex)
        try values.encode(role, forKey: .role)
        try values.encode(repetitions, forKey: .repetitions)
        try values.encode(load, forKey: .load)
        try values.encodeIfPresent(targetRPE, forKey: .targetRPE)
        try values.encodeIfPresent(targetRIR, forKey: .targetRIR)
        try values.encodeIfPresent(restSeconds, forKey: .restSeconds)
        try values.encodeIfPresent(tempo, forKey: .tempo)
        try values.encode(isOptional, forKey: .isOptional)
        try values.encode(progressionEligible, forKey: .progressionEligible)
        try values.encodeIfPresent(notes, forKey: .notes)
        try values.encodeIfPresent(velocity, forKey: .velocity)
        try values.encodeIfPresent(completionRule, forKey: .completionRule)
        try values.encodeIfPresent(olympicAttempt, forKey: .olympicAttempt)
        try values.encode(separatesPerformedEvidence, forKey: .separatesPerformedEvidence)
        try values.encode(prescribedCompletionMetrics, forKey: .completionTargetMetrics)
        try values.encode(generatesAfterSourceCompletion, forKey: .generatesAfterSourceCompletion)
    }

    /// Metrics with an explicit target in this set recipe. This is encoded as
    /// a small compatibility projection so the extension can resolve
    /// `.prescribedTargets` without depending on the app-only program engine.
    var prescribedCompletionMetrics: Set<TrackingMetric> {
        var metrics: Set<TrackingMetric>
        switch repetitions {
        case .fixed, .range, .amrap, .sequence:
            metrics = [.repetitions]
        case .duration:
            metrics = [.duration]
        case .distance:
            metrics = [.distance]
        case .calories:
            metrics = [.calories]
        case .open:
            metrics = []
        }
        if hasPrescribedLoadTarget {
            metrics.insert(.load)
        }
        return metrics
    }

    private var hasPrescribedLoadTarget: Bool {
        load.fixedValue != nil
            || load.percentage != nil
            || load.reference.kind != .manual
    }
}

extension ExerciseSet {
    /// The immutable effective program prescription carried by this performed
    /// row. A missing or legacy payload stays absent rather than inventing a
    /// target from performed evidence.
    var programSetPrescription: SetPrescriptionDefinition? {
        prescriptionDefinitionData.flatMap {
            try? JSONDecoder().decode(SetPrescriptionDefinition.self, from: $0)
        }
    }

    var prescribedDurationSecondsSnapshot: Double? {
        guard case .duration(let seconds) = programSetPrescription?.repetitions else { return nil }
        return seconds
    }

    var prescribedDistanceMetersSnapshot: Double? {
        guard case .distance(let meters) = programSetPrescription?.repetitions else { return nil }
        return meters
    }

    var prescribedCaloriesSnapshot: Double? {
        if let prescribedCalories { return prescribedCalories }
        guard case .calories(let calories) = programSetPrescription?.repetitions else { return nil }
        return calories
    }

    var separatesProgramPerformedEvidence: Bool {
        programSetPrescription?.separatesPerformedEvidence == true
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

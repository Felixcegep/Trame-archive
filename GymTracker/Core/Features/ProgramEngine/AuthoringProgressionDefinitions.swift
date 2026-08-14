import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated enum AuthoringRuleSelection: Codable, Hashable {
    case named(String)
    case namedMany([String])
    case unsupported

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            self = .named(name)
        } else if let names = try? container.decode([String].self) {
            self = .namedMany(names)
        } else {
            self = .unsupported
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .named(let name): try container.encode(name)
        case .namedMany(let names): try container.encode(names)
        case .unsupported: try container.encodeNil()
        }
    }
}

nonisolated struct AuthoringTriggerDefinition: Codable, Hashable {
    var type: String
    var count: Int?
    var tolerance: Double?
    var triggers: [AuthoringTriggerDefinition]?
    var stageID: String?
    var delta: Double?

    init(
        type: String,
        count: Int? = nil,
        tolerance: Double? = nil,
        triggers: [AuthoringTriggerDefinition]? = nil,
        stageID: String? = nil,
        delta: Double? = nil
    ) {
        self.type = type
        self.count = count
        self.tolerance = tolerance
        self.triggers = triggers
        self.stageID = stageID
        self.delta = delta
    }

    func expand() throws -> ProgressionTrigger {
        switch type {
        case "allRequiredSetsCompleted": return .allRequiredSetsCompleted
        case "allRequiredRepetitionsCompleted": return .allRequiredRepetitionsCompleted
        case "allSetsReachedUpperRepBound": return .allSetsReachedUpperRepBound
        case "firstSetReachedUpperRepBound": return .firstSetReachedUpperRepBound
        case "workoutCompleted": return .workoutCompleted
        case "weekCompleted": return .weekCompleted
        case "waveCompleted": return .waveCompleted
        case "blockCompleted": return .blockCompleted
        case "cycleCompleted": return .cycleCompleted
        case "failureCountReached": return .failureCountReached(count ?? 1)
        case "consecutiveMissedAttemptsReached":
            return .consecutiveMissedAttemptsReached(count ?? 3)
        case "totalRepetitionsReached": return .totalRepetitionsReached(count ?? 0)
        case "amrapResultReached": return .amrapResultReached(count ?? 0)
        case "targetRPEMatched": return .targetRPEMatched(tolerance: tolerance ?? 0)
        case "actualRPEBelowTarget": return .actualRPEBelowTarget(tolerance: tolerance ?? 0)
        case "actualRPEAboveTarget": return .actualRPEAboveTarget(tolerance: tolerance ?? 0)
        case "targetRIRMatched": return .targetRIRMatched(tolerance: Int(tolerance ?? 0))
        case "technicalQualityReached": return .technicalQualityReached
        case "atStage":
            guard let stageID else { throw ProgramLibraryImportError.unsupportedRuleConstruct("trigger.atStage.stageID") }
            return .atStage(stageID)
        case "allOf": return .allOf(try (triggers ?? []).map { try $0.expand() })
        case "anyOf": return .anyOf(try (triggers ?? []).map { try $0.expand() })
        case "velocityBelowBaseline": return .velocityBelowBaseline(delta: delta ?? 0)
        case "velocityAboveBaseline": return .velocityAboveBaseline(delta: delta ?? 0)
        case "velocityInTargetZone": return .velocityInTargetZone
        case "velocityBelowZoneCount": return .velocityBelowZoneCount(count ?? 1)
        default: throw ProgramLibraryImportError.unsupportedRuleConstruct("trigger.\(type)")
        }
    }
}

nonisolated struct AuthoringActionDefinition: Codable, Hashable {
    var type: String
    var value: Double?
    var formula: AuthoringFormulaDefinition?
    var next: String?
    var setCount: Int?
    var repetitions: Int?
    var percentage: Double?
    var advancesToNextStage: Bool
    var andChangeStage: String?

    private enum CodingKeys: String, CodingKey {
        case type, value, formula, next, setCount, repetitions, percentage, andChangeStage
    }

    init(
        type: String,
        value: Double? = nil,
        formula: AuthoringFormulaDefinition? = nil,
        next: String? = nil,
        setCount: Int? = nil,
        repetitions: Int? = nil,
        percentage: Double? = nil,
        advancesToNextStage: Bool = false,
        andChangeStage: String? = nil
    ) {
        self.type = type
        self.value = value
        self.formula = formula
        self.next = next
        self.setCount = setCount
        self.repetitions = repetitions
        self.percentage = percentage
        self.advancesToNextStage = advancesToNextStage
        self.andChangeStage = andChangeStage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
        formula = try container.decodeIfPresent(AuthoringFormulaDefinition.self, forKey: .formula)
        next = try? container.decode(String.self, forKey: .next)
        setCount = try container.decodeIfPresent(Int.self, forKey: .setCount)
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions)
        percentage = try container.decodeIfPresent(Double.self, forKey: .percentage)
        advancesToNextStage = (try? container.decode(Bool.self, forKey: .next)) ?? false
        andChangeStage = try container.decodeIfPresent(String.self, forKey: .andChangeStage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(formula, forKey: .formula)
        try container.encodeIfPresent(setCount, forKey: .setCount)
        try container.encodeIfPresent(repetitions, forKey: .repetitions)
        try container.encodeIfPresent(percentage, forKey: .percentage)
        if let next {
            try container.encode(next, forKey: .next)
        } else if advancesToNextStage {
            try container.encode(true, forKey: .next)
        }
        try container.encodeIfPresent(andChangeStage, forKey: .andChangeStage)
    }

    func expand(exposureKey: String = "") throws -> ProgressionAction {
        switch type {
        case "addLoad": return .addLoad(value ?? 0)
        case "reduceLoad": return .reduceLoad(value ?? 0)
        case "addLoadPercentage": return .addLoadPercentage(value ?? 0)
        case "reduceLoadPercentage": return .reduceLoadPercentage(value ?? 0)
        case "addRepetitions": return .addRepetitions(Int(value ?? 0))
        case "reduceRepetitions": return .reduceRepetitions(Int(value ?? 0))
        case "addSets": return .addSets(Int(value ?? 0))
        case "reduceSets": return .reduceSets(Int(value ?? 0))
        case "addDuration": return .addDuration(value ?? 0)
        case "reduceDuration": return .reduceDuration(value ?? 0)
        case "repeatPrescription": return .repeatPrescription
        case "advanceWave": return .advanceWave
        case "advanceBlock": return .advanceBlock
        case "resetFailureCount": return .resetFailureCount
        case "resetProgressionOffsets": return .resetProgressionOffsets
        case "advanceExerciseVariation": return .advanceExerciseVariation
        case "regressExerciseVariation": return .regressExerciseVariation
        case "changeStage":
            guard let stageID = next ?? andChangeStage else {
                throw ProgramLibraryImportError.unsupportedRuleConstruct("action.changeStage.stageID")
            }
            return .changeStage(stageID)
        case "updateTrainingMax":
            guard let formula else { throw ProgramLibraryImportError.unsupportedRuleConstruct("action.\(type).formula") }
            return .updateTrainingMax(try formula.expand(exposureKey: exposureKey))
        case "updateEstimatedOneRepMax":
            guard let formula else { throw ProgramLibraryImportError.unsupportedRuleConstruct("action.\(type).formula") }
            return .updateEstimatedOneRepMax(try formula.expand(exposureKey: exposureKey))
        case "updateActualOneRepMax":
            guard let formula else { throw ProgramLibraryImportError.unsupportedRuleConstruct("action.\(type).formula") }
            return .updateActualOneRepMax(try formula.expand(exposureKey: exposureKey))
        case "updateVelocityBaseline":
            guard let formula else { throw ProgramLibraryImportError.unsupportedRuleConstruct("action.\(type).formula") }
            return .updateVelocityBaseline(try formula.expand(exposureKey: exposureKey))
        case "noChange": return .noChange
        case "endActiveDailyMaximumAndGenerateBackOffs":
            return .endActiveDailyMaximumAndGenerateBackOffs(
                setCount: setCount ?? 0,
                repetitions: repetitions ?? 0,
                percentage: percentage ?? 0
            )
        default: throw ProgramLibraryImportError.unsupportedRuleConstruct("action.\(type)")
        }
    }
}

nonisolated struct AuthoringFormulaDefinition: Codable, Hashable {
    var constant: Double?
    var source: String?
    var metric: ProgressionMetric?
    var of: String?
    var op: String?
    var args: [AuthoringFormulaDefinition]?
    var min: Double?
    var max: Double?

    private enum CodingKeys: String, CodingKey {
        case constant = "const", source, metric, of, op, args, min, max
    }

    func expand(exposureKey: String) throws -> ProgressionFormula {
        let resolvedExposure = of.flatMap { $0 == "$self" ? nil : $0 } ?? exposureKey
        if let constant { return .source(.constant(constant)) }
        if let source {
            switch source {
            case "trainingMax": return .source(.trainingMax(exposureKey: resolvedExposure))
            case "estimatedOneRepMax": return .source(.estimatedOneRepMax(exposureKey: resolvedExposure))
            case "actualOneRepMax": return .source(.actualOneRepMax(exposureKey: resolvedExposure))
            case "previousOccurrence": return .source(.previousOccurrence(exposureKey: resolvedExposure))
            case "previousSuccessfulSet": return .source(.previousSuccessfulSet(exposureKey: resolvedExposure))
            case "topSet": return .source(.completedTopSet(exposureKey: resolvedExposure))
            case "dailyMaximum": return .source(.dailyMaximum(exposureKey: resolvedExposure))
            case "velocityBaseline": return .source(.velocityBaseline(exposureKey: resolvedExposure))
            default: throw ProgramLibraryImportError.unsupportedRuleConstruct("formula.source.\(source)")
            }
        }
        if let metric {
            return .source(.completedMetric(exposureKey: resolvedExposure, metric: metric))
        }
        guard let op else { throw ProgramLibraryImportError.unsupportedRuleConstruct("formula.empty") }
        if op == "clamp", let argument = args?.first, let min, let max {
            return .clamp(
                value: try argument.expand(exposureKey: exposureKey),
                minimum: min,
                maximum: max
            )
        }
        guard let args, args.count == 2 else {
            throw ProgramLibraryImportError.unsupportedRuleConstruct("formula.\(op).arguments")
        }
        let lhs = try args[0].expand(exposureKey: exposureKey)
        let rhs = try args[1].expand(exposureKey: exposureKey)
        switch op {
        case "add": return .add(lhs, rhs)
        case "subtract": return .subtract(lhs, rhs)
        case "multiply": return .multiply(lhs, rhs)
        case "divide": return .divide(lhs, rhs)
        case "min": return .minimum(lhs, rhs)
        case "max": return .maximum(lhs, rhs)
        default: throw ProgramLibraryImportError.unsupportedRuleConstruct("formula.op.\(op)")
        }
    }
}

nonisolated struct AuthoringRuleDefinition: Codable, Hashable {
    var metric: ProgressionMetric
    var trigger: AuthoringTriggerDefinition
    var success: AuthoringActionDefinition
    var failure: AuthoringActionDefinition?
    var cadence: ProgressionCadence
    var scope: ProgressionScope
    var mode: ProgressionApplicationMode
    var priority: Int?

    func expand(path: String, exposureKey: String) throws -> ProgressionRuleDefinition {
        ProgressionRuleDefinition(
            id: ProgramLibraryDeterministicID.uuid(for: path),
            metric: metric,
            trigger: try trigger.expand(),
            successAction: try success.expand(exposureKey: exposureKey),
            failureAction: try failure?.expand(exposureKey: exposureKey),
            cadence: cadence,
            scope: scope,
            priority: priority ?? 0,
            applicationMode: mode
        )
    }
}

nonisolated enum AuthoringRuleSetDefinition: Codable, Hashable {
    case rules([AuthoringRuleDefinition])
    case derived(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let rules = try? container.decode([AuthoringRuleDefinition].self) {
            self = .rules(rules)
        } else {
            self = .derived(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .rules(let rules): try container.encode(rules)
        case .derived(let expression): try container.encode(expression)
        }
    }
}

nonisolated struct AuthoringLoadDefinition: Codable, Hashable {
    var reference: LoadReferenceKind?
    var of: String?
    var fixed: Double?
    var percent: Double?
    var offset: Double?
    var percentOffset: Double?
    var min: Double?
    var max: Double?
    var round: Double?

    init(
        reference: LoadReferenceKind? = nil,
        of: String? = nil,
        fixed: Double? = nil,
        percent: Double? = nil,
        offset: Double? = nil,
        percentOffset: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        round: Double? = nil
    ) {
        self.reference = reference
        self.of = of
        self.fixed = fixed
        self.percent = percent
        self.offset = offset
        self.percentOffset = percentOffset
        self.min = min
        self.max = max
        self.round = round
    }

    func expand(exposureKey: String? = nil, mainReference: String? = nil) -> LoadPrescription {
        let kind: LoadReferenceKind
        if fixed != nil {
            kind = .fixedLoad
        } else {
            kind = reference ?? .manual
        }
        let resolvedExposure: String?
        if of == "$self" {
            resolvedExposure = exposureKey
        } else if of == "$main" {
            resolvedExposure = mainReference
        } else {
            resolvedExposure = of
        }
        return LoadPrescription(
            reference: LoadReference(kind: kind, exposureKey: resolvedExposure),
            fixedValue: fixed,
            percentage: percent,
            absoluteOffset: offset ?? 0,
            percentageOffset: percentOffset,
            minimum: min,
            maximum: max,
            rounding: round.map(LoadRoundingRule.nearestIncrement) ?? .none
        )
    }
}

nonisolated struct AuthoringSetGroupDefinition: Codable, Hashable {
    var count: Int
    var reps: Int?
    var repRange: [Int]?
    var amrap: [Int?]?
    var durationSeconds: Double?
    /// Canonical workout distance. Compact recipes never carry a display unit;
    /// authoring, compilation, active snapshots, and backup all retain metres.
    var distanceMeters: Double?
    /// Optional group-local rest overrides the exercise default. This is needed
    /// for wave prescriptions whose recovery changes while the exercise stays
    /// the same occurrence.
    var restSeconds: Int?
    var load: AuthoringLoadDefinition?
    var role: ProgramSetRole?
    var targetRPE: Double?
    var targetRIR: Int?
    var tempo: String?
    var progressionEligible: Bool?

    init(
        count: Int,
        reps: Int? = nil,
        repRange: [Int]? = nil,
        amrap: [Int?]? = nil,
        durationSeconds: Double? = nil,
        distanceMeters: Double? = nil,
        restSeconds: Int? = nil,
        load: AuthoringLoadDefinition? = nil,
        role: ProgramSetRole? = nil,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        tempo: String? = nil,
        progressionEligible: Bool? = nil
    ) {
        self.count = count
        self.reps = reps
        self.repRange = repRange
        self.amrap = amrap
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restSeconds = restSeconds
        self.load = load
        self.role = role
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.tempo = tempo
        self.progressionEligible = progressionEligible
    }

    func expand(
        path: String,
        startingAt orderIndex: Int,
        restSeconds: Int? = nil,
        exposureKey: String? = nil,
        mainReference: String? = nil
    ) throws -> [SetPrescriptionDefinition] {
        let options = [
            reps != nil,
            repRange != nil,
            amrap != nil,
            durationSeconds != nil,
            distanceMeters != nil
        ]
        guard options.filter({ $0 }).count == 1 else {
            throw ProgramLibraryImportError.invalidSetGroup(path)
        }

        let repetitionPrescription: RepPrescription
        if let reps {
            repetitionPrescription = .fixed(reps)
        } else if let repRange, repRange.count == 2 {
            repetitionPrescription = .range(minimum: repRange[0], maximum: repRange[1])
        } else if let amrap, amrap.count == 2 {
            repetitionPrescription = .amrap(minimum: amrap[0], maximum: amrap[1])
        } else if let durationSeconds {
            repetitionPrescription = .duration(seconds: durationSeconds)
        } else if let distanceMeters {
            repetitionPrescription = .distance(meters: distanceMeters)
        } else {
            throw ProgramLibraryImportError.invalidSetGroup(path)
        }

        return (0..<max(0, count)).map { offset in
            let setPath = "\(path)/s\(offset)"
            return SetPrescriptionDefinition(
                id: ProgramLibraryDeterministicID.uuid(for: setPath),
                orderIndex: orderIndex + offset,
                role: role ?? (amrap != nil ? .amrap : .working),
                repetitions: repetitionPrescription,
                load: load?.expand(exposureKey: exposureKey, mainReference: mainReference) ?? LoadPrescription(),
                targetRPE: targetRPE,
                targetRIR: targetRIR,
                restSeconds: self.restSeconds ?? restSeconds,
                tempo: tempo,
                progressionEligible: progressionEligible ?? true
            )
        }
    }
}


#endif

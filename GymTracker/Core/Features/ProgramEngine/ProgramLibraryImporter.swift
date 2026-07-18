import Foundation
import SwiftData
import CryptoKit

#if !GYMTRACKER_EXTENSION

nonisolated enum ProgramLibraryImportError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decodingFailed
    case invalidSetGroup(String)
    case missingExercise(String)
    case missingRuleSet(String)
    case unsupportedRuleConstruct(String)
    case catalogFailures([String])

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            return "Program library schema version \(found) is newer than supported version \(supported)."
        case .decodingFailed:
            return "The program library could not be decoded."
        case .invalidSetGroup(let path):
            return "The set group at \(path) must define exactly one repetition prescription."
        case .missingExercise(let name):
            return "The program library references missing exercise \(name)."
        case .missingRuleSet(let name):
            return "The program library references missing rule set \(name)."
        case .unsupportedRuleConstruct(let construct):
            return "The program rule construct \(construct) is not supported by this engine."
        case .catalogFailures(let keys):
            return "The program catalog contains invalid definitions: \(keys.joined(separator: ", "))."
        }
    }
}

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
    var advancesToNextStage: Bool
    var andChangeStage: String?

    private enum CodingKeys: String, CodingKey {
        case type, value, formula, next, andChangeStage
    }

    init(
        type: String,
        value: Double? = nil,
        formula: AuthoringFormulaDefinition? = nil,
        next: String? = nil,
        advancesToNextStage: Bool = false,
        andChangeStage: String? = nil
    ) {
        self.type = type
        self.value = value
        self.formula = formula
        self.next = next
        self.advancesToNextStage = advancesToNextStage
        self.andChangeStage = andChangeStage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
        formula = try container.decodeIfPresent(AuthoringFormulaDefinition.self, forKey: .formula)
        next = try? container.decode(String.self, forKey: .next)
        advancesToNextStage = (try? container.decode(Bool.self, forKey: .next)) ?? false
        andChangeStage = try container.decodeIfPresent(String.self, forKey: .andChangeStage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(formula, forKey: .formula)
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
        let resolvedExposure = of == "$self" || of == nil ? exposureKey : of!
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
        let options = [reps != nil, repRange != nil, amrap != nil, durationSeconds != nil]
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
                restSeconds: restSeconds,
                tempo: tempo,
                progressionEligible: progressionEligible ?? true
            )
        }
    }
}

nonisolated struct AuthoringWarmupStep: Codable, Hashable {
    var percent: Double
    var reps: Int
    var restSeconds: Int?
}

nonisolated struct AuthoringExerciseDefinition: Codable, Hashable {
    var exercise: String
    var exposureKey: String
    var optional: Bool?
    var restSeconds: Int?
    var setGroups: [AuthoringSetGroupDefinition]?
    var extraSetGroups: [AuthoringSetGroupDefinition]?
    var sets: [AuthoringDirectSetDefinition]?
    var warmupScheme: [AuthoringWarmupStep]?
    var rules: AuthoringRuleSelection?
    var stages: String?
    var initialStage: String?
    var variationLadder: [String]?
    var waves: String?
    var mainReference: String?
}

nonisolated struct AuthoringDirectSetDefinition: Codable, Hashable {
    struct Velocity: Codable, Hashable {
        var zone: [Double]?
        var lossStopPercent: Double?
        var probe: Bool?

        var expanded: SetPrescriptionDefinition.VelocityPrescription {
            .init(
                targetMinimum: zone?.first,
                targetMaximum: zone.flatMap { $0.count > 1 ? $0[1] : nil },
                lossStopPercent: lossStopPercent,
                isProbe: probe ?? false
            )
        }
    }
    var reps: Int?
    var repRange: [Int]?
    var amrap: [Int?]?
    var durationSeconds: Double?
    var load: AuthoringLoadDefinition?
    var role: ProgramSetRole?
    var targetRPE: Double?
    var targetRIR: Int?
    var restSeconds: Int?
    var tempo: String?
    var progressionEligible: Bool?
    var optional: Bool?
    var deferred: Bool?
    var velocity: Velocity?

    func expand(path: String, orderIndex: Int, defaultRestSeconds: Int?, exposureKey: String) throws -> SetPrescriptionDefinition {
        let group = AuthoringSetGroupDefinition(
            count: 1,
            reps: reps,
            repRange: repRange,
            amrap: amrap,
            durationSeconds: durationSeconds,
            load: load,
            role: role,
            targetRPE: targetRPE,
            targetRIR: targetRIR,
            tempo: tempo,
            progressionEligible: progressionEligible
        )
        var result = try group.expand(
            path: path,
            startingAt: orderIndex,
            restSeconds: restSeconds ?? defaultRestSeconds,
            exposureKey: exposureKey
        )[0]
        result.isOptional = optional ?? false
        result.generatesAfterSourceCompletion = deferred ?? false
        result.velocity = velocity?.expanded
        return result
    }
}

nonisolated struct AuthoringStageDefinition: Codable, Hashable {
    var stageID: String
    var name: String?
    var carriesLoad: Bool?
    var setGroups: [AuthoringSetGroupDefinition]
}

nonisolated struct AuthoringWaveDefinition: Codable, Hashable {
    var name: String?
    var setGroups: [AuthoringSetGroupDefinition]
}

nonisolated struct AuthoringWorkoutDefinition: Codable, Hashable {
    var name: String
    var dayOffset: Int
    var role: String?
    var optional: Bool?
    var exercises: [AuthoringExerciseDefinition]
}

nonisolated struct AuthoringWeekDefinition: Codable, Hashable {
    var weekIndex: Int
    var name: String?
    var repeatCount: Int
    var workouts: [AuthoringWorkoutDefinition]

    private enum CodingKeys: String, CodingKey {
        case weekIndex, name, repeatCount = "repeat", workouts
    }

    init(weekIndex: Int, name: String? = nil, repeatCount: Int = 1, workouts: [AuthoringWorkoutDefinition]) {
        self.weekIndex = weekIndex
        self.name = name
        self.repeatCount = repeatCount
        self.workouts = workouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekIndex = try container.decode(Int.self, forKey: .weekIndex)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        repeatCount = max(1, try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1)
        workouts = try container.decode([AuthoringWorkoutDefinition].self, forKey: .workouts)
    }
}

nonisolated struct AuthoringBlockDefinition: Codable, Hashable {
    var name: String
    var phaseType: PlanPhaseType
    var repeatCount: Int
    var deloadVolumeReductionPercent: Int?
    var deloadIntensityReductionPercent: Int?
    var weeks: [AuthoringWeekDefinition]

    private enum CodingKeys: String, CodingKey {
        case name, phaseType, repeatCount = "repeat"
        case deloadVolumeReductionPercent, deloadIntensityReductionPercent, weeks
    }

    init(
        name: String,
        phaseType: PlanPhaseType,
        repeatCount: Int = 1,
        deloadVolumeReductionPercent: Int? = nil,
        deloadIntensityReductionPercent: Int? = nil,
        weeks: [AuthoringWeekDefinition]
    ) {
        self.name = name
        self.phaseType = phaseType
        self.repeatCount = repeatCount
        self.deloadVolumeReductionPercent = deloadVolumeReductionPercent
        self.deloadIntensityReductionPercent = deloadIntensityReductionPercent
        self.weeks = weeks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        phaseType = try container.decode(PlanPhaseType.self, forKey: .phaseType)
        repeatCount = max(1, try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1)
        deloadVolumeReductionPercent = try container.decodeIfPresent(Int.self, forKey: .deloadVolumeReductionPercent)
        deloadIntensityReductionPercent = try container.decodeIfPresent(Int.self, forKey: .deloadIntensityReductionPercent)
        weeks = try container.decode([AuthoringWeekDefinition].self, forKey: .weeks)
    }
}

nonisolated struct AuthoringProgramDefinition: Codable, Hashable {
    var programKey: String
    var name: String
    var description: String?
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var durationWeeks: Int
    var supportedDaysPerWeek: [Int]
    var scheduleMode: PlanScheduleMode
    var scheduleIntervalDays: Int?
    var prerequisites: [String]?
    var warnings: [String]?
    var isExperimental: Bool?
    var rulesLibrary: [String: AuthoringRuleSetDefinition]?
    var stageTemplates: [String: [AuthoringStageDefinition]]?
    var waveTemplates: [String: [AuthoringWaveDefinition]]?
    var blocks: [AuthoringBlockDefinition]

    func expand(exerciseIDsByName: [String: UUID]) throws -> ProgramDefinitionPayload {
        var expandedBlocks: [ProgramBlockDefinition] = []
        var nextWeekIndex = 0

        for (sourceBlockIndex, sourceBlock) in blocks.enumerated() {
            for blockRepeatIndex in 0..<sourceBlock.repeatCount {
                let blockPath = "\(programKey)/b\(sourceBlockIndex)/r\(blockRepeatIndex)"
                var expandedWeeks: [ProgramWeekDefinition] = []
                for (sourceWeekIndex, sourceWeek) in sourceBlock.weeks.enumerated() {
                    for weekRepeatIndex in 0..<sourceWeek.repeatCount {
                        let weekPath = "\(blockPath)/w\(sourceWeekIndex)/r\(weekRepeatIndex)"
                        let workouts = try sourceWeek.workouts.enumerated().map { workoutIndex, workout in
                            let workoutPath = "\(weekPath)/wk\(workoutIndex)"
                            let exercises = try workout.exercises.enumerated().map { exerciseIndex, exercise in
                                guard let exerciseID = exerciseIDsByName[exercise.exercise] else {
                                    throw ProgramLibraryImportError.missingExercise(exercise.exercise)
                                }
                                let exercisePath = "\(workoutPath)/e\(exerciseIndex)"
                                var sets: [SetPrescriptionDefinition] = []
                                for (groupIndex, group) in (exercise.setGroups ?? []).enumerated() {
                                    sets += try group.expand(
                                        path: "\(exercisePath)/g\(groupIndex)",
                                        startingAt: sets.count,
                                        restSeconds: exercise.restSeconds,
                                        exposureKey: exercise.exposureKey,
                                        mainReference: exercise.mainReference
                                    )
                                }
                                for (setIndex, set) in (exercise.sets ?? []).enumerated() {
                                    sets.append(try set.expand(
                                        path: "\(exercisePath)/direct/\(setIndex)",
                                        orderIndex: sets.count,
                                        defaultRestSeconds: exercise.restSeconds,
                                        exposureKey: exercise.exposureKey
                                    ))
                                }
                                for (groupIndex, group) in (exercise.extraSetGroups ?? []).enumerated() {
                                    sets += try group.expand(
                                        path: "\(exercisePath)/extra/\(groupIndex)",
                                        startingAt: sets.count,
                                        restSeconds: exercise.restSeconds,
                                        exposureKey: exercise.exposureKey
                                    )
                                }
                                let warmup = exercise.warmupScheme.map { steps in
                                    WarmupSchemeDefinition(steps: steps.enumerated().map { stepIndex, step in
                                        WarmupStepDefinition(
                                            id: ProgramLibraryDeterministicID.uuid(for: "\(exercisePath)/warmup/\(stepIndex)"),
                                            percentage: step.percent,
                                            repetitions: step.reps,
                                            restSeconds: step.restSeconds
                                        )
                                    })
                                }
                                let progressionRules: [ProgressionRuleDefinition]
                                let stageIDs = exercise.stages
                                    .flatMap { stageTemplates?[$0]?.map(\.stageID) } ?? []
                                switch exercise.rules {
                                case .none:
                                    progressionRules = []
                                case .named(let ruleSetName):
                                    guard let ruleSet = rulesLibrary?[ruleSetName] else {
                                        throw ProgramLibraryImportError.missingRuleSet(ruleSetName)
                                    }
                                    let authoringRules = try resolvedRules(
                                        ruleSet,
                                        named: ruleSetName,
                                        library: rulesLibrary ?? [:]
                                    )
                                    progressionRules = try authoringRules.enumerated().flatMap { ruleIndex, rule in
                                        try materializeRule(
                                            rule,
                                            path: "\(exercisePath)/rule/\(ruleIndex)",
                                            exposureKey: exercise.exposureKey,
                                            stageIDs: stageIDs
                                        )
                                    }
                                case .namedMany(let ruleSetNames):
                                    progressionRules = try ruleSetNames.enumerated().flatMap { selectionIndex, ruleSetName in
                                        guard let ruleSet = rulesLibrary?[ruleSetName] else {
                                            throw ProgramLibraryImportError.missingRuleSet(ruleSetName)
                                        }
                                        let authoringRules = try resolvedRules(
                                            ruleSet,
                                            named: ruleSetName,
                                            library: rulesLibrary ?? [:]
                                        )
                                        return try authoringRules.enumerated().flatMap { ruleIndex, rule in
                                            try materializeRule(
                                                rule,
                                                path: "\(exercisePath)/rule/\(selectionIndex)/\(ruleIndex)",
                                                exposureKey: exercise.exposureKey,
                                                stageIDs: stageIDs
                                            )
                                        }
                                    }
                                case .unsupported:
                                    throw ProgramLibraryImportError.unsupportedRuleConstruct("exercise.rules")
                                }
                                let stages: [ProgramStageDefinition]
                                if let stageTemplateName = exercise.stages {
                                    guard let authoringStages = stageTemplates?[stageTemplateName] else {
                                        throw ProgramLibraryImportError.unsupportedRuleConstruct("stageTemplate.\(stageTemplateName)")
                                    }
                                    stages = try authoringStages.enumerated().map { stageIndex, stage in
                                        let stagePath = "\(exercisePath)/stage/\(stageIndex)"
                                        var stageSets: [SetPrescriptionDefinition] = []
                                        for (groupIndex, group) in stage.setGroups.enumerated() {
                                            stageSets += try group.expand(
                                                path: "\(stagePath)/g\(groupIndex)",
                                                startingAt: stageSets.count,
                                                restSeconds: exercise.restSeconds,
                                                exposureKey: exercise.exposureKey,
                                                mainReference: exercise.mainReference
                                            )
                                        }
                                        return ProgramStageDefinition(
                                            id: ProgramLibraryDeterministicID.uuid(for: stagePath),
                                            stageID: stage.stageID,
                                            name: stage.name,
                                            plannedSets: stageSets,
                                            carriesLoad: stage.carriesLoad ?? true
                                        )
                                    }
                                } else {
                                    stages = []
                                }
                                let variationExerciseIDs = try exercise.variationLadder?.map { variationName in
                                    guard let variationID = exerciseIDsByName[variationName] else {
                                        throw ProgramLibraryImportError.missingExercise(variationName)
                                    }
                                    return variationID
                                }
                                let waves: [ProgramWaveDefinition]
                                if let waveTemplateName = exercise.waves {
                                    guard let authoringWaves = waveTemplates?[waveTemplateName] else {
                                        throw ProgramLibraryImportError.unsupportedRuleConstruct("waveTemplate.\(waveTemplateName)")
                                    }
                                    waves = try authoringWaves.enumerated().map { waveIndex, wave in
                                        let wavePath = "\(exercisePath)/wave/\(waveIndex)"
                                        var waveSets: [SetPrescriptionDefinition] = []
                                        for (groupIndex, group) in wave.setGroups.enumerated() {
                                            waveSets += try group.expand(
                                                path: "\(wavePath)/g\(groupIndex)",
                                                startingAt: waveSets.count,
                                                restSeconds: exercise.restSeconds,
                                                exposureKey: exercise.exposureKey,
                                                mainReference: exercise.mainReference
                                            )
                                        }
                                        return ProgramWaveDefinition(
                                            id: ProgramLibraryDeterministicID.uuid(for: wavePath),
                                            orderIndex: waveIndex,
                                            name: wave.name,
                                            plannedSets: waveSets
                                        )
                                    }
                                } else {
                                    waves = []
                                }
                                return ProgramExerciseDefinition(
                                    id: ProgramLibraryDeterministicID.uuid(for: exercisePath),
                                    exerciseID: exerciseID,
                                    exposureKey: exercise.exposureKey,
                                    orderIndex: exerciseIndex,
                                    isOptional: exercise.optional ?? false,
                                    plannedSets: sets,
                                    waves: waves,
                                    stages: stages,
                                    initialStageID: exercise.initialStage,
                                    progressionRules: progressionRules,
                                    variationExerciseIDs: variationExerciseIDs,
                                    warmupScheme: warmup
                                )
                            }
                            return ProgramWorkoutDefinition(
                                id: ProgramLibraryDeterministicID.uuid(for: workoutPath),
                                orderIndex: workoutIndex,
                                name: workout.name,
                                dayOffset: workout.dayOffset,
                                role: workout.role ?? "strength",
                                isOptional: workout.optional ?? false,
                                plannedExercises: exercises
                            )
                        }
                        expandedWeeks.append(ProgramWeekDefinition(
                            id: ProgramLibraryDeterministicID.uuid(for: weekPath),
                            weekIndex: nextWeekIndex,
                            name: sourceWeek.name,
                            workouts: workouts
                        ))
                        nextWeekIndex += 1
                    }
                }
                expandedBlocks.append(ProgramBlockDefinition(
                    id: ProgramLibraryDeterministicID.uuid(for: blockPath),
                    orderIndex: expandedBlocks.count,
                    name: sourceBlock.name,
                    phaseType: sourceBlock.phaseType,
                    deloadVolumeReductionPercent: sourceBlock.deloadVolumeReductionPercent,
                    deloadIntensityReductionPercent: sourceBlock.deloadIntensityReductionPercent,
                    weeks: expandedWeeks
                ))
            }
        }

        let allExercises = expandedBlocks.flatMap(\.weeks).flatMap(\.workouts).flatMap(\.plannedExercises)
        var requiredCapabilities: Set<String> = []
        if allExercises.contains(where: { !$0.stages.isEmpty }) { requiredCapabilities.insert(EngineCapabilities.stages) }
        if allExercises.contains(where: { !$0.waves.isEmpty }) { requiredCapabilities.insert(EngineCapabilities.waves) }
        if allExercises.contains(where: { !($0.variationExerciseIDs ?? []).isEmpty }) {
            requiredCapabilities.insert(EngineCapabilities.variationLadders)
        }
        if allExercises.flatMap({ $0.plannedSets + $0.waves.flatMap(\.plannedSets) + $0.stages.flatMap(\.plannedSets) })
            .contains(where: { if case .amrap = $0.repetitions { return true }; return false }) {
            requiredCapabilities.insert(EngineCapabilities.amrapRepetitions)
        }

        return ProgramDefinitionPayload(
            id: ProgramLibraryDeterministicID.uuid(for: programKey),
            programKey: programKey,
            name: name,
            description: description,
            goal: goal,
            experienceLevel: experienceLevel,
            durationWeeks: durationWeeks,
            supportedDaysPerWeek: supportedDaysPerWeek,
            scheduleMode: scheduleMode,
            scheduleIntervalDays: scheduleIntervalDays ?? 1,
            prerequisites: prerequisites ?? [],
            warnings: warnings ?? [],
            isExperimental: isExperimental ?? false,
            requiredCapabilities: requiredCapabilities.sorted(),
            blocks: expandedBlocks
        )
    }

    private func resolvedRules(
        _ ruleSet: AuthoringRuleSetDefinition,
        named name: String,
        library: [String: AuthoringRuleSetDefinition],
        visited: Set<String> = []
    ) throws -> [AuthoringRuleDefinition] {
        guard !visited.contains(name) else {
            throw ProgramLibraryImportError.unsupportedRuleConstruct("ruleAliasCycle.\(name)")
        }
        switch ruleSet {
        case .rules(let rules):
            return rules
        case .derived(let expression):
            let marker = " with addLoad "
            guard let range = expression.range(of: marker),
                  let amount = Double(expression[range.upperBound...]) else {
                throw ProgramLibraryImportError.unsupportedRuleConstruct("ruleAlias.\(expression)")
            }
            let baseName = String(expression[..<range.lowerBound])
            guard let base = library[baseName] else {
                throw ProgramLibraryImportError.missingRuleSet(baseName)
            }
            var rules = try resolvedRules(
                base,
                named: baseName,
                library: library,
                visited: visited.union([name])
            )
            guard let index = rules.firstIndex(where: { $0.success.type == "addLoad" }) else {
                throw ProgramLibraryImportError.unsupportedRuleConstruct("ruleAlias.\(expression)")
            }
            rules[index].success.value = amount
            return rules
        }
    }

    private func materializeRule(
        _ rule: AuthoringRuleDefinition,
        path: String,
        exposureKey: String,
        stageIDs: [String]
    ) throws -> [ProgressionRuleDefinition] {
        guard rule.success.advancesToNextStage else {
            return [try rule.expand(path: path, exposureKey: exposureKey)]
        }
        guard stageIDs.count > 1 else {
            throw ProgramLibraryImportError.unsupportedRuleConstruct("action.changeStage.next")
        }
        return try zip(stageIDs, stageIDs.dropFirst()).enumerated().map { index, transition in
            var explicit = rule
            explicit.trigger = .init(
                type: "allOf",
                triggers: [rule.trigger, .init(type: "atStage", stageID: transition.0)]
            )
            explicit.success.next = transition.1
            explicit.success.advancesToNextStage = false
            return try explicit.expand(
                path: "\(path)/stage/\(index)",
                exposureKey: exposureKey
            )
        }
    }
}

nonisolated enum ProgramLibraryDeterministicID {
    static func uuid(for path: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(path.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

nonisolated struct ProgramLibraryDocument: Codable, Hashable {
    var schemaVersion: Int
    var libraryVersion: Int
    var programDefinitions: [ProgramDefinitionPayload]

    init(
        schemaVersion: Int = ProgramLibraryImporter.supportedSchemaVersion,
        libraryVersion: Int,
        programDefinitions: [ProgramDefinitionPayload]
    ) {
        self.schemaVersion = schemaVersion
        self.libraryVersion = libraryVersion
        self.programDefinitions = programDefinitions
    }
}

nonisolated struct ProgramLibraryImportResult: Equatable {
    var importedProgramKeys: [String]
    var skippedPrograms: [SkippedProgram]

    nonisolated struct SkippedProgram: Equatable {
        var programKey: String
        var missingCapabilities: Set<String>
    }
}

nonisolated struct AuthoringCatalogDecodeResult {
    var schemaVersion: Int
    var definitions: [AuthoringProgramDefinition]
    var failures: [Failure]

    nonisolated struct Failure: Equatable {
        var programKey: String
        var message: String
    }
}

nonisolated enum AuthoringProgramCatalogDecoder {
    static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> AuthoringCatalogDecodeResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemaVersion = root["schemaVersion"] as? Int,
              let programs = root["programDefinitions"] as? [[String: Any]] else {
            throw ProgramLibraryImportError.decodingFailed
        }
        guard schemaVersion <= ProgramLibraryImporter.supportedSchemaVersion else {
            throw ProgramLibraryImportError.unsupportedSchemaVersion(
                found: schemaVersion,
                supported: ProgramLibraryImporter.supportedSchemaVersion
            )
        }

        var definitions: [AuthoringProgramDefinition] = []
        var failures: [AuthoringCatalogDecodeResult.Failure] = []
        for program in programs {
            let programKey = program["programKey"] as? String ?? "<missing-program-key>"
            do {
                let programData = try JSONSerialization.data(withJSONObject: program)
                definitions.append(try decoder.decode(AuthoringProgramDefinition.self, from: programData))
            } catch {
                failures.append(.init(programKey: programKey, message: String(describing: error)))
            }
        }
        return AuthoringCatalogDecodeResult(
            schemaVersion: schemaVersion,
            definitions: definitions,
            failures: failures
        )
    }

    static func bundledData(bundle: Bundle = .main) throws -> Data {
        guard let url = bundle.url(forResource: "ProgramLibrary", withExtension: "json") else {
            throw ProgramLibraryImportError.decodingFailed
        }
        return try Data(contentsOf: url)
    }
}

enum ProgramLibraryImporter {
    nonisolated static let supportedSchemaVersion = 1

    nonisolated static func decode(
        _ data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> ProgramLibraryDocument {
        guard let document = try? decoder.decode(ProgramLibraryDocument.self, from: data) else {
            throw ProgramLibraryImportError.decodingFailed
        }
        guard document.schemaVersion <= supportedSchemaVersion else {
            throw ProgramLibraryImportError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }
        return document
    }

    @MainActor
    static func importDocument(
        _ document: ProgramLibraryDocument,
        into context: ModelContext
    ) throws -> ProgramLibraryImportResult {
        guard document.schemaVersion <= supportedSchemaVersion else {
            throw ProgramLibraryImportError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }

        var importedProgramKeys: [String] = []
        var skippedPrograms: [ProgramLibraryImportResult.SkippedProgram] = []

        for payload in document.programDefinitions {
            let missingCapabilities = EngineCapabilities.missing(from: payload.requiredCapabilities)
            guard missingCapabilities.isEmpty else {
                skippedPrograms.append(.init(
                    programKey: payload.programKey,
                    missingCapabilities: missingCapabilities
                ))
                continue
            }

            _ = try ProgramDefinitionRepository.save(payload, isBuiltIn: true, in: context)
            importedProgramKeys.append(payload.programKey)
        }

        try context.save()
        return ProgramLibraryImportResult(
            importedProgramKeys: importedProgramKeys,
            skippedPrograms: skippedPrograms
        )
    }

    @MainActor
    static func importData(
        _ data: Data,
        into context: ModelContext,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> ProgramLibraryImportResult {
        try importDocument(decode(data, decoder: decoder), into: context)
    }
}

@MainActor
enum ProgramLibrarySeedData {
    static func seedBundledCatalog(in context: ModelContext, bundle: Bundle = .main) throws -> ProgramLibraryImportResult {
        try seed(AuthoringProgramCatalogDecoder.bundledData(bundle: bundle), in: context)
    }

    static func seed(_ data: Data, in context: ModelContext) throws -> ProgramLibraryImportResult {
        let catalog = try AuthoringProgramCatalogDecoder.decode(data)
        guard catalog.failures.isEmpty else {
            for failure in catalog.failures {
                print("Program catalog decode failed for \(failure.programKey): \(failure.message)")
            }
            throw ProgramLibraryImportError.catalogFailures(catalog.failures.map(\.programKey))
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exerciseIDsByName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0.id) })
        let payloads = try catalog.definitions.map { try $0.expand(exerciseIDsByName: exerciseIDsByName) }
        for payload in payloads {
            let issues = ProgramDefinitionValidator.validate(payload, isBuiltIn: true)
            guard issues.isEmpty else {
                throw ProgramDefinitionStoreError.invalid(issues)
            }
        }
        return try ProgramLibraryImporter.importDocument(
            ProgramLibraryDocument(libraryVersion: 1, programDefinitions: payloads),
            into: context
        )
    }
}

#endif

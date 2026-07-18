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
        }
    }
}

nonisolated enum AuthoringRuleSelection: Codable, Hashable {
    case named(String)
    case unsupported

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            self = .named(name)
        } else {
            self = .unsupported
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .named(let name): try container.encode(name)
        case .unsupported: try container.encodeNil()
        }
    }
}

nonisolated struct AuthoringTriggerDefinition: Codable, Hashable {
    var type: String
    var count: Int?
    var tolerance: Double?
    var triggers: [AuthoringTriggerDefinition]?

    init(
        type: String,
        count: Int? = nil,
        tolerance: Double? = nil,
        triggers: [AuthoringTriggerDefinition]? = nil
    ) {
        self.type = type
        self.count = count
        self.tolerance = tolerance
        self.triggers = triggers
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
        case "allOf": return .allOf(try (triggers ?? []).map { try $0.expand() })
        case "anyOf": return .anyOf(try (triggers ?? []).map { try $0.expand() })
        default: throw ProgramLibraryImportError.unsupportedRuleConstruct("trigger.\(type)")
        }
    }
}

nonisolated struct AuthoringActionDefinition: Codable, Hashable {
    var type: String
    var value: Double?

    init(type: String, value: Double? = nil) {
        self.type = type
        self.value = value
    }

    func expand() throws -> ProgressionAction {
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
        case "noChange": return .noChange
        default: throw ProgramLibraryImportError.unsupportedRuleConstruct("action.\(type)")
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

    func expand(path: String) throws -> ProgressionRuleDefinition {
        ProgressionRuleDefinition(
            id: ProgramLibraryDeterministicID.uuid(for: path),
            metric: metric,
            trigger: try trigger.expand(),
            successAction: try success.expand(),
            failureAction: try failure?.expand(),
            cadence: cadence,
            scope: scope,
            priority: priority ?? 0,
            applicationMode: mode
        )
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

    func expand() -> LoadPrescription {
        let kind: LoadReferenceKind
        if fixed != nil {
            kind = .fixedLoad
        } else {
            kind = reference ?? .manual
        }
        return LoadPrescription(
            reference: LoadReference(kind: kind, exposureKey: of),
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
        restSeconds: Int? = nil
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
                load: load?.expand() ?? LoadPrescription(),
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
    var setGroups: [AuthoringSetGroupDefinition]
    var warmupScheme: [AuthoringWarmupStep]?
    var rules: AuthoringRuleSelection?
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
    var rulesLibrary: [String: [AuthoringRuleDefinition]]?
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
                                for (groupIndex, group) in exercise.setGroups.enumerated() {
                                    sets += try group.expand(
                                        path: "\(exercisePath)/g\(groupIndex)",
                                        startingAt: sets.count,
                                        restSeconds: exercise.restSeconds
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
                                switch exercise.rules {
                                case .none:
                                    progressionRules = []
                                case .named(let ruleSetName):
                                    guard let authoringRules = rulesLibrary?[ruleSetName] else {
                                        throw ProgramLibraryImportError.missingRuleSet(ruleSetName)
                                    }
                                    progressionRules = try authoringRules.enumerated().map { ruleIndex, rule in
                                        try rule.expand(path: "\(exercisePath)/rule/\(ruleIndex)")
                                    }
                                case .unsupported:
                                    throw ProgramLibraryImportError.unsupportedRuleConstruct("exercise.rules")
                                }
                                return ProgramExerciseDefinition(
                                    id: ProgramLibraryDeterministicID.uuid(for: exercisePath),
                                    exerciseID: exerciseID,
                                    exposureKey: exercise.exposureKey,
                                    orderIndex: exerciseIndex,
                                    isOptional: exercise.optional ?? false,
                                    plannedSets: sets,
                                    progressionRules: progressionRules,
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
            blocks: expandedBlocks
        )
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

#endif

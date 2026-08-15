import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

nonisolated struct AuthoringWarmupStep: Codable, Hashable {
    var percent: Double
    var reps: Int
    var restSeconds: Int?
}

nonisolated struct AuthoringExerciseDefinition: Codable, Hashable {
    var exercise: String
    var exposureKey: String
    var role: ExerciseRole?
    var optional: Bool?
    var executionBlockKey: String?
    var executionBlockComponentOrder: Int?
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

/// Compact JSON authoring shape for the existing within-workout execution
/// block domain. All fields use the same typed enums and units as the runtime;
/// unsupported nested blocks cannot be expressed by this graph.
nonisolated struct AuthoringExecutionBlockDefinition: Codable, Hashable {
    var blockKey: String
    var name: String?
    var kind: ExerciseBlockKind
    var targetRounds: Int?
    var sharedLoad: Bool?
    var restSeconds: Int?
    var clockMode: BlockClockMode?
    var prescribedDurationSeconds: Int?
    var timeCapSeconds: Int?
    var intervalSeconds: Int?
    var scoreKind: BlockScoreKind?
    var repetitionScheme: BlockRepetitionScheme?
    var repetitionStart: Int?
    var repetitionEnd: Int?
    var repetitionStep: Int?
}

nonisolated struct AuthoringDirectSetDefinition: Codable, Hashable {
    struct ComplexComponent: Codable, Hashable {
        var exercise: String
        var reps: Int
    }

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
    struct OlympicAttempt: Codable, Hashable {
        var technicalPurpose: OlympicTechnicalPurpose?
        var startPosition: OlympicStartPosition?
        var targetQuality: LiftQuality?

        var expanded: OlympicAttemptPrescription {
            .init(
                technicalPurpose: technicalPurpose,
                startPosition: startPosition,
                targetQuality: targetQuality
            )
        }
    }
    /// Repeats this complete parent prescription, including ordered complex
    /// components and Olympic-attempt metadata. Each expansion receives its
    /// own deterministic set identity and remains one shared-load attempt.
    var count: Int?
    var reps: Int?
    var repRange: [Int]?
    var amrap: [Int?]?
    var durationSeconds: Double?
    var distanceMeters: Double?
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
    var complex: [ComplexComponent]?
    var olympicAttempt: OlympicAttempt?

    func expand(
        path: String,
        orderIndex: Int,
        defaultRestSeconds: Int?,
        exposureKey: String,
        exerciseIDsByName: [String: UUID]
    ) throws -> SetPrescriptionDefinition {
        let group = AuthoringSetGroupDefinition(
            count: 1,
            reps: reps ?? ((complex != nil || olympicAttempt != nil) ? 1 : nil),
            repRange: repRange,
            amrap: amrap,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
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
        if let complex {
            guard !complex.isEmpty else {
                throw ProgramLibraryImportError.invalidSetGroup("\(path)/complex")
            }
            result.repetitions = try .sequence(complex.enumerated().map { componentIndex, component in
                guard component.reps > 0, let exerciseID = exerciseIDsByName[component.exercise] else {
                    throw ProgramLibraryImportError.missingExercise(component.exercise)
                }
                return RepComponent(
                    exerciseID: exerciseID,
                    repetitions: component.reps,
                    exerciseNameSnapshot: component.exercise
                )
            })
        }
        result.olympicAttempt = olympicAttempt?.expanded
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

nonisolated struct AuthoringCompletionPolicyDefinition: Codable, Hashable {
    var type: String
    var carryState: Bool?

    func expand() throws -> CompletionPolicy {
        switch type {
        case "end": return .end
        case "offerRestart": return .offerRestart(carryState: carryState ?? false)
        case "offerTestDay": return .offerTestDay
        default: throw ProgramLibraryImportError.unsupportedRuleConstruct("completionPolicy.\(type)")
        }
    }
}

nonisolated struct AuthoringWorkoutDefinition: Codable, Hashable {
    var name: String
    var dayOffset: Int
    var role: String?
    var optional: Bool?
    var executionBlocks: [AuthoringExecutionBlockDefinition]?
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
    var requiredEquipment: [EquipmentType]?
    var prerequisites: [String]?
    var warnings: [String]?
    var isExperimental: Bool?
    var intakeInputs: [ProgramIntakeInput]?
    var missedWorkoutPolicy: MissedWorkoutPolicy?
    var completionPolicy: AuthoringCompletionPolicyDefinition?
    var requiredCapabilities: [String]?
    var provenance: ProgramProvenance?
    var sourceReferences: [ProgramSourceReference]?
    var discoveryMetadata: ProgramDiscoveryMetadata?
    var supportedDisciplineIDs: [String]?
    var focusAreaApplicability: FocusAreaApplicability?
    var focusAreaIDs: [String]?
    var estimatedSessionMinutesMinimum: Int?
    var estimatedSessionMinutesMaximum: Int?
    var competitionDisciplineID: String?
    var optionalEquipmentCapabilityIDs: [String]?
    var equipmentRequirement: ProgramEquipmentRequirement?
    var displayName: String?
    var disclaimer: String?
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
                            let executionBlocks = (workout.executionBlocks ?? []).enumerated().map { blockIndex, block in
                                ProgramExecutionBlockDefinition(
                                    id: ProgramLibraryDeterministicID.uuid(for: "\(workoutPath)/executionBlock/\(blockIndex)"),
                                    blockKey: block.blockKey,
                                    orderIndex: blockIndex,
                                    name: block.name,
                                    kind: block.kind,
                                    targetRounds: block.targetRounds,
                                    isSharedLoad: block.sharedLoad ?? false,
                                    restSeconds: block.restSeconds,
                                    clockMode: block.clockMode ?? .none,
                                    prescribedDurationSeconds: block.prescribedDurationSeconds,
                                    timeCapSeconds: block.timeCapSeconds,
                                    intervalSeconds: block.intervalSeconds,
                                    scoreKind: block.scoreKind ?? .none,
                                    repetitionScheme: block.repetitionScheme ?? .fixed,
                                    repetitionStart: block.repetitionStart,
                                    repetitionEnd: block.repetitionEnd,
                                    repetitionStep: block.repetitionStep
                                )
                            }
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
                                    let repetitionCount = set.count ?? 1
                                    guard repetitionCount > 0 else {
                                        throw ProgramLibraryImportError.invalidSetGroup(
                                            "\(exercisePath)/direct/\(setIndex)/count"
                                        )
                                    }
                                    for repetitionIndex in 0..<repetitionCount {
                                        sets.append(try set.expand(
                                            path: "\(exercisePath)/direct/\(setIndex)/repeat/\(repetitionIndex)",
                                            orderIndex: sets.count,
                                            defaultRestSeconds: exercise.restSeconds,
                                            exposureKey: exercise.exposureKey,
                                            exerciseIDsByName: exerciseIDsByName
                                        ))
                                    }
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
                                    role: exercise.role,
                                    orderIndex: exerciseIndex,
                                    isOptional: exercise.optional ?? false,
                                    executionBlockKey: exercise.executionBlockKey,
                                    executionBlockComponentOrder: exercise.executionBlockComponentOrder,
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
                                executionBlocks: executionBlocks,
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
        var detectedCapabilities: Set<String> = []
        if allExercises.contains(where: { !$0.stages.isEmpty }) { detectedCapabilities.insert(EngineCapabilities.stages) }
        if allExercises.contains(where: { !$0.waves.isEmpty }) { detectedCapabilities.insert(EngineCapabilities.waves) }
        if allExercises.contains(where: { !($0.variationExerciseIDs ?? []).isEmpty }) {
            detectedCapabilities.insert(EngineCapabilities.variationLadders)
        }
        if allExercises.flatMap({ $0.plannedSets + $0.waves.flatMap(\.plannedSets) + $0.stages.flatMap(\.plannedSets) })
            .contains(where: { if case .amrap = $0.repetitions { return true }; return false }) {
            detectedCapabilities.insert(EngineCapabilities.amrapRepetitions)
        }
        if allExercises.flatMap({ $0.plannedSets + $0.waves.flatMap(\.plannedSets) + $0.stages.flatMap(\.plannedSets) })
            .contains(where: { $0.velocity != nil }) {
            detectedCapabilities.insert(EngineCapabilities.velocity)
        }
        if expandedBlocks.flatMap(\.weeks).flatMap(\.workouts)
            .contains(where: { !$0.executionBlocks.isEmpty }) {
            detectedCapabilities.insert(EngineCapabilities.executionBlocks)
        }
        if allExercises.flatMap({ $0.plannedSets + $0.waves.flatMap(\.plannedSets) + $0.stages.flatMap(\.plannedSets) })
            .contains(where: { if case .distance = $0.repetitions { return true }; return false }) {
            detectedCapabilities.insert(EngineCapabilities.distancePrescription)
        }
        if allExercises.flatMap({ $0.plannedSets + $0.waves.flatMap(\.plannedSets) + $0.stages.flatMap(\.plannedSets) })
            .contains(where: { $0.olympicAttempt != nil }) {
            detectedCapabilities.insert(EngineCapabilities.olympicAttempts)
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
            requiredEquipment: requiredEquipment ?? [],
            prerequisites: prerequisites ?? [],
            warnings: warnings ?? [],
            isExperimental: isExperimental ?? false,
            intakeInputs: intakeInputs ?? [],
            missedWorkoutPolicy: missedWorkoutPolicy ?? .shiftSequence,
            completionPolicy: try completionPolicy?.expand() ?? .end,
            requiredCapabilities: Set((requiredCapabilities ?? []) + detectedCapabilities).sorted(),
            provenance: provenance,
            sourceReferences: sourceReferences,
            discoveryMetadata: discoveryMetadata,
            supportedDisciplineIDs: supportedDisciplineIDs,
            focusAreaApplicability: focusAreaApplicability,
            focusAreaIDs: focusAreaIDs,
            estimatedSessionMinutesMinimum: estimatedSessionMinutesMinimum,
            estimatedSessionMinutesMaximum: estimatedSessionMinutesMaximum,
            competitionDisciplineID: competitionDisciplineID,
            optionalEquipmentCapabilityIDs: optionalEquipmentCapabilityIDs,
            equipmentRequirement: equipmentRequirement,
            displayName: displayName,
            disclaimer: disclaimer,
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

#endif

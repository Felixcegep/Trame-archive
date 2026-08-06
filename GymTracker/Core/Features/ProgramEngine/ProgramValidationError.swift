import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated struct ProgramValidationIssue: Codable, Hashable, Identifiable {
    enum Code: String, Codable, Hashable {
        case invalidSchemaVersion
        case emptyProgramKey
        case emptyName
        case invalidDuration
        case invalidSchedule
        case emptyBlocks
        case emptyWeeks
        case emptyWorkouts
        case invalidDayOffset
        case emptyWorkout
        case emptyExecutionBlock
        case emptyExecutionBlockKey
        case duplicateExecutionBlockKey
        case invalidExecutionBlockOrder
        case invalidExecutionBlockConfiguration
        case unknownExecutionBlock
        case missingExecutionBlockComponentOrder
        case duplicateExecutionBlockComponentOrder
        case invalidExecutionBlockComponentOrder
        case invalidExecutionBlockComponentCount
        case emptyExposureKey
        case emptySetPrescription
        case invalidSetOrder
        case invalidRepRange
        case invalidRest
        case invalidRPE
        case invalidRIR
        case invalidPrescriptionValue
        case invalidCompletionRule
        case invalidLoadReference
        case invalidPercentage
        case invalidFormula
        case duplicateIdentifier
        case duplicateExposureKey
        case invalidIntakeExposure
        case invalidStage
        case formulaCycle
        case referenceCycle
        case trackingProfileConflict
        case invalidProvenance
        case invalidDisciplineID
        case invalidFocusAreaID
        case invalidCompetitionDisciplineID
    }

    var id: UUID = UUID()
    var path: String
    var code: Code
    var message: String
}

extension TrackingProfileIssue {
    /// Surfaces this tracking-profile conflict at the precise payload path
    /// instead of a generic persistence error.
    var asProgramValidationIssue: ProgramValidationIssue {
        ProgramValidationIssue(path: path, code: .trackingProfileConflict, message: message)
    }
}

/// Hand-mirrored copies of three Onboarding enums' raw values.
///
/// `supportedDisciplineIDs`, `focusAreaIDs`, and `competitionDisciplineID`
/// are stored as plain strings on the payload specifically so a program
/// definition never has to import `TrainingDisciplinePreference`, `FocusArea`,
/// or `CompetitionDiscipline` (all declared in
/// `GymTracker/Core/Features/Onboarding/TrainingProfilePreferences.swift`) to
/// compile. That indirection matters here for a second reason beyond payload
/// stability: this file is also compiled into the widget extension target
/// (see the "GymTracker" folder's membership exceptions in
/// `GymTracker.xcodeproj/project.pbxproj`), which does not include the
/// Onboarding feature at all — a direct reference to those types would not
/// build there. Validating against a real import was the better-looking
/// option and the wrong one; this set is the deliberate, documented
/// duplication instead. If a case is added to or removed from any of the
/// three source enums, this list must be updated in the same change, or the
/// vocabulary that shipped the original drift (see `focusAreaIDs` history)
/// will silently stop being caught again.
nonisolated enum ProgramMatchVocabulary {
    /// Mirrors `TrainingDisciplinePreference.allCases.map(\.rawValue)`.
    static let disciplineIDs: Set<String> = [
        "generalStrength", "bodybuilding", "powerlifting", "olympicWeightlifting",
        "strongman", "hybridFitnessRacing", "cardioEndurance", "mobilityFlexibility",
        "generalFitness", "mixed", "unspecified"
    ]

    /// Mirrors `FocusArea.allCases.map(\.rawValue)`.
    static let focusAreaIDs: Set<String> = [
        "balanced", "chest", "back", "shoulders", "arms", "quadriceps",
        "hamstringsAndGlutes", "calves", "core"
    ]

    /// Mirrors `CompetitionDiscipline.allCases.map(\.rawValue)`.
    static let competitionDisciplineIDs: Set<String> = [
        "powerlifting", "olympicWeightlifting", "strongman", "bodybuilding",
        "hybridFitnessRacing", "endurance", "other", "undecided"
    ]
}

nonisolated enum ProgramDefinitionValidator {
    static func validate(_ definition: ProgramDefinitionPayload, isBuiltIn: Bool = false) -> [ProgramValidationIssue] {
        var issues: [ProgramValidationIssue] = []
        func add(_ path: String, _ code: ProgramValidationIssue.Code, _ message: String) {
            issues.append(ProgramValidationIssue(path: path, code: code, message: message))
        }

        if definition.schemaVersion < 1 { add("schemaVersion", .invalidSchemaVersion, "Schema version must be positive.") }
        if definition.templateVersion < 1 { add("templateVersion", .invalidSchemaVersion, "Template version must be positive.") }
        if isBuiltIn, definition.programKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add("programKey", .emptyProgramKey, "A built-in program requires a stable program key.")
        }
        if definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("name", .emptyName, "A program name is required.") }
        if definition.durationWeeks < 1 { add("durationWeeks", .invalidDuration, "A program must contain at least one week.") }
        if definition.supportedDaysPerWeek.isEmpty || definition.supportedDaysPerWeek.contains(where: { $0 < 1 || $0 > 7 }) {
            add("supportedDaysPerWeek", .invalidSchedule, "Supported days must be between one and seven.")
        }
        if definition.scheduleIntervalDays < 1 {
            add("scheduleIntervalDays", .invalidSchedule, "Schedule interval must be at least one day.")
        }
        if definition.blocks.isEmpty { add("blocks", .emptyBlocks, "A program must contain a block.") }
        if definition.provenance == nil, definition.sourceReferences?.isEmpty == false {
            add("sourceReferences", .invalidProvenance, "Source references require an explicit provenance classification.")
        }
        if let min = definition.estimatedSessionMinutesMinimum, min <= 0 {
            add("estimatedSessionMinutesMinimum", .invalidPrescriptionValue, "Minimum session minutes must be positive.")
        }
        if let max = definition.estimatedSessionMinutesMaximum, max <= 0 {
            add("estimatedSessionMinutesMaximum", .invalidPrescriptionValue, "Maximum session minutes must be positive.")
        }
        if let min = definition.estimatedSessionMinutesMinimum, let max = definition.estimatedSessionMinutesMaximum, min > max {
            add("estimatedSessionMinutesMinimum", .invalidPrescriptionValue, "Minimum session minutes cannot exceed maximum session minutes.")
        }
        // An unmappable identifier here is not a cosmetic typo: `ProgramMatchCandidate`
        // reads these strings straight against the onboarding enums'
        // `rawValue`s with no fallback, so a value that cannot map is dead
        // metadata that silently never contributes to a recommendation.
        for (index, disciplineID) in (definition.supportedDisciplineIDs ?? []).enumerated()
        where !ProgramMatchVocabulary.disciplineIDs.contains(disciplineID) {
            add(
                "supportedDisciplineIDs[\(index)]",
                .invalidDisciplineID,
                "'\(disciplineID)' is not a recognised training discipline identifier."
            )
        }
        for (index, focusAreaID) in (definition.focusAreaIDs ?? []).enumerated()
        where !ProgramMatchVocabulary.focusAreaIDs.contains(focusAreaID) {
            add(
                "focusAreaIDs[\(index)]",
                .invalidFocusAreaID,
                "'\(focusAreaID)' is not a recognised focus area identifier."
            )
        }
        if let competitionDisciplineID = definition.competitionDisciplineID,
           !ProgramMatchVocabulary.competitionDisciplineIDs.contains(competitionDisciplineID) {
            add(
                "competitionDisciplineID",
                .invalidCompetitionDisciplineID,
                "'\(competitionDisciplineID)' is not a recognised competition discipline identifier."
            )
        }
        for (index, reference) in (definition.sourceReferences ?? []).enumerated() {
            let path = "sourceReferences[\(index)]"
            if reference.organizationOrAuthors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || reference.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || reference.sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add(path, .invalidProvenance, "A source reference requires authorship, title, and a stable source identifier.")
            }
        }

        var identifiers = Set<UUID>()
        var formulaSources: [String: Set<String>] = [:]
        var loadReferenceSources: [String: Set<String>] = [:]
        var exposureKeys = Set<String>()
        var loadReferencePaths: [(dependency: String, path: String)] = []
        var formulaReferencePaths: [(dependency: String, path: String)] = []
        func checkID(_ id: UUID, _ path: String) {
            if !identifiers.insert(id).inserted { add(path, .duplicateIdentifier, "Identifier is used more than once.") }
        }
        for (blockIndex, block) in definition.blocks.enumerated() {
            let blockPath = "blocks[\(blockIndex)]"
            checkID(block.id, blockPath)
            if block.weeks.isEmpty { add(blockPath, .emptyWeeks, "A block must contain a week.") }
            for (field, value) in [
                ("deloadVolumeReductionPercent", block.deloadVolumeReductionPercent),
                ("deloadIntensityReductionPercent", block.deloadIntensityReductionPercent)
            ] {
                if let value, !(0...90).contains(value) {
                    add("\(blockPath).\(field)", .invalidPercentage, "Deload reduction must be between zero and ninety percent.")
                }
                if block.phaseType != .deload, value != nil {
                    add("\(blockPath).\(field)", .invalidPercentage, "Deload reductions are only valid on a deload phase.")
                }
            }
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
                    var executionBlockKeys = Set<String>()
                    var executionBlockOrders = Set<Int>()
                    var executionBlockMembershipOrders: [String: Set<Int>] = [:]
                    var executionBlockMembershipCounts: [String: Int] = [:]
                    if workout.dayOffset < 0 || workout.dayOffset > 6 { add("\(workoutPath).dayOffset", .invalidDayOffset, "Day offset must be between zero and six.") }
                    if workout.plannedExercises.isEmpty { add(workoutPath, .emptyWorkout, "A workout must contain an exercise.") }
                    for (executionBlockIndex, executionBlock) in workout.executionBlocks.enumerated() {
                        let executionBlockPath = "\(workoutPath).executionBlocks[\(executionBlockIndex)]"
                        checkID(executionBlock.id, executionBlockPath)
                        let key = executionBlock.blockKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if key.isEmpty {
                            add("\(executionBlockPath).blockKey", .emptyExecutionBlockKey, "Every execution block needs a stable key.")
                        } else if !executionBlockKeys.insert(key).inserted {
                            add("\(executionBlockPath).blockKey", .duplicateExecutionBlockKey, "Execution block keys must be unique within a workout.")
                        }
                        if executionBlock.orderIndex < 0 || !executionBlockOrders.insert(executionBlock.orderIndex).inserted {
                            add("\(executionBlockPath).orderIndex", .invalidExecutionBlockOrder, "Execution block order indices must be non-negative and unique within a workout.")
                        }
                        if executionBlock.targetRounds.map({ $0 <= 0 }) == true {
                            add("\(executionBlockPath).targetRounds", .invalidExecutionBlockConfiguration, "Target rounds must be positive.")
                        }
                        if executionBlock.restSeconds.map({ $0 < 0 }) == true {
                            add("\(executionBlockPath).restSeconds", .invalidRest, "Execution block rest cannot be negative.")
                        }
                        if let message = executionBlockConfigurationMessage(for: executionBlock) {
                            add(executionBlockPath, .invalidExecutionBlockConfiguration, message)
                        }
                    }
                    for (exerciseIndex, exercise) in workout.plannedExercises.enumerated() {
                        let exercisePath = "\(workoutPath).exercises[\(exerciseIndex)]"
                        checkID(exercise.id, exercisePath)
                        if let authoredBlockKey = exercise.executionBlockKey {
                            let blockKey = authoredBlockKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !executionBlockKeys.contains(blockKey) {
                                add("\(exercisePath).executionBlockKey", .unknownExecutionBlock, "The exercise references an execution block that does not exist in this workout.")
                            } else if let componentOrder = exercise.executionBlockComponentOrder {
                                if componentOrder < 0 {
                                    add("\(exercisePath).executionBlockComponentOrder", .invalidExecutionBlockComponentOrder, "Execution block component order cannot be negative.")
                                } else {
                                    if !executionBlockMembershipOrders[blockKey, default: []].insert(componentOrder).inserted {
                                        add("\(exercisePath).executionBlockComponentOrder", .duplicateExecutionBlockComponentOrder, "Component order must be unique within an execution block.")
                                    }
                                    executionBlockMembershipCounts[blockKey, default: 0] += 1
                                }
                            } else {
                                add("\(exercisePath).executionBlockComponentOrder", .missingExecutionBlockComponentOrder, "An execution-block exercise needs a component order.")
                            }
                        } else if exercise.executionBlockComponentOrder != nil {
                            add("\(exercisePath).executionBlockComponentOrder", .unknownExecutionBlock, "A component order requires execution block membership.")
                        }
                        if exercise.exposureKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            add("\(exercisePath).exposureKey", .emptyExposureKey, "Every planned exposure needs a stable key.")
                        } else if !workoutExposures.insert(exercise.exposureKey).inserted {
                            add("\(exercisePath).exposureKey", .duplicateExposureKey, "Exposure keys must be unique within a program definition.")
                        }
                        exposureKeys.insert(exercise.exposureKey)
                        if exercise.plannedSets.isEmpty && exercise.waves.isEmpty && exercise.stages.isEmpty {
                            add(exercisePath, .emptySetPrescription, "An exercise must contain a set prescription, wave, or stage.")
                        }
                        if !exercise.stages.isEmpty && !exercise.waves.isEmpty {
                            add(exercisePath, .invalidStage, "Stages and waves cannot be used on the same exercise.")
                        }
                        if !exercise.stages.isEmpty {
                            var stageIDs = Set<String>()
                            for (stageIndex, stage) in exercise.stages.enumerated() {
                                let stagePath = "\(exercisePath).stages[\(stageIndex)]"
                                checkID(stage.id, stagePath)
                                let normalizedID = stage.stageID.trimmingCharacters(in: .whitespacesAndNewlines)
                                if normalizedID.isEmpty || !stageIDs.insert(normalizedID).inserted {
                                    add("\(stagePath).stageID", .invalidStage, "Stage identifiers must be non-empty and unique within an exercise.")
                                }
                                if stage.plannedSets.isEmpty {
                                    add(stagePath, .emptySetPrescription, "A stage must contain a set prescription.")
                                }
                                validateStageSets(stage.plannedSets, stagePath, checkID, add)
                            }
                            guard let initialStageID = exercise.initialStageID,
                                  stageIDs.contains(initialStageID) else {
                                add("\(exercisePath).initialStageID", .invalidStage, "The initial stage must reference a stage on this exercise.")
                                continue
                            }
                            for (ruleIndex, rule) in exercise.progressionRules.enumerated() {
                                for target in stageTargets(in: [rule.successAction, rule.failureAction].compactMap { $0 })
                                    where !stageIDs.contains(target) {
                                    add("\(exercisePath).rules[\(ruleIndex)]", .invalidStage, "The rule references missing stage '\(target)'.")
                                }
                            }
                        } else if exercise.initialStageID != nil {
                            add("\(exercisePath).initialStageID", .invalidStage, "An initial stage requires stage definitions.")
                        }
                        if let warmup = exercise.warmupScheme {
                            if warmup.steps.isEmpty {
                                add("\(exercisePath).warmupScheme", .invalidSetOrder, "A warm-up scheme needs at least one step.")
                            }
                            for (stepIndex, step) in warmup.steps.enumerated() where step.percentage < 0 || step.percentage > 1 || step.repetitions < 1 {
                                add("\(exercisePath).warmupScheme.steps[\(stepIndex)]", .invalidSetOrder, "Warm-up percentages must be 0…1 and repetitions must be positive.")
                            }
                        }
                        var setOrders = Set<Int>()
                        for (setIndex, set) in exercise.plannedSets.enumerated() {
                            let setPath = "\(exercisePath).sets[\(setIndex)]"
                            checkID(set.id, setPath)
                            if set.orderIndex < 0 { add("\(setPath).orderIndex", .invalidSetOrder, "Set order must not be negative.") }
                            if !setOrders.insert(set.orderIndex).inserted { add("\(setPath).orderIndex", .invalidSetOrder, "Set order indices must be unique within an exercise.") }
                            validateRep(set.repetitions, setPath, add)
                            validateOlympicAttempt(set, setPath, add)
                            validateCompletionRule(set, setPath, add)
                            if let rest = set.restSeconds, rest < 0 { add("\(setPath).restSeconds", .invalidRest, "Rest cannot be negative.") }
                            if let rpe = set.targetRPE, rpe < 0 || rpe > 10 { add("\(setPath).targetRPE", .invalidRPE, "RPE must be between zero and ten.") }
                            if let rir = set.targetRIR, rir < 0 || rir > 10 { add("\(setPath).targetRIR", .invalidRIR, "RIR must be between zero and ten.") }
                            validateLoad(set.load, "\(setPath).load", add)
                            if set.generatesAfterSourceCompletion,
                               set.role != .backOff {
                                add("\(setPath).generatesAfterSourceCompletion", .invalidPrescriptionValue, "Only back-off prescriptions can be deferred.")
                            }
                            if set.generatesAfterSourceCompletion,
                               set.load.reference.kind != .topSet,
                               set.load.reference.kind != .dailyMaximum {
                                add("\(setPath).load.reference", .invalidLoadReference, "A deferred back-off must reference a top set or daily maximum.")
                            }
                            if set.load.reference.kind == .anotherPlannedExercise,
                               let dependency = set.load.reference.exposureKey {
                                loadReferenceSources[exercise.exposureKey, default: []].insert(dependency)
                            }
                            collectLoadReference(
                                set.load,
                                path: "\(setPath).load.reference",
                                into: &loadReferencePaths
                            )
                        }
                        if !exercise.waves.isEmpty {
                            var waveOrders = Set<Int>()
                            for (waveIndex, wave) in exercise.waves.enumerated() {
                                let wavePath = "\(exercisePath).waves[\(waveIndex)]"
                                checkID(wave.id, wavePath)
                                if !waveOrders.insert(wave.orderIndex).inserted { add("\(wavePath).orderIndex", .invalidSetOrder, "Wave order indices must be unique within an exercise.") }
                                if wave.plannedSets.isEmpty { add(wavePath, .emptySetPrescription, "A wave must contain a set prescription.") }
                                var waveSetOrders = Set<Int>()
                                for (setIndex, set) in wave.plannedSets.enumerated() {
                                    let setPath = "\(wavePath).sets[\(setIndex)]"
                                    checkID(set.id, setPath)
                                    if set.orderIndex < 0 { add("\(setPath).orderIndex", .invalidSetOrder, "Set order must not be negative.") }
                                    if !waveSetOrders.insert(set.orderIndex).inserted { add("\(setPath).orderIndex", .invalidSetOrder, "Set order indices must be unique within a wave.") }
                                    validateRep(set.repetitions, setPath, add)
                                    validateOlympicAttempt(set, setPath, add)
                                    validateCompletionRule(set, setPath, add)
                                    if let rest = set.restSeconds, rest < 0 { add("\(setPath).restSeconds", .invalidRest, "Rest cannot be negative.") }
                                    if let rpe = set.targetRPE, rpe < 0 || rpe > 10 { add("\(setPath).targetRPE", .invalidRPE, "RPE must be between zero and ten.") }
                                    if let rir = set.targetRIR, rir < 0 || rir > 10 { add("\(setPath).targetRIR", .invalidRIR, "RIR must be between zero and ten.") }
                                    validateLoad(set.load, "\(setPath).load", add)
                                    if set.generatesAfterSourceCompletion,
                                       set.role != .backOff {
                                        add("\(setPath).generatesAfterSourceCompletion", .invalidPrescriptionValue, "Only back-off prescriptions can be deferred.")
                                    }
                                    if set.generatesAfterSourceCompletion,
                                       set.load.reference.kind != .topSet,
                                       set.load.reference.kind != .dailyMaximum {
                                        add("\(setPath).load.reference", .invalidLoadReference, "A deferred back-off must reference a top set or daily maximum.")
                                    }
                                    if set.load.reference.kind == .anotherPlannedExercise,
                                       let dependency = set.load.reference.exposureKey {
                                        loadReferenceSources[exercise.exposureKey, default: []].insert(dependency)
                                    }
                                    collectLoadReference(
                                        set.load,
                                        path: "\(setPath).load.reference",
                                        into: &loadReferencePaths
                                    )
                                }
                            }
                        }
                        for (ruleIndex, rule) in exercise.progressionRules.enumerated() {
                            let rulePath = "\(exercisePath).rules[\(ruleIndex)]"
                            validateTrigger(rule.trigger, "\(rulePath).trigger", add)
                            validateActiveWorkoutAction(
                                rule,
                                hasDailyMaximumPrescription: exercise.plannedSets.contains { $0.role == .dailyMaximum }
                                    || exercise.waves.flatMap(\.plannedSets).contains { $0.role == .dailyMaximum }
                                    || exercise.stages.flatMap(\.plannedSets).contains { $0.role == .dailyMaximum },
                                path: rulePath,
                                add
                            )
                            if let failureAction = rule.failureAction,
                               case .endActiveDailyMaximumAndGenerateBackOffs = failureAction {
                                add(
                                    "\(rulePath).failureAction",
                                    .invalidPrescriptionValue,
                                    "Ending an active daily maximum cannot be a failure action."
                                )
                            }
                            if let formula = rule.formula {
                                var sources = Set<String>()
                                collectSources(formula, into: &sources)
                                formulaSources[exercise.exposureKey, default: []].formUnion(sources)
                                formulaReferencePaths += sources.map {
                                    (dependency: $0, path: "\(exercisePath).rules[\(ruleIndex)].formula")
                                }
                            }
                            collectActionFormula(rule.successAction, for: exercise.exposureKey, into: &formulaSources)
                            collectActionFormulaReferences(
                                rule.successAction,
                                path: "\(exercisePath).rules[\(ruleIndex)].successAction",
                                into: &formulaReferencePaths
                            )
                            if let failureAction = rule.failureAction {
                                collectActionFormula(failureAction, for: exercise.exposureKey, into: &formulaSources)
                                collectActionFormulaReferences(
                                    failureAction,
                                    path: "\(exercisePath).rules[\(ruleIndex)].failureAction",
                                    into: &formulaReferencePaths
                                )
                            }
                            if rule.version < 1 { add("\(exercisePath).rules[\(ruleIndex)].version", .invalidSchemaVersion, "Rule version must be positive.") }
                        }
                    }
                    for executionBlock in workout.executionBlocks {
                        let blockKey = executionBlock.blockKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let memberCount = executionBlockMembershipCounts[blockKey] ?? 0
                        if memberCount == 0 {
                            add("\(workoutPath).executionBlocks", .emptyExecutionBlock, "Execution block '\(blockKey)' needs at least one exercise.")
                            continue
                        }
                        if !validComponentCount(memberCount, for: executionBlock.kind) {
                            add("\(workoutPath).executionBlocks", .invalidExecutionBlockComponentCount, "\(executionBlock.kind.title) has an invalid number of exercise components.")
                        }
                        let componentOrders = executionBlockMembershipOrders[blockKey] ?? []
                        if componentOrders != Set(0..<memberCount) {
                            add("\(workoutPath).executionBlocks", .invalidExecutionBlockComponentOrder, "Execution block component order must be contiguous from zero.")
                        }
                    }
                }
            }
        }

        if hasCycle(in: formulaSources) {
            add("progressionRules", .formulaCycle, "Formula references contain a cycle.")
        }
        if hasCycle(in: loadReferenceSources) {
            add("loadReferences", .referenceCycle, "Cross-exercise load references contain a cycle.")
        }
        for reference in loadReferencePaths where !exposureKeys.contains(reference.dependency) {
            add(reference.path, .invalidLoadReference, "The referenced exposure '\(reference.dependency)' does not exist in this program.")
        }
        for reference in formulaReferencePaths where !exposureKeys.contains(reference.dependency) {
            add(reference.path, .invalidFormula, "The formula references exposure '\(reference.dependency)', which does not exist in this program.")
        }
        for (index, intakeInput) in definition.intakeInputs.enumerated()
        where intakeInput.exposureKey != "*" && !exposureKeys.contains(intakeInput.exposureKey) {
            add("intakeInputs[\(index)].exposureKey", .invalidIntakeExposure, "The intake input references exposure '\(intakeInput.exposureKey)', which does not exist in this program.")
        }
        return issues
    }

    private static func executionBlockConfigurationMessage(
        for block: ProgramExecutionBlockDefinition
    ) -> String? {
        if let message = ExecutionBlockConfigurationValidator.message(
            kind: block.kind,
            clockMode: block.clockMode,
            prescribedDurationSeconds: block.prescribedDurationSeconds,
            timeCapSeconds: block.timeCapSeconds,
            intervalSeconds: block.intervalSeconds,
            repetitionScheme: block.repetitionScheme,
            repetitionStart: block.repetitionStart,
            repetitionEnd: block.repetitionEnd,
            repetitionStep: block.repetitionStep
        ) {
            return message
        }
        if !block.kind.supportsRounds, block.targetRounds != nil {
            return "This execution block format does not use target rounds."
        }
        if block.clockMode == .none,
           block.prescribedDurationSeconds != nil || block.timeCapSeconds != nil || block.intervalSeconds != nil {
            return "Clock durations require an enabled shared clock."
        }
        if block.clockMode != .countdown, block.prescribedDurationSeconds != nil {
            return "Only a countdown clock uses a prescribed duration."
        }
        if block.clockMode != .repeatingInterval, block.intervalSeconds != nil {
            return "Only a repeating-interval clock uses an interval length."
        }
        if block.repetitionScheme == .fixed,
           block.repetitionStart != nil || block.repetitionEnd != nil || block.repetitionStep != nil {
            return "Fixed repetitions cannot include ladder bounds."
        }
        if block.kind == .amrap, block.scoreKind != .roundsAndRepetitions {
            return "An AMRAP is scored as rounds and repetitions."
        }
        if block.kind == .forTime, block.scoreKind != .duration {
            return "A For Time block is scored by duration."
        }
        if (block.kind == .emom || block.kind == .interval),
           block.scoreKind != .completedWork {
            return "This interval format is scored by completed work."
        }
        if block.scoreKind == .duration, block.clockMode == .none {
            return "A duration score requires a shared clock."
        }
        if block.scoreKind == .roundsAndRepetitions,
           block.kind != .amrap,
           !block.kind.supportsRounds {
            return "Rounds-and-repetitions scoring requires a round-based format."
        }
        return nil
    }

    private static func validComponentCount(_ count: Int, for kind: ExerciseBlockKind) -> Bool {
        switch kind {
        case .straight: count == 1
        case .pairedSet: count == 2
        case .triset: count == 3
        case .giantSet: count >= 4
        default: count > 0
        }
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

    private static func validateTrigger(
        _ trigger: ProgressionTrigger,
        _ path: String,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        switch trigger {
        case .allOf(let triggers), .anyOf(let triggers):
            if triggers.isEmpty {
                add(path, .invalidPrescriptionValue, "A composite trigger must contain at least one trigger.")
            }
            for (index, child) in triggers.enumerated() {
                validateTrigger(child, "\(path)[\(index)]", add)
            }
        case .atStage(let stageID):
            if stageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add(path, .invalidPrescriptionValue, "A stage trigger requires a stage identifier.")
            }
        case .failureCountReached(let count), .consecutiveMissedAttemptsReached(let count),
                .velocityBelowZoneCount(let count):
            if count < 1 {
                add(path, .invalidPrescriptionValue, "A count trigger requires a positive threshold.")
            }
        default:
            break
        }
    }

    private static func validateOlympicAttempt(
        _ set: SetPrescriptionDefinition,
        _ path: String,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        guard set.olympicAttempt != nil else { return }
        guard case .sequence(let components) = set.repetitions, !components.isEmpty else {
            add(
                "\(path).olympicAttempt",
                .invalidPrescriptionValue,
                "An Olympic attempt requires an ordered component sequence."
            )
            return
        }
        if let target = set.olympicAttempt?.targetQuality,
           target != .excellent,
           target != .acceptable {
            add(
                "\(path).olympicAttempt.targetQuality",
                .invalidPrescriptionValue,
                "An Olympic target quality must be excellent or acceptable."
            )
        }
    }

    private static func stageTargets(in actions: [ProgressionAction]) -> [String] {
        actions.compactMap { action in
            guard case .changeStage(let stageID) = action else { return nil }
            return stageID
        }
    }

    private static func validateActiveWorkoutAction(
        _ rule: ProgressionRuleDefinition,
        hasDailyMaximumPrescription: Bool,
        path: String,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        guard case let .endActiveDailyMaximumAndGenerateBackOffs(
            setCount,
            repetitions,
            percentage
        ) = rule.successAction else { return }
        guard setCount > 0, repetitions > 0, percentage > 0, percentage <= 1 else {
            add(
                "\(path).successAction",
                .invalidPrescriptionValue,
                "Generated back-offs need positive sets and repetitions and a percentage in 0…1."
            )
            return
        }
        guard case .consecutiveMissedAttemptsReached = rule.trigger,
              rule.cadence == .nextSet,
              rule.applicationMode == .recommendation,
              hasDailyMaximumPrescription else {
            add(
                "\(path).successAction",
                .invalidPrescriptionValue,
                "Ending an active daily maximum requires a daily-maximum prescription, a consecutive-miss trigger, next-set cadence, and recommendation mode."
            )
            return
        }
    }

    private static func validateStageSets(
        _ sets: [SetPrescriptionDefinition],
        _ path: String,
        _ checkID: (UUID, String) -> Void,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        var orders = Set<Int>()
        for (index, set) in sets.enumerated() {
            let setPath = "\(path).sets[\(index)]"
            checkID(set.id, setPath)
            if set.orderIndex < 0 || !orders.insert(set.orderIndex).inserted {
                add("\(setPath).orderIndex", .invalidSetOrder, "Stage set order indices must be non-negative and unique.")
            }
            validateRep(set.repetitions, setPath, add)
            validateOlympicAttempt(set, setPath, add)
            validateCompletionRule(set, setPath, add)
            if let rest = set.restSeconds, rest < 0 { add("\(setPath).restSeconds", .invalidRest, "Rest cannot be negative.") }
            if let rpe = set.targetRPE, !(0...10).contains(rpe) { add("\(setPath).targetRPE", .invalidRPE, "RPE must be between zero and ten.") }
            if let rir = set.targetRIR, !(0...10).contains(rir) { add("\(setPath).targetRIR", .invalidRIR, "RIR must be between zero and ten.") }
            validateLoad(set.load, "\(setPath).load", add)
        }
    }

    private static func validateCompletionRule(
        _ set: SetPrescriptionDefinition,
        _ path: String,
        _ add: (String, ProgramValidationIssue.Code, String) -> Void
    ) {
        guard let rule = set.completionRule else { return }
        switch rule {
        case .all(let metrics), .any(let metrics):
            if metrics.isEmpty {
                add(
                    "\(path).completionRule",
                    .invalidCompletionRule,
                    "A metric completion rule must include at least one metric."
                )
            }
            let unsupported = metrics.subtracting(TrackingMetric.completionWritable)
            if !unsupported.isEmpty {
                let names = unsupported.sorted { $0.rawValue < $1.rawValue }
                    .map(\.title)
                    .joined(separator: ", ")
                add(
                    "\(path).completionRule",
                    .invalidCompletionRule,
                    "These metrics cannot currently require set completion: \(names)."
                )
            }
        case .prescribedTargets:
            if set.prescribedCompletionMetrics.isEmpty {
                add(
                    "\(path).completionRule",
                    .invalidCompletionRule,
                    "Prescribed-target completion requires at least one explicit repetition, load, duration, distance, or calorie target."
                )
            }
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
                add("\(path).reference", .invalidLoadReference, "This load reference requires an exposure key.")
            }
        case .exerciseOneRepMax, .referenceExercise:
            if load.reference.exerciseID == nil && load.reference.exposureKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                add("\(path).reference", .invalidLoadReference, "This load reference requires an exercise or exposure key.")
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
                    .dailyMaximum(let key), .anotherExposure(let key), .completedMetric(let key, _),
                    .velocityBaseline(let key):
                sources.insert(key)
            case .constant:
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

    private static func collectActionFormula(
        _ action: ProgressionAction,
        for exposureKey: String,
        into graph: inout [String: Set<String>]
    ) {
        let formula: ProgressionFormula?
        switch action {
        case .updateTrainingMax(let value),
                .updateEstimatedOneRepMax(let value),
                .updateActualOneRepMax(let value):
            formula = value
        default:
            formula = nil
        }
        guard let formula else { return }
        var sources = Set<String>()
        collectSources(formula, into: &sources)
        graph[exposureKey, default: []].formUnion(sources)
    }

    private static func collectActionFormulaReferences(
        _ action: ProgressionAction,
        path: String,
        into references: inout [(dependency: String, path: String)]
    ) {
        let formula: ProgressionFormula?
        switch action {
        case .updateTrainingMax(let value),
                .updateEstimatedOneRepMax(let value),
                .updateActualOneRepMax(let value):
            formula = value
        default:
            formula = nil
        }
        guard let formula else { return }
        var sources = Set<String>()
        collectSources(formula, into: &sources)
        references += sources.map { (dependency: $0, path: path) }
    }

    private static func collectLoadReference(
        _ load: LoadPrescription,
        path: String,
        into references: inout [(dependency: String, path: String)]
    ) {
        guard let key = load.reference.exposureKey,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        switch load.reference.kind {
        case .trainingMax, .estimatedOneRepMax, .exerciseOneRepMax, .previousWorkout,
                .previousSuccessfulSet, .previousOccurrence, .topSet, .dailyMaximum,
                .anotherPlannedExercise:
            references.append((dependency: key, path: path))
        case .manual, .fixedLoad, .referenceExercise:
            break
        }
    }

    private static func hasCycle(in graph: [String: Set<String>]) -> Bool {
        var visiting = Set<String>()
        var visited = Set<String>()
        func visit(_ node: String) -> Bool {
            if visiting.contains(node) { return true }
            if visited.contains(node) { return false }
            visiting.insert(node)
            // Reading the current exposure's own Training Max/e1RM is a
            // normal update formula, not a cross-exposure cycle. Only a
            // dependency that leads to another exposure can form a cycle.
            for dependency in graph[node] ?? [] where dependency != node && graph[dependency] != nil {
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

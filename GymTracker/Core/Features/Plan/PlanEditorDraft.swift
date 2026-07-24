import SwiftData
import SwiftUI

@MainActor
struct PlanEditorDraft {
    var name: String
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var requiredEquipment: [EquipmentType]
    var scheduleMode: PlanScheduleMode
    var scheduleIntervalDays: Int
    var blocks: [PlanBlockDraft]
    var weeks: [PlanWeekDraft]

    init(plan: WorkoutPlan) {
        name = plan.name
        goal = plan.goal
        experienceLevel = plan.experienceLevel
        requiredEquipment = plan.requiredEquipment
        scheduleMode = plan.scheduleMode
        scheduleIntervalDays = plan.scheduleIntervalDays
        blocks = plan.orderedBlocks.map(PlanBlockDraft.init)
        weeks = plan.orderedWeeks.map(PlanWeekDraft.init)
    }

    func apply(to plan: WorkoutPlan, using context: ModelContext) throws {
        // The review screen blocks confirmation on these issues, but the plan
        // graph itself is the persistence boundary: intents, importers, and
        // future editors must receive the same protection as the sheet.
        let issues = trackingProfileIssues
        guard issues.isEmpty else {
            throw TrackingProfileValidationFailure(issues: issues)
        }

        plan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.goal = goal
        plan.experienceLevel = experienceLevel
        plan.requiredEquipment = Array(Set(requiredEquipment)).sorted { $0.rawValue < $1.rawValue }
        plan.scheduleMode = scheduleMode
        plan.scheduleIntervalDays = max(1, scheduleIntervalDays)
        plan.updatedAt = .now

        let retainedBlockIDs = Set(blocks.map(\.id))
        for block in plan.blocks where !retainedBlockIDs.contains(block.id) {
            context.delete(block)
        }

        for blockDraft in blocks {
            guard let block = plan.orderedBlocks.first(where: { $0.id == blockDraft.id }) else { continue }
            block.orderIndex = blockDraft.orderIndex
            block.name = blockDraft.normalizedName
            block.phaseType = blockDraft.phaseType
            block.deloadVolumeReductionPercent = blockDraft.phaseType == .deload
                ? blockDraft.normalizedVolumeReductionPercent
                : nil
            block.deloadIntensityReductionPercent = blockDraft.phaseType == .deload
                ? blockDraft.normalizedIntensityReductionPercent
                : nil
        }

        for weekDraft in weeks {
            guard let week = plan.orderedWeeks.first(where: { $0.id == weekDraft.id }) else { continue }
            for workoutDraft in weekDraft.workouts {
                guard let workout = week.orderedPlannedWorkouts.first(where: { $0.id == workoutDraft.id }) else { continue }
                workout.name = workoutDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                workout.dayOffset = workoutDraft.dayOffset
                workout.isOptional = workoutDraft.isOptional

                let retainedExecutionBlockIDs = Set(workoutDraft.executionBlocks.compactMap(\.existingID))
                for existing in workout.executionBlocks where !retainedExecutionBlockIDs.contains(existing.id) {
                    context.delete(existing)
                }
                var blockIDsByDraftID: [UUID: UUID] = [:]
                workout.executionBlocks = workoutDraft.executionBlocks.enumerated().map { index, draft in
                    if let existingID = draft.existingID,
                       let existing = workout.executionBlocks.first(where: { $0.id == existingID }) {
                        draft.apply(to: existing, orderIndex: index)
                        blockIDsByDraftID[draft.id] = existing.id
                        return existing
                    }
                    let block = draft.makeModel(orderIndex: index)
                    blockIDsByDraftID[draft.id] = block.id
                    return block
                }

                let retainedIDs = Set(workoutDraft.exercises.compactMap(\.existingID))
                for existing in workout.plannedExercises where !retainedIDs.contains(existing.id) {
                    context.delete(existing)
                }

                workout.plannedExercises = workoutDraft.exercises.enumerated().map { index, draft in
                    if let existingID = draft.existingID,
                       let existing = workout.plannedExercises.first(where: { $0.id == existingID }) {
                        draft.apply(to: existing, orderIndex: index, using: context)
                        existing.executionBlockID = draft.executionBlockID.flatMap { blockIDsByDraftID[$0] }
                        existing.executionBlockComponentOrder = draft.executionBlockComponentOrder
                        return existing
                    }
                    let created = draft.makeModel(orderIndex: index)
                    created.executionBlockID = draft.executionBlockID.flatMap { blockIDsByDraftID[$0] }
                    created.executionBlockComponentOrder = draft.executionBlockComponentOrder
                    return created
                }
                workout.normalizePlannedExerciseOrder()
            }
        }
    }
}

extension PlanEditorDraft {
    var equipmentSummary: String {
        requiredEquipment.isEmpty
            ? "No equipment selected"
            : requiredEquipment.map(\.rawValue).joined(separator: ", ")
    }

    var phaseSummary: String {
        let deloadCount = blocks.filter { $0.phaseType == .deload }.count
        let phaseText = blocks.count == 1 ? "1 phase" : "\(blocks.count) phases"
        guard deloadCount > 0 else { return phaseText }
        return "\(phaseText) · \(deloadCount) deload"
    }
}

@MainActor
struct PlanBlockDraft: Identifiable {
    let id: UUID
    var orderIndex: Int
    let weekIndices: [Int]
    var name: String
    var phaseType: PlanPhaseType
    var deloadVolumeReductionPercent: Int
    var deloadIntensityReductionPercent: Int

    init(block: PlanBlock) {
        id = block.id
        orderIndex = block.orderIndex
        weekIndices = block.orderedWeeks.map(\.weekIndex)
        name = block.name
        phaseType = block.phaseType
        deloadVolumeReductionPercent = block.effectiveDeloadVolumeReductionPercent
        deloadIntensityReductionPercent = block.effectiveDeloadIntensityReductionPercent
    }

    var weekSummary: String {
        guard let first = weekIndices.first, let last = weekIndices.last else {
            return "No weeks assigned"
        }
        if first == last {
            return "Week \(first + 1)"
        }
        return "Weeks \(first + 1)–\(last + 1)"
    }

    var normalizedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? phaseType.defaultBlockName : trimmed
    }

    var normalizedVolumeReductionPercent: Int {
        min(90, max(0, deloadVolumeReductionPercent))
    }

    var normalizedIntensityReductionPercent: Int {
        min(90, max(0, deloadIntensityReductionPercent))
    }

    var deloadSummary: String {
        "Reduce sets by \(normalizedVolumeReductionPercent)% · load by \(normalizedIntensityReductionPercent)%"
    }
}

@MainActor
struct PlanWeekDraft: Identifiable {
    let id: UUID
    let weekIndex: Int
    var workouts: [PlanWorkoutDraft]

    init(week: PlanWeek) {
        id = week.id
        weekIndex = week.weekIndex
        workouts = week.orderedPlannedWorkouts.map(PlanWorkoutDraft.init)
    }
}

@MainActor
struct PlanWorkoutDraft: Identifiable {
    let id: UUID
    var name: String
    var dayOffset: Int
    var isOptional: Bool
    var exercises: [PlanExerciseDraft]
    var executionBlocks: [PlanExecutionBlockDraft]

    init(workout: PlannedWorkout) {
        id = workout.id
        name = workout.name
        dayOffset = workout.dayOffset
        isOptional = workout.isOptional
        exercises = workout.orderedPlannedExercises.map(PlanExerciseDraft.init)
        executionBlocks = workout.orderedExecutionBlocks.map(PlanExecutionBlockDraft.init)
    }
}

@MainActor
struct PlanExecutionBlockDraft: Identifiable {
    let id: UUID
    let existingID: UUID?
    var kind: ExerciseBlockKind
    var name: String
    var targetRounds: Int?
    var isSharedLoad: Bool
    var restSeconds: Int?
    var clockMode: BlockClockMode
    var prescribedDurationSeconds: Int?
    var timeCapSeconds: Int?
    var intervalSeconds: Int?
    var scoreKind: BlockScoreKind
    var repetitionScheme: BlockRepetitionScheme
    var repetitionStart: Int?
    var repetitionEnd: Int?
    var repetitionStep: Int?
    var sourceTemplateBlockID: UUID?
    var definitionBlockKey: String?

    init(
        kind: ExerciseBlockKind,
        name: String = "",
        targetRounds: Int? = nil,
        isSharedLoad: Bool = false,
        restSeconds: Int? = nil,
        clockMode: BlockClockMode = .none,
        prescribedDurationSeconds: Int? = nil,
        timeCapSeconds: Int? = nil,
        intervalSeconds: Int? = nil,
        scoreKind: BlockScoreKind = .none,
        repetitionScheme: BlockRepetitionScheme = .fixed,
        repetitionStart: Int? = nil,
        repetitionEnd: Int? = nil,
        repetitionStep: Int? = nil,
        sourceTemplateBlockID: UUID? = nil,
        definitionBlockKey: String? = nil
    ) {
        id = UUID()
        existingID = nil
        self.kind = kind
        self.name = name
        self.targetRounds = targetRounds
        self.isSharedLoad = isSharedLoad
        self.restSeconds = restSeconds
        self.clockMode = clockMode
        self.prescribedDurationSeconds = prescribedDurationSeconds
        self.timeCapSeconds = timeCapSeconds
        self.intervalSeconds = intervalSeconds
        self.scoreKind = scoreKind
        self.repetitionScheme = repetitionScheme
        self.repetitionStart = repetitionStart
        self.repetitionEnd = repetitionEnd
        self.repetitionStep = repetitionStep
        self.sourceTemplateBlockID = sourceTemplateBlockID
        self.definitionBlockKey = definitionBlockKey
    }

    init(block: PlannedExerciseBlock) {
        id = block.id
        existingID = block.id
        kind = block.kind
        name = block.name ?? ""
        targetRounds = block.targetRounds
        isSharedLoad = block.isSharedLoad
        restSeconds = block.restSeconds
        clockMode = block.clockMode
        prescribedDurationSeconds = block.prescribedDurationSeconds
        timeCapSeconds = block.timeCapSeconds
        intervalSeconds = block.intervalSeconds
        scoreKind = block.scoreKind
        repetitionScheme = block.repetitionScheme
        repetitionStart = block.repetitionStart
        repetitionEnd = block.repetitionEnd
        repetitionStep = block.repetitionStep
        sourceTemplateBlockID = block.sourceTemplateBlockID
        definitionBlockKey = block.definitionBlockKey
    }

    func makeModel(orderIndex: Int) -> PlannedExerciseBlock {
        PlannedExerciseBlock(
            orderIndex: orderIndex,
            kind: kind,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name,
            targetRounds: targetRounds,
            isSharedLoad: isSharedLoad,
            restSeconds: restSeconds,
            clockMode: clockMode,
            prescribedDurationSeconds: prescribedDurationSeconds,
            timeCapSeconds: timeCapSeconds,
            intervalSeconds: intervalSeconds,
            scoreKind: scoreKind,
            repetitionScheme: repetitionScheme,
            repetitionStart: repetitionStart,
            repetitionEnd: repetitionEnd,
            repetitionStep: repetitionStep,
            sourceTemplateBlockID: sourceTemplateBlockID,
            definitionBlockKey: definitionBlockKey
        )
    }

    func apply(to block: PlannedExerciseBlock, orderIndex: Int) {
        block.orderIndex = orderIndex
        block.kind = kind
        block.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
        block.targetRounds = targetRounds
        block.isSharedLoad = isSharedLoad
        block.restSeconds = restSeconds
        block.clockMode = clockMode
        block.prescribedDurationSeconds = prescribedDurationSeconds
        block.timeCapSeconds = timeCapSeconds
        block.intervalSeconds = intervalSeconds
        block.scoreKind = scoreKind
        block.repetitionScheme = repetitionScheme
        block.repetitionStart = repetitionStart
        block.repetitionEnd = repetitionEnd
        block.repetitionStep = repetitionStep
        block.sourceTemplateBlockID = sourceTemplateBlockID
        block.definitionBlockKey = definitionBlockKey
    }
}

@MainActor
struct PlanExerciseDraft: Identifiable {
    let id: UUID
    let existingID: UUID?
    var progressionKey: String
    var supersetGroupID: UUID?
    var executionBlockID: UUID?
    var executionBlockComponentOrder: Int?
    var exercise: Exercise
    var role: ExerciseRole
    var isOptional: Bool
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var suggestedLoadText: String
    var suggestedLoadType: WeightType
    var restSeconds: Int
    var targetRPEText: String
    var targetRIR: Int
    var notes: String
    var progressionRule: ProgressionRule
    var stimulus: TrainingStimulus
    var alternatives: [Exercise]
    var plannedSets: [PlanSetDraft]
    var progressionRulesData: Data?
    var progressionWavesData: Data?
    var progressionStagesData: Data?
    var initialTrainingMax: Double?
    var initialEstimatedOneRepMax: Double?
    var initialActualOneRepMax: Double?

    init(exercise: Exercise, orderIndex: Int) {
        id = UUID()
        existingID = nil
        progressionKey = UUID().uuidString
        supersetGroupID = nil
        executionBlockID = nil
        executionBlockComponentOrder = nil
        self.exercise = exercise
        role = .main
        isOptional = false
        targetSets = 3
        repRangeMinimum = 8
        repRangeMaximum = 12
        suggestedLoadText = ""
        suggestedLoadType = .kg
        restSeconds = 90
        targetRPEText = ""
        targetRIR = 0
        notes = ""
        progressionRule = exercise.trackingType.usesWeight
            && exercise.trackingType != .assistedBodyweight
            ? .doubleProgression
            : .none
        stimulus = TrainingStimulusResolver.inferredStimulus(for: exercise) ?? .strength
        alternatives = []
        plannedSets = []
        progressionRulesData = nil
        progressionWavesData = nil
        progressionStagesData = nil
        initialTrainingMax = nil
        initialEstimatedOneRepMax = nil
        initialActualOneRepMax = nil
    }

    init(plannedExercise: PlannedExercise) {
        id = plannedExercise.id
        existingID = plannedExercise.id
        progressionKey = plannedExercise.progressionKey
        supersetGroupID = plannedExercise.supersetGroupID
        executionBlockID = plannedExercise.executionBlockID
        executionBlockComponentOrder = plannedExercise.executionBlockComponentOrder
        exercise = plannedExercise.exercise
        role = plannedExercise.role
        isOptional = plannedExercise.isOptional
        targetSets = plannedExercise.targetSets
        repRangeMinimum = plannedExercise.repRangeMinimum
        repRangeMaximum = plannedExercise.repRangeMaximum
        suggestedLoadText = plannedExercise.suggestedLoad.map { String($0) } ?? ""
        suggestedLoadType = plannedExercise.suggestedLoadType ?? .kg
        restSeconds = plannedExercise.restSeconds
        targetRPEText = plannedExercise.targetRPE.map { String($0) } ?? ""
        targetRIR = plannedExercise.targetRIR ?? 0
        notes = plannedExercise.notes ?? ""
        progressionRule = plannedExercise.progressionRule
        stimulus = plannedExercise.resolvedStimulus
        alternatives = plannedExercise.alternatives
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(\.exercise)
        plannedSets = plannedExercise.orderedPlannedSets.map(PlanSetDraft.init)
        progressionRulesData = plannedExercise.progressionRulesData
        progressionWavesData = plannedExercise.progressionWavesData
        progressionStagesData = plannedExercise.progressionStagesData
        initialTrainingMax = plannedExercise.initialTrainingMax
        initialEstimatedOneRepMax = plannedExercise.initialEstimatedOneRepMax
        initialActualOneRepMax = plannedExercise.initialActualOneRepMax
    }

    var summary: String {
        let load = suggestedLoadText.isEmpty ? "No suggested load" : "\(suggestedLoadText) \(suggestedLoadType == .kg ? "kg" : "lb")"
        return "\(targetSets) × \(repRangeMinimum)-\(repRangeMaximum) · \(load) · \(restSeconds)s rest"
    }

    var displayName: String {
        exercise.name
    }

    var alternativesSummary: String? {
        guard !alternatives.isEmpty else { return nil }
        return alternatives.map(\.name).joined(separator: ", ")
    }

    /// Imported or legacy plan data may predate current editor constraints.
    /// Normalize it before binding it to controls that require a valid range.
    mutating func normalizeRepRangeForEditing() {
        repRangeMinimum = min(max(repRangeMinimum, 1), 100)
        repRangeMaximum = min(max(repRangeMaximum, repRangeMinimum), 100)
    }

    func makeModel(orderIndex: Int) -> PlannedExercise {
        PlannedExercise(
            exercise: exercise,
            orderIndex: orderIndex,
            role: role,
            isOptional: isOptional,
            targetSets: targetSets,
            repRangeMinimum: repRangeMinimum,
            repRangeMaximum: max(repRangeMinimum, repRangeMaximum),
            suggestedLoad: Double(suggestedLoadText),
            suggestedLoadType: suggestedLoadType,
            restSeconds: restSeconds,
            targetRPE: Double(targetRPEText),
            targetRIR: targetRIR == 0 ? nil : targetRIR,
            notes: notes.isEmpty ? nil : notes,
            progressionRule: progressionRule,
            stimulus: stimulus,
            alternatives: alternatives.enumerated().map {
                PlannedExerciseAlternative(exercise: $0.element, orderIndex: $0.offset)
            },
            plannedSets: plannedSets.enumerated().map { index, set in
                set.makeModel(orderIndex: index)
            },
            supersetGroupID: supersetGroupID,
            progressionKey: progressionKey,
            progressionRulesData: progressionRulesData,
            progressionWavesData: progressionWavesData,
            progressionStagesData: progressionStagesData,
            initialTrainingMax: initialTrainingMax,
            initialEstimatedOneRepMax: initialEstimatedOneRepMax,
            initialActualOneRepMax: initialActualOneRepMax
        )
    }

    func apply(to model: PlannedExercise, orderIndex: Int, using context: ModelContext) {
        model.orderIndex = orderIndex
        model.exercise = exercise
        model.role = role
        model.isOptional = isOptional
        model.targetSets = targetSets
        model.repRangeMinimum = repRangeMinimum
        model.repRangeMaximum = max(repRangeMinimum, repRangeMaximum)
        model.suggestedLoad = Double(suggestedLoadText)
        model.suggestedLoadType = suggestedLoadType
        model.restSeconds = restSeconds
        model.targetRPE = Double(targetRPEText)
        model.targetRIR = targetRIR == 0 ? nil : targetRIR
        model.notes = notes.isEmpty ? nil : notes
        model.progressionRule = progressionRule
        model.stimulus = stimulus
        model.progressionKey = progressionKey
        model.progressionRulesData = progressionRulesData
        model.progressionWavesData = progressionWavesData
        model.progressionStagesData = progressionStagesData
        model.initialTrainingMax = initialTrainingMax
        model.initialEstimatedOneRepMax = initialEstimatedOneRepMax
        model.initialActualOneRepMax = initialActualOneRepMax
        model.supersetGroupID = supersetGroupID
        for alternative in model.alternatives {
            context.delete(alternative)
        }
        model.alternatives = alternatives.enumerated().map {
            PlannedExerciseAlternative(exercise: $0.element, orderIndex: $0.offset)
        }
        for plannedSet in model.plannedSets {
            context.delete(plannedSet)
        }
        model.plannedSets = plannedSets.enumerated().map { index, set in
            set.makeModel(orderIndex: index)
        }
    }
}

extension PlanEditorDraft {
    /// Structured stimulus/tracking conflicts in the draft. Non-empty issues
    /// must block applying the draft to the persisted plan graph.
    var trackingProfileIssues: [TrackingProfileIssue] {
        var issues: [TrackingProfileIssue] = []
        for (weekIndex, week) in weeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                for (exerciseIndex, exercise) in workout.exercises.enumerated()
                where !TrackingProfileValidator.isValid(
                    stimulus: exercise.stimulus,
                    trackingType: exercise.exercise.trackingType
                ) {
                    issues.append(
                        TrackingProfileIssue(
                            path: "weeks[\(weekIndex)].workouts[\(workoutIndex)].exercises[\(exerciseIndex)]",
                            exerciseName: exercise.exercise.name,
                            stimulus: exercise.stimulus,
                            trackingType: exercise.exercise.trackingType
                        )
                    )
                }
            }
        }
        return issues
    }
}

extension PlanExerciseDraft {
    var title: String { exercise.name }

    var supportsDoubleProgression: Bool {
        exercise.trackingType.usesWeight && exercise.trackingType != .assistedBodyweight
    }

    var doubleProgressionEnabled: Bool {
        get { progressionRule == .doubleProgression }
        set { progressionRule = newValue ? .doubleProgression : .none }
    }

    mutating func addPlannedSet() {
        plannedSets.append(
            PlanSetDraft(
                setType: .normal,
                repetitions: nil,
                repRangeMinimum: repRangeMinimum,
                repRangeMaximum: repRangeMaximum,
                suggestedLoad: Double(suggestedLoadText),
                suggestedLoadType: suggestedLoadType,
                restSeconds: restSeconds,
                targetRPE: Double(targetRPEText),
                targetRIR: targetRIR == 0 ? nil : targetRIR
            )
        )
    }
}

@MainActor
struct PlanSetDraft: Identifiable {
    let id: UUID
    var setType: SetType
    var repetitionsText: String
    var repRangeMinimumText: String
    var repRangeMaximumText: String
    var suggestedLoadText: String
    var suggestedLoadType: WeightType
    var restSecondsText: String
    var targetRPEText: String
    var targetRIRText: String
    var tempoText: String
    var progressionEligible: Bool
    var isOptional: Bool
    var notes: String
    var definitionData: Data?

    init(
        setType: SetType,
        repetitions: Int?,
        repRangeMinimum: Int?,
        repRangeMaximum: Int?,
        suggestedLoad: Double?,
        suggestedLoadType: WeightType,
        restSeconds: Int?,
        targetRPE: Double?,
        targetRIR: Int?
    ) {
        id = UUID()
        self.setType = setType
        repetitionsText = repetitions.map { String($0) } ?? ""
        repRangeMinimumText = repRangeMinimum.map { String($0) } ?? ""
        repRangeMaximumText = repRangeMaximum.map { String($0) } ?? ""
        suggestedLoadText = suggestedLoad.map { String($0) } ?? ""
        self.suggestedLoadType = suggestedLoadType
        restSecondsText = restSeconds.map { String($0) } ?? ""
        targetRPEText = targetRPE.map { String($0) } ?? ""
        targetRIRText = targetRIR.map { String($0) } ?? ""
        tempoText = ""
        progressionEligible = true
        isOptional = false
        notes = ""
        definitionData = nil
    }

    init(plannedSet: PlannedSet) {
        id = UUID()
        setType = plannedSet.setType
        repetitionsText = plannedSet.repetitions.map { String($0) } ?? ""
        repRangeMinimumText = plannedSet.repRangeMinimum.map { String($0) } ?? ""
        repRangeMaximumText = plannedSet.repRangeMaximum.map { String($0) } ?? ""
        suggestedLoadText = plannedSet.suggestedLoad.map { String($0) } ?? ""
        suggestedLoadType = plannedSet.suggestedLoadType ?? .kg
        restSecondsText = plannedSet.restSeconds.map { String($0) } ?? ""
        targetRPEText = plannedSet.targetRPE.map { String($0) } ?? ""
        targetRIRText = plannedSet.targetRIR.map { String($0) } ?? ""
        tempoText = plannedSet.tempo ?? ""
        progressionEligible = plannedSet.progressionEligible
        isOptional = plannedSet.isOptional
        notes = plannedSet.notes ?? ""
        definitionData = plannedSet.definitionData
    }

    var summary: String {
        let repetitions: String
        if let exact = Int(repetitionsText) {
            repetitions = "\(exact) reps"
        } else if let minimum = Int(repRangeMinimumText), let maximum = Int(repRangeMaximumText) {
            repetitions = "\(minimum)–\(max(minimum, maximum)) reps"
        } else {
            repetitions = "No rep target"
        }
        let load = suggestedLoadText.isEmpty ? "No load" : "\(suggestedLoadText) \(suggestedLoadType.rawValue)"
        var details = ["\(setType.title) · \(repetitions) · \(load)"]
        if let rest = Int(restSecondsText), rest >= 0 { details.append("\(rest)s rest") }
        if let rpe = Double(targetRPEText) { details.append("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))") }
        if let rir = Int(targetRIRText) { details.append("RIR \(rir)") }
        if !tempoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { details.append("Tempo \(tempoText)") }
        if !progressionEligible { details.append("No progression") }
        if isOptional { details.append("Optional") }
        return details.joined(separator: " · ")
    }

    func makeModel(orderIndex: Int) -> PlannedSet {
        let exactRepetitions = Int(repetitionsText)
        let minimum = exactRepetitions == nil ? Int(repRangeMinimumText) : nil
        let maximum = exactRepetitions == nil
            ? Int(repRangeMaximumText).map { maximum in max(minimum ?? maximum, maximum) }
            : nil
        return PlannedSet(
            orderIndex: orderIndex,
            setType: setType,
            repetitions: exactRepetitions,
            repRangeMinimum: minimum,
            repRangeMaximum: maximum,
            suggestedLoad: Double(suggestedLoadText),
            suggestedLoadType: suggestedLoadText.isEmpty ? nil : suggestedLoadType,
            restSeconds: Int(restSecondsText),
            targetRPE: Double(targetRPEText),
            targetRIR: Int(targetRIRText),
            tempo: tempoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempoText,
            progressionEligible: progressionEligible,
            isOptional: isOptional,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            definitionData: definitionData
        )
    }
}

extension PlanGoal {
    var title: String {
        switch self {
        case .generalStrength: return "General strength"
        case .hypertrophy: return "Hypertrophy"
        case .powerlifting: return "Powerlifting"
        case .generalFitness: return "General fitness"
        }
    }
}

extension PlanExperienceLevel {
    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

extension PlanPhaseType {
    var title: String {
        switch self {
        case .accumulation: return "Accumulation"
        case .hypertrophy: return "Hypertrophy"
        case .strength: return "Strength"
        case .peaking: return "Peaking"
        case .deload: return "Deload"
        }
    }

    var defaultBlockName: String {
        switch self {
        case .accumulation: return "Build"
        case .hypertrophy: return "Hypertrophy"
        case .strength: return "Strength"
        case .peaking: return "Peak"
        case .deload: return "Deload"
        }
    }
}

extension ExerciseRole {
    var title: String {
        switch self {
        case .preparation: return "Preparation"
        case .main: return "Main"
        case .secondary: return "Secondary"
        case .accessory: return "Accessory"
        }
    }
}

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

    func apply(to plan: WorkoutPlan, using context: ModelContext) {
        plan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.goal = goal
        plan.experienceLevel = experienceLevel
        plan.requiredEquipment = Array(Set(requiredEquipment)).sorted { $0.rawValue < $1.rawValue }
        plan.scheduleMode = scheduleMode
        plan.scheduleIntervalDays = max(1, scheduleIntervalDays)
        plan.updatedAt = .now

        for blockDraft in blocks {
            guard let block = plan.orderedBlocks.first(where: { $0.id == blockDraft.id }) else { continue }
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

                let retainedIDs = Set(workoutDraft.exercises.compactMap(\.existingID))
                for existing in workout.plannedExercises where !retainedIDs.contains(existing.id) {
                    context.delete(existing)
                }

                workout.plannedExercises = workoutDraft.exercises.enumerated().map { index, draft in
                    if let existingID = draft.existingID,
                       let existing = workout.plannedExercises.first(where: { $0.id == existingID }) {
                        draft.apply(to: existing, orderIndex: index, using: context)
                        return existing
                    }
                    return draft.makeModel(orderIndex: index)
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
    let orderIndex: Int
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
    var exercises: [PlanExerciseDraft]

    init(workout: PlannedWorkout) {
        id = workout.id
        name = workout.name
        dayOffset = workout.dayOffset
        exercises = workout.orderedPlannedExercises.map(PlanExerciseDraft.init)
    }
}

@MainActor
struct PlanExerciseDraft: Identifiable {
    let id: UUID
    let existingID: UUID?
    var progressionKey: String
    var supersetGroupID: UUID?
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
    var initialTrainingMax: Double?
    var initialEstimatedOneRepMax: Double?
    var initialActualOneRepMax: Double?

    init(exercise: Exercise, orderIndex: Int) {
        id = UUID()
        existingID = nil
        progressionKey = UUID().uuidString
        supersetGroupID = nil
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
        stimulus = exercise.defaultTrainingStimulus
        alternatives = []
        plannedSets = []
        progressionRulesData = nil
        progressionWavesData = nil
        initialTrainingMax = nil
        initialEstimatedOneRepMax = nil
        initialActualOneRepMax = nil
    }

    init(plannedExercise: PlannedExercise) {
        id = plannedExercise.id
        existingID = plannedExercise.id
        progressionKey = plannedExercise.progressionKey
        supersetGroupID = plannedExercise.supersetGroupID
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

private extension Exercise {
    var defaultTrainingStimulus: TrainingStimulus {
        if category == .mobility || category == .flexibility { return .mobility }
        if trackingType.usesDuration && !trackingType.usesWeight { return .endurance }
        return .strength
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

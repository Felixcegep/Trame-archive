import SwiftData
import SwiftUI

@MainActor
struct PlanEditorDraft {
    var name: String
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var requiredEquipment: [EquipmentType]
    var blocks: [PlanBlockDraft]
    var weeks: [PlanWeekDraft]

    init(plan: WorkoutPlan) {
        name = plan.name
        goal = plan.goal
        experienceLevel = plan.experienceLevel
        requiredEquipment = plan.requiredEquipment
        blocks = plan.orderedBlocks.map(PlanBlockDraft.init)
        weeks = plan.orderedWeeks.map(PlanWeekDraft.init)
    }

    func apply(to plan: WorkoutPlan, using context: ModelContext) {
        plan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.goal = goal
        plan.experienceLevel = experienceLevel
        plan.requiredEquipment = Array(Set(requiredEquipment)).sorted { $0.rawValue < $1.rawValue }
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
                        draft.apply(to: existing, orderIndex: index)
                        return existing
                    }
                    return draft.makeModel(orderIndex: index)
                }
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

    init(exercise: Exercise, orderIndex: Int) {
        id = UUID()
        existingID = nil
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
    }

    init(plannedExercise: PlannedExercise) {
        id = plannedExercise.id
        existingID = plannedExercise.id
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
    }

    var summary: String {
        let load = suggestedLoadText.isEmpty ? "No suggested load" : "\(suggestedLoadText) \(suggestedLoadType == .kg ? "kg" : "lb")"
        return "\(targetSets) × \(repRangeMinimum)-\(repRangeMaximum) · \(load) · \(restSeconds)s rest"
    }

    var displayName: String {
        exercise.name
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
            progressionRule: progressionRule
        )
    }

    func apply(to model: PlannedExercise, orderIndex: Int) {
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

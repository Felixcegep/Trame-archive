//
//  Workout.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import SwiftData

@Model
class Workout {
    /// Stable cross-process identity for the workout represented by a Live Activity
    /// and for durable prescription evidence.
    var id = UUID()
    var status: WorkoutStatus = WorkoutStatus.active
    var nom: String?
    var notes: String?
    var startTime: Date
    var endTime: Date?
    var restEndDate: Date?
    var pausedRemainingTime: Double?
    var sourceTemplate: WorkoutTemplate?
    var sourcePlanID: UUID?
    var sourcePlanRunID: UUID?
    var sourcePlanBlockID: UUID?
    var sourcePlanWeekID: UUID?
    var sourcePlannedWorkoutID: UUID?
    var sourcePlanName: String?
    @Relationship(deleteRule: .cascade, inverse: \ExerciceEntry.workout)
    var exercises: [ExerciceEntry] = []
    
    init(nom: String?, endTime: Date? = nil) {
        self.status = endTime == nil ? .active : .completed
        self.nom = nom
        self.notes = nil
        self.startTime = Date.now
        self.endTime = endTime
        self.restEndDate = nil
        self.pausedRemainingTime = nil
        self.sourceTemplate = nil
        self.sourcePlanID = nil
        self.sourcePlanRunID = nil
        self.sourcePlanBlockID = nil
        self.sourcePlanWeekID = nil
        self.sourcePlannedWorkoutID = nil
        self.sourcePlanName = nil
    }
    init(template : WorkoutTemplate, unitSystem : UnitSystem){
        self.status = .active
        self.nom = template.name
        self.notes = nil
        self.startTime = Date.now
        self.restEndDate = nil
        self.pausedRemainingTime = nil
        self.sourceTemplate = template
        self.sourcePlanID = nil
        self.sourcePlanRunID = nil
        self.sourcePlanBlockID = nil
        self.sourcePlanWeekID = nil
        self.sourcePlannedWorkoutID = nil
        self.sourcePlanName = nil
        self.exercises = []
        for (index, templateExercise) in template.orderedTemplateExercises.enumerated() {
            exercises.append(ExerciceEntry(from: templateExercise, orderIndex: index, usedMetric: unitSystem))
        }
    }

    convenience init(plannedWorkout: PlannedWorkout, planRun: PlanRun, unitSystem: UnitSystem) {
        self.init(nom: plannedWorkout.name)
        self.sourceTemplate = plannedWorkout.sourceTemplate
        self.sourcePlanID = planRun.sourcePlanID
        self.sourcePlanRunID = planRun.id
        self.sourcePlanBlockID = plannedWorkout.week?.block?.id
        self.sourcePlanWeekID = plannedWorkout.week?.id
        self.sourcePlannedWorkoutID = plannedWorkout.id
        self.sourcePlanName = planRun.sourcePlanName

        self.exercises = []
        for (index, plannedExercise) in plannedWorkout.orderedPlannedExercises.enumerated() {
            exercises.append(ExerciceEntry(from: plannedExercise, orderIndex: index, usedMetric: unitSystem))
        }
    }

    /// Single source of truth for what a workout is called across the save
    /// flow, History list, and History detail: the explicit name when set,
    /// otherwise a title derived from its exercises.
    var displayTitle: String {
        let explicitName = nom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard explicitName.isEmpty else { return explicitName }

        let exerciseNames = orderedExercises.map(\.exercice.name)
        switch exerciseNames.count {
        case 0:
            return String(localized: "Workout")
        case 1:
            return exerciseNames[0]
        case 2:
            return "\(exerciseNames[0]) + \(exerciseNames[1])"
        default:
            return "\(exerciseNames[0]) + \(exerciseNames.count - 1) more"
        }
    }

    var orderedExercises: [ExerciceEntry] {
        exercises.sorted { lhs, rhs in
            lhs.orderIndex == rhs.orderIndex
                ? lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                : lhs.orderIndex < rhs.orderIndex
        }
    }

    func normalizeExerciseOrder() {
        for (index, exercise) in orderedExercises.enumerated() {
            exercise.orderIndex = index
            exercise.normalizeSetOrder()
        }
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    var incompleteSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { !$0.done }.count }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

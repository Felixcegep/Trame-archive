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

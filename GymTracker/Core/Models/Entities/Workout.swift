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
    var name: String?
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
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var exercises: [ExerciseEntry] = []
    
    init(name: String?, endTime: Date? = nil) {
        self.status = endTime == nil ? .active : .completed
        self.name = name
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
        self.name = template.name
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
        var snapshotGroupIDs: [UUID: UUID] = [:]
        for (index, templateExercise) in template.orderedTemplateExercises.enumerated() {
            let groupID: UUID?
            if let sourceID = templateExercise.supersetGroupID {
                if let existingID = snapshotGroupIDs[sourceID] {
                    groupID = existingID
                } else {
                    let freshID = UUID()
                    snapshotGroupIDs[sourceID] = freshID
                    groupID = freshID
                }
            } else {
                groupID = nil
            }
            exercises.append(
                ExerciseEntry(
                    from: templateExercise,
                    orderIndex: index,
                    usedMetric: unitSystem,
                    supersetGroupID: groupID
                )
            )
        }
    }

    convenience init(plannedWorkout: PlannedWorkout, planRun: PlanRun, unitSystem: UnitSystem) {
        self.init(name: plannedWorkout.name)
        self.sourceTemplate = plannedWorkout.sourceTemplate
        self.sourcePlanID = planRun.sourcePlanID
        self.sourcePlanRunID = planRun.id
        self.sourcePlanBlockID = plannedWorkout.week?.block?.id
        self.sourcePlanWeekID = plannedWorkout.week?.id
        self.sourcePlannedWorkoutID = plannedWorkout.id
        self.sourcePlanName = planRun.sourcePlanName

        self.exercises = []
        var snapshotGroupIDs: [UUID: UUID] = [:]
        for (index, plannedExercise) in plannedWorkout.orderedPlannedExercises.enumerated() {
            let groupID: UUID?
            if let sourceID = plannedExercise.supersetGroupID {
                if let existingID = snapshotGroupIDs[sourceID] {
                    groupID = existingID
                } else {
                    let freshID = UUID()
                    snapshotGroupIDs[sourceID] = freshID
                    groupID = freshID
                }
            } else {
                groupID = nil
            }
            let entry = ExerciseEntry(
                from: plannedExercise,
                orderIndex: index,
                usedMetric: unitSystem,
                supersetGroupID: groupID
            )
            PlanDeloadService.apply(to: entry, for: plannedWorkout.week?.block)
            exercises.append(entry)
        }
    }

    /// Single source of truth for what a workout is called across the save
    /// flow, History list, and History detail: the explicit name when set,
    /// otherwise a title derived from its exercises.
    var displayTitle: String {
        let explicitName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard explicitName.isEmpty else { return explicitName }

        let exerciseNames = orderedExercises.map(\.nameSnapshot)
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

    var orderedExercises: [ExerciseEntry] {
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
        SupersetGrouping.dissolveInvalidGroups(in: orderedExercises)
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

//
//  WorkoutTemplate.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import SwiftData
@Model
class WorkoutTemplate {
    var id = UUID()
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.workoutTemplate)
    var templateExercises: [TemplateExercise] = []
    @Relationship(deleteRule: .cascade, inverse: \TemplateExerciseBlock.workoutTemplate)
    var executionBlocks: [TemplateExerciseBlock] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutCollection.workoutTemplates)
    var workoutCollections: [WorkoutCollection] = []
    @Relationship(deleteRule: .nullify, inverse: \Workout.sourceTemplate)
    var sourceWorkouts: [Workout] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanSlot.workoutTemplate)
    var repeatingPlanSlots: [RepeatingPlanSlot] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanRunSlot.workoutTemplate)
    var repeatingPlanRunSlots: [RepeatingPlanRunSlot] = []
    var preWorkoutMobilityRoutine: MobilityRoutine?
    var postWorkoutMobilityRoutine: MobilityRoutine?
    var isBuiltIn: Bool = false
    var isArchived: Bool = false

    init(
        name: String,
        exercises: [Exercise],
        templateExercises: [TemplateExercise]? = nil,
        preWorkoutMobilityRoutine: MobilityRoutine? = nil,
        postWorkoutMobilityRoutine: MobilityRoutine? = nil,
        isBuiltIn: Bool = false,
        isArchived: Bool = false
    ) {
        self.name = name
        self.templateExercises = templateExercises ?? exercises.enumerated().map { index, exercise in
            TemplateExercise(exercise: exercise, order: index)
        }
        self.preWorkoutMobilityRoutine = preWorkoutMobilityRoutine
        self.postWorkoutMobilityRoutine = postWorkoutMobilityRoutine
        self.isBuiltIn = isBuiltIn
        self.isArchived = isArchived
    }

    var orderedTemplateExercises: [TemplateExercise] {
        templateExercises.sorted(by: { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.progressionKey < rhs.progressionKey
        })
    }

    var exercises: [Exercise] {
        orderedTemplateExercises.map(\.exercise)
    }

    var orderedExecutionBlocks: [TemplateExerciseBlock] {
        executionBlocks.sorted { $0.orderIndex < $1.orderIndex }
    }

    func normalizeTemplateExerciseOrder() {
        for (index, templateExercise) in orderedTemplateExercises.enumerated() {
            templateExercise.orderIndex = index
        }
        SupersetGrouping.dissolveInvalidGroups(in: orderedTemplateExercises)
    }
}

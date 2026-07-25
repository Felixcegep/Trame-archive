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
    var isBuiltIn: Bool = false

    init(
        name: String,
        exercises: [Exercise],
        templateExercises: [TemplateExercise]? = nil,
        isBuiltIn: Bool = false
    ) {
        self.name = name
        self.templateExercises = templateExercises ?? exercises.enumerated().map { index, exercise in
            TemplateExercise(exercise: exercise, order: index)
        }
        self.isBuiltIn = isBuiltIn
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

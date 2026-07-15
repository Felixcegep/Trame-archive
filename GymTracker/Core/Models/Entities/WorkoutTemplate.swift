//
//  WorkoutTemplate.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftData
@Model
class WorkoutTemplate {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.workoutTemplate)
    var templateExercises: [TemplateExercise] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutCollection.workoutTemplates)
    var workoutCollections: [WorkoutCollection] = []
    @Relationship(deleteRule: .nullify, inverse: \Workout.sourceTemplate)
    var sourceWorkouts: [Workout] = []

    init(
        name: String,
        exercises: [Exercise],
        templateExercises: [TemplateExercise]? = nil
    ) {
        self.name = name
        self.templateExercises = templateExercises ?? exercises.enumerated().map { index, exercise in
            TemplateExercise(exercise: exercise, order: index)
        }
    }

    var orderedTemplateExercises: [TemplateExercise] {
        templateExercises.sorted { lhs, rhs in
            lhs.orderIndex == rhs.orderIndex
                ? lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                : lhs.orderIndex < rhs.orderIndex
        }
    }

    var exercises: [Exercise] {
        orderedTemplateExercises.map(\.exercise)
    }

    func normalizeTemplateExerciseOrder() {
        for (index, templateExercise) in orderedTemplateExercises.enumerated() {
            templateExercise.orderIndex = index
        }
    }
}

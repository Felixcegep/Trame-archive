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
    @Relationship(deleteRule: .nullify, inverse: \ExerciceTemplate.workoutTemplates)
    var exercises: [ExerciceTemplate]
    @Relationship(deleteRule: .nullify, inverse: \WorkoutPlan.workoutTemplates)
    var workoutPlans: [WorkoutPlan] = []
    @Relationship(deleteRule: .nullify, inverse: \Workout.sourceTemplate)
    var sourceWorkouts: [Workout] = []

    init(name: String, exercises: [ExerciceTemplate]) {
        self.name = name
        self.exercises = exercises
    }
}

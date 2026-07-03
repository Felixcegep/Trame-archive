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
    var exercises: [ExerciceTemplate]
    init(name: String, exercises: [ExerciceTemplate]) {
        self.name = name
        self.exercises = exercises
    }
}

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
    var nom: String?
    var notes: String?
    var startTime: Date
    var endTime: Date?
    var sourceTemplate: WorkoutTemplate?
    var exercises: [ExerciceEntry] = []
    
    init(nom: String?, endTime: Date? = nil) {
        self.nom = nom
        self.notes = nil
        self.startTime = Date.now
        self.endTime = endTime
        self.sourceTemplate = nil
    }
    init(template : WorkoutTemplate, unitSystem : UnitSystem){
        self.nom = template.name
        self.notes = nil
        self.startTime = Date.now
        self.sourceTemplate = template
        self.exercises = []
        let prescribedExercises = template.templateExercises.sorted { $0.order < $1.order }

        if prescribedExercises.isEmpty {
            for exerciceTemplate in template.exercises {
                exercises.append(ExerciceEntry(from: exerciceTemplate, usedMetric: unitSystem))
            }
        } else {
            for templateExercise in prescribedExercises {
                exercises.append(ExerciceEntry(from: templateExercise, usedMetric: unitSystem))
            }
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

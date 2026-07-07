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
    var startTime: Date
    var endTime: Date?
    var exercises: [ExerciceEntry] = []
    
    init(nom: String?,endTime: Date? = nil) {
        self.startTime = Date.now
    }
    init(template : WorkoutTemplate){
        self.startTime = Date.now
        self.exercises = []
        for exerciceTemplate in template.exercises{
            let exercises = ExerciceEntry(from : exerciceTemplate)
            self.exercises.append(exercises)
        }
        
    }
}




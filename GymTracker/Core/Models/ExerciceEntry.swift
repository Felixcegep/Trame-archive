//
//  ExerciceEntry.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import Combine
import SwiftData

@Model
class ExerciceEntry{
    var Comment : String?
    var exercice : ExerciceTemplate
    var sets : [ExerciseSet]
    init(Comment: String? = nil, exercice: ExerciceTemplate, sets: [ExerciseSet] = []) {
        self.Comment = Comment
        self.exercice = exercice
        self.sets = sets
    }
    init (from: ExerciceTemplate){
        
        self.exercice = from
        self.sets = []
    }

    
}

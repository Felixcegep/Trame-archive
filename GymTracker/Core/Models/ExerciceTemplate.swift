//
//  Exercice.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftData

@Model
class ExerciceTemplate {
    var name: String
    var PrimaryMuscle: [Muscle]
    var SecondaryMuscle: [Muscle]?
    init(name: String, PrimaryMuscle: [Muscle], SecondaryMuscle: [Muscle]? = nil) {
        self.name = name
        self.PrimaryMuscle = PrimaryMuscle
        self.SecondaryMuscle = SecondaryMuscle
    }
}


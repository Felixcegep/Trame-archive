//
//  Set.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//


import Combine
import Foundation
import SwiftData

@Model
class ExerciseSet {
    var weightType : WeightType
    var repetition : Float
    var weight : Float
    var done : Bool = false
    
    init(repetition: Float, weight: Float) {
        self.repetition = repetition
        self.weight = weight
        self.weightType = .kg
        done = false
    }
    init () {
        repetition = 0
        weight = 0
        weightType = .kg
        done = false
    }
    func copy() -> ExerciseSet {
        return ExerciseSet(repetition: repetition, weight: weight)
    }
    
}

enum WeightType : String, Codable {
    case kg
    case lbs
}

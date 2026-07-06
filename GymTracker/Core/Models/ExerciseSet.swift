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
final class ExerciseSet {
    var weightType: WeightType = WeightType.kg
    var distanceType: DistanceType = DistanceType.kilometers
    var repetition: Float
    var weight: Float
    var duration: TimeInterval?
    var distance: Float?
    var done: Bool = false
    
    init(
        repetition: Float = 0,
        weight: Float = 0,
        duration: TimeInterval? = nil,
        distance: Float? = nil,
        weightType: WeightType = .kg,
        distanceType: DistanceType = .kilometers,
        done: Bool = false
    ) {
        self.repetition = repetition
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.weightType = weightType
        self.distanceType = distanceType
        self.done = done
    }

    func copy() -> ExerciseSet {
        return ExerciseSet(
            repetition: repetition,
            weight: weight,
            duration: duration,
            distance: distance,
            weightType: weightType,
            distanceType: distanceType,
            done: false
        )
    }
    
}

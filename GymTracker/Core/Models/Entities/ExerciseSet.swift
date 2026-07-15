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
    var orderIndex: Int = 0
    var weightType: WeightType = WeightType.kg
    var distanceType: DistanceType = DistanceType.kilometers
    var repetitions: Float
    var weight: Float
    var duration: TimeInterval?
    var distance: Float?
    var done: Bool = false
    var rpe: Int?
    var setType: SetType = SetType.normal
    var usedMetric : UnitSystem
    var exerciseEntry: ExerciseEntry?
    init(
        repetitions: Float = 0,
        weight: Float = 0,
        duration: TimeInterval? = nil,
        distance: Float? = nil,
        
        
        done: Bool = false,
        rpe: Int? = nil,
        setType: SetType = .normal,
        orderIndex: Int = 0,
        usedMetric : UnitSystem
    ) {
        self.orderIndex = orderIndex
        self.weightType = usedMetric == .metric ? .kg : .lbs
        self.distanceType = usedMetric == .metric ? .kilometers : .miles
        self.repetitions = repetitions
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.done = done
        self.rpe = rpe
        self.setType = setType
        self.usedMetric = usedMetric
    }

    func copy() -> ExerciseSet {
        return ExerciseSet(
            repetitions: repetitions,
            weight: weight,
            duration: duration,
            distance: distance,
            
            
            done: false,
            rpe: rpe,
            setType: setType,
            orderIndex: 0,
            usedMetric: usedMetric
        )
    }

    func displayText() -> String {
        if let duration = duration, duration > 0 {
            if let distance = distance, distance > 0 {
                return String(format: "%ds @ %.2f %@", Int(duration), distance, distanceType.rawValue)
            }
            return "\(Int(duration))s"
        }

        if weight > 0 {
            return "\(Int(repetitions)) x \(String(format: "%.1f", weight)) \(weightType.rawValue)"
        }

        return "\(Int(repetitions)) reps"
    }
}

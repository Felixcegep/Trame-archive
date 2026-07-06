//
//  Exercice.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftData

@Model
final class ExerciceTemplate {
    var name: String
    var PrimaryMuscle: [Muscle]
    var SecondaryMuscle: [Muscle]?
    var trackingType: TrackingType = TrackingType.weightAndReps
    var equipmentType: EquipmentType = EquipmentType.other
    var tags: [String] = []

    init(
        name: String,
        PrimaryMuscle: [Muscle],
        SecondaryMuscle: [Muscle]? = nil,
        trackingType: TrackingType = .weightAndReps,
        equipmentType: EquipmentType = .other,
        tags: [String] = []
    ) {
        self.name = name
        self.PrimaryMuscle = PrimaryMuscle
        self.SecondaryMuscle = SecondaryMuscle
        self.trackingType = trackingType
        self.equipmentType = equipmentType
        self.tags = tags
    }
}

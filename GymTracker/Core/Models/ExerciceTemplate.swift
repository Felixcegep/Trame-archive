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
    var category: ExerciseCategory = ExerciseCategory.strength
    var trackingType: TrackingType = TrackingType.weightAndReps
    var equipmentType: EquipmentType? = EquipmentType.other
    var resistanceType: ResistanceType?
    var movementPattern: MovementPattern?
    var difficulty: Difficulty = Difficulty.beginner
    var tags: [String] = []

    init(
        name: String,
        PrimaryMuscle: [Muscle],
        SecondaryMuscle: [Muscle]? = nil,
        category: ExerciseCategory = .strength,
        trackingType: TrackingType = .weightAndReps,
        equipmentType: EquipmentType? = .other,
        resistanceType: ResistanceType? = nil,
        movementPattern: MovementPattern? = nil,
        difficulty: Difficulty = .beginner,
        tags: [String] = []
    ) {
        self.name = name
        self.PrimaryMuscle = PrimaryMuscle
        self.SecondaryMuscle = SecondaryMuscle
        self.category = category
        self.trackingType = trackingType
        self.equipmentType = equipmentType ?? .other
        self.resistanceType = resistanceType
        self.movementPattern = movementPattern
        self.difficulty = difficulty
        self.tags = tags
    }
}

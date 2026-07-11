//
//  Exercice.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import SwiftData

@Model
final class ExerciceTemplate {
    var name: String
    var PrimaryMuscle: [Muscle]
    var SecondaryMuscle: [Muscle]?
    var category: ExerciseCategory?
    var trackingType: TrackingType = TrackingType.weightAndReps
    var equipmentType: EquipmentType? = EquipmentType.other
    var resistanceType: ResistanceType?
    var movementPattern: MovementPattern?
    var difficulty: Difficulty?
    var tags: [String] = []
    var isFavorite: Bool = false
    var workoutTemplates: [WorkoutTemplate] = []

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
        tags: [String] = [],
        isFavorite: Bool = false
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
        self.isFavorite = isFavorite
    }

    var displayCategory: ExerciseCategory {
        category ?? .strength
    }

    var displayDifficulty: Difficulty {
        difficulty ?? .beginner
    }

    var subtitle: String {
        let muscle = PrimaryMuscle.first?.displayName ?? NSLocalizedString("General", comment: "")
        let equipment = NSLocalizedString(equipmentType?.rawValue ?? "Other", comment: "")
        let tracking = NSLocalizedString(trackingType.rawValue, comment: "")
        return "\(muscle) · \(equipment) · \(tracking)"
    }
}

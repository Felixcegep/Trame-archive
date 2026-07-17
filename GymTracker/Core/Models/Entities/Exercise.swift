//
//  Exercise.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var primaryMuscles: [Muscle]
    var secondaryMuscles: [Muscle]?
    var category: ExerciseCategory?
    var trackingType: TrackingType = TrackingType.weightAndReps
    var equipmentType: EquipmentType? = EquipmentType.other
    var resistanceType: ResistanceType?
    var movementPattern: MovementPattern?
    var forceType: ForceType?
    var mechanics: ExerciseMechanics?
    var difficulty: Difficulty?
    var tags: [String] = []
    var isFavorite: Bool = false
    var isPlateLoaded: Bool = false
    var isCustom: Bool = false
    var isArchived: Bool = false
    var laterality: Laterality = Laterality.bilateral
    var repCountingStyle: RepCountingStyle = RepCountingStyle.total
    var weightEntryStyle: WeightEntryStyle = WeightEntryStyle.totalLoad
    var loadUnitCount: Int = 1

    init(
        name: String,
        primaryMuscles: [Muscle],
        secondaryMuscles: [Muscle]? = nil,
        category: ExerciseCategory = .strength,
        trackingType: TrackingType = .weightAndReps,
        equipmentType: EquipmentType? = .other,
        resistanceType: ResistanceType? = nil,
        movementPattern: MovementPattern? = nil,
        forceType: ForceType? = nil,
        mechanics: ExerciseMechanics? = nil,
        difficulty: Difficulty = .beginner,
        tags: [String] = [],
        isFavorite: Bool = false,
        isPlateLoaded: Bool? = nil,
        isCustom: Bool = false,
        isArchived: Bool = false,
        laterality: Laterality = .bilateral,
        repCountingStyle: RepCountingStyle = .total,
        weightEntryStyle: WeightEntryStyle = .totalLoad,
        loadUnitCount: Int = 1
    ) {
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.category = category
        self.trackingType = trackingType
        self.equipmentType = equipmentType ?? .other
        self.resistanceType = resistanceType
        self.movementPattern = movementPattern
        self.forceType = forceType
        self.mechanics = mechanics
        self.difficulty = difficulty
        self.tags = tags
        self.isFavorite = isFavorite
        self.isPlateLoaded = isPlateLoaded ?? (equipmentType == .barbell)
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.laterality = laterality
        self.repCountingStyle = repCountingStyle
        self.weightEntryStyle = weightEntryStyle
        self.loadUnitCount = loadUnitCount
    }

    var displayCategory: ExerciseCategory {
        category ?? .strength
    }

    var displayDifficulty: Difficulty {
        difficulty ?? .beginner
    }

    var subtitle: String {
        let muscle = primaryMuscles.first?.displayName ?? NSLocalizedString("General", comment: "")
        let equipment = NSLocalizedString(equipmentType?.rawValue ?? "Other", comment: "")
        let tracking = NSLocalizedString(trackingType.rawValue, comment: "")
        return "\(muscle) · \(equipment) · \(tracking)"
    }

    var supportsPlateCalculator: Bool {
        trackingType.usesWeight && (equipmentType == .barbell || isPlateLoaded)
    }

    var loggingSemantics: LoggingSemantics {
        LoggingSemantics(
            laterality: laterality,
            repCountingStyle: repCountingStyle,
            weightEntryStyle: weightEntryStyle,
            loadUnitCount: loadUnitCount
        )
    }
}

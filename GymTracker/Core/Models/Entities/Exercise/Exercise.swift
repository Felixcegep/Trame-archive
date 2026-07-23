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
    /// Stable external identity for program definitions and backup links.
    var id = UUID()
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
    var gripStyle: GripStyle?
    var stance: ExerciseStance?
    var rangeOfMotion: RangeOfMotion?
    var setupAngleDegrees: Int?
    var variationFamilyID: String?
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
    var searchAliases: [String] = []
    var frenchName: String?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseRelationship.sourceExercise)
    var outgoingRelationships: [ExerciseRelationship] = []
    @Relationship(deleteRule: .cascade, inverse: \ExerciseRelationship.targetExercise)
    var incomingRelationships: [ExerciseRelationship] = []

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
        gripStyle: GripStyle? = nil,
        stance: ExerciseStance? = nil,
        rangeOfMotion: RangeOfMotion? = nil,
        setupAngleDegrees: Int? = nil,
        variationFamilyID: String? = nil,
        difficulty: Difficulty = .beginner,
        tags: [String] = [],
        isFavorite: Bool = false,
        isPlateLoaded: Bool? = nil,
        isCustom: Bool = false,
        isArchived: Bool = false,
        laterality: Laterality = .bilateral,
        repCountingStyle: RepCountingStyle = .total,
        weightEntryStyle: WeightEntryStyle = .totalLoad,
        loadUnitCount: Int = 1,
        id: UUID = UUID()
    ) {
        self.id = id
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
        self.gripStyle = gripStyle
        self.stance = stance
        self.rangeOfMotion = rangeOfMotion
        self.setupAngleDegrees = setupAngleDegrees
        self.variationFamilyID = variationFamilyID
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

extension Sequence where Element == Exercise {
    /// Orders exercises so a name-keyed lookup can safely take the first
    /// match per name. A custom exercise may legitimately share a built-in
    /// one's display name (backups preserve both as distinct records via
    /// their own ids), so system-content resolution — seeded plans,
    /// templates, relationships, and program imports — must always resolve
    /// a shared name to the canonical system definition, never a user's
    /// same-named custom record.
    func uniquedByNamePreferringSystem() -> [Exercise] {
        sorted { !$0.isCustom && $1.isCustom }
    }
}

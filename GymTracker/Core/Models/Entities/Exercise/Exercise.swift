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
    var catalogueKey: String? = nil
    var name: String
    var primaryMuscles: [Muscle]
    var secondaryMuscles: [Muscle]?
    var category: ExerciseCategory?
    var trackingType: TrackingType = TrackingType.weightAndReps
    var equipmentType: EquipmentType? = EquipmentType.other
    var resistanceType: ResistanceType?
    var movementPattern: MovementPattern?
    var movementPatterns: [MovementPattern] = []
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
    /// Explicit sport discipline authored for this exercise. `nil` for every
    /// exercise created before this field existed and for any exercise an
    /// author has not classified — `resolvedSportDiscipline` (see
    /// `SportCapabilityTypes.swift`) derives a default from `trackingType`/
    /// `category` in that case, matching this exercise's pre-existing
    /// behavior exactly.
    var sportDisciplineRaw: String?
    /// Present only when `sportDisciplineRaw == "strongman"`. Governs which
    /// `SportAnalyticsPolicy` is resolved for this exercise (carry vs. hold
    /// vs. other event families).
    var strongmanEventFamilyRaw: String?
    /// Catalog-level default `StrongmanImplementProfile`, encoded. Every
    /// performed set keeps its own independent snapshot
    /// (`ExerciseSet.strongmanImplementProfileData`) captured at log time, so
    /// editing this later never rewrites completed history.
    var strongmanImplementProfileData: Data?
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
        movementPatterns: [MovementPattern] = [],
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
        if !movementPatterns.isEmpty {
            self.movementPatterns = movementPatterns
            self.movementPattern = movementPattern ?? movementPatterns.first
        } else if let movementPattern {
            self.movementPatterns = [movementPattern]
            self.movementPattern = movementPattern
        } else {
            self.movementPatterns = []
            self.movementPattern = nil
        }
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

    var displayMovementPatterns: [MovementPattern] {
        if !movementPatterns.isEmpty {
            return movementPatterns
        }
        if let movementPattern {
            return [movementPattern]
        }
        return []
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
    /// Returns one exercise per exact display name, preferring the canonical
    /// system definition when a custom exercise shares that name.
    func uniquedByNamePreferringSystem() -> [Exercise] {
        var namesInOrder: [String] = []
        var exerciseByName: [String: Exercise] = [:]

        for exercise in self {
            if let existing = exerciseByName[exercise.name] {
                if existing.isCustom && !exercise.isCustom {
                    exerciseByName[exercise.name] = exercise
                }
            } else {
                namesInOrder.append(exercise.name)
                exerciseByName[exercise.name] = exercise
            }
        }

        return namesInOrder.compactMap { exerciseByName[$0] }
    }
}

//
//  ExerciseTypes.swift
//  GymTracker
//

import Foundation

enum EquipmentType: String, Codable, CaseIterable, Hashable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case kettlebell = "Kettlebell"
    case medicineBall = "Medicine Ball"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case cardioMachine = "Cardio Machine"
    case other = "Other"
}

enum ResistanceType: String, Codable, CaseIterable {
    case externalWeight = "External Weight"
    case bodyweight = "Bodyweight"
    case assistedBodyweight = "Assisted Bodyweight"
    case weightedBodyweight = "Weighted Bodyweight"
    case elastic = "Elastic"
    case machine = "Machine"
    case none = "None"
    case other = "Other"
}

enum MovementPattern: String, Codable, CaseIterable {
    case horizontalPush = "Horizontal Push"
    case verticalPush = "Vertical Push"
    case horizontalPull = "Horizontal Pull"
    case verticalPull = "Vertical Pull"
    case squat = "Squat"
    case hinge = "Hinge"
    case lunge = "Lunge"
    case carry = "Carry"
    case rotation = "Rotation"
    case antiRotation = "Anti-Rotation"
    case antiExtension = "Anti-Extension"
    case antiLateralFlexion = "Anti-Lateral Flexion"
    case locomotion = "Locomotion"
    case other = "Other"
}

enum Difficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Strength"
    case cardio = "Cardio"
    case mobility = "Mobility"
    case flexibility = "Flexibility"
    case balance = "Balance"
    case sport = "Sport"
    case other = "Other"
}

enum TrackingType: String, Codable, CaseIterable {
    case weightAndReps = "Weight & Reps"
    case repsOnly = "Reps Only"
    case weightedBodyweight = "Weighted Bodyweight"
    case assistedBodyweight = "Assisted Bodyweight"
    case duration = "Duration"
    case durationAndDistance = "Duration & Distance"
    case calories = "Calories"

    var usesWeight: Bool {
        switch self {
        case .weightAndReps, .weightedBodyweight, .assistedBodyweight:
            return true
        case .repsOnly, .duration, .durationAndDistance, .calories:
            return false
        }
    }

    var usesReps: Bool {
        switch self {
        case .weightAndReps, .repsOnly, .weightedBodyweight, .assistedBodyweight:
            return true
        case .duration, .durationAndDistance, .calories:
            return false
        }
    }

    var usesDuration: Bool {
        switch self {
        case .duration, .durationAndDistance:
            return true
        case .weightAndReps, .repsOnly, .weightedBodyweight, .assistedBodyweight, .calories:
            return false
        }
    }

    var usesDistance: Bool {
        self == .durationAndDistance
    }

    var usesCalories: Bool {
        self == .calories
    }
}

enum GripStyle: String, Codable, CaseIterable {
    case pronated = "Pronated"
    case supinated = "Supinated"
    case neutral = "Neutral"
    case mixed = "Mixed"
}

enum ExerciseStance: String, Codable, CaseIterable {
    case standing = "Standing"
    case seated = "Seated"
    case kneeling = "Kneeling"
    case split = "Split"
    case staggered = "Staggered"
    case supine = "Supine"
    case prone = "Prone"
}

enum RangeOfMotion: String, Codable, CaseIterable {
    case full = "Full"
    case partial = "Partial"
    case extended = "Extended"
}

enum ExerciseRelationshipType: String, Codable, CaseIterable, Identifiable {
    case substitution = "Substitution"
    case progression = "Progression"
    case regression = "Regression"

    var id: Self { self }

    var actionTitle: String {
        switch self {
        case .substitution:
            "Substitution"
        case .progression:
            "Progression"
        case .regression:
            "Regression"
        }
    }
}

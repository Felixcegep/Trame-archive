//
//  TrackingType.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-06.
//

enum TrackingType: String, Codable, CaseIterable {
    case weightAndReps = "Weight & Reps"
    case repsOnly = "Reps Only"
    case weightedBodyweight = "Weighted Bodyweight"
    case assistedBodyweight = "Assisted Bodyweight"
    case duration = "Duration"
    case durationAndDistance = "Duration & Distance"

    var usesWeight: Bool {
        switch self {
        case .weightAndReps, .weightedBodyweight, .assistedBodyweight:
            return true
        case .repsOnly, .duration, .durationAndDistance:
            return false
        }
    }

    var usesReps: Bool {
        switch self {
        case .weightAndReps, .repsOnly, .weightedBodyweight, .assistedBodyweight:
            return true
        case .duration, .durationAndDistance:
            return false
        }
    }

    var usesDuration: Bool {
        switch self {
        case .duration, .durationAndDistance:
            return true
        case .weightAndReps, .repsOnly, .weightedBodyweight, .assistedBodyweight:
            return false
        }
    }

    var usesDistance: Bool {
        self == .durationAndDistance
    }
}

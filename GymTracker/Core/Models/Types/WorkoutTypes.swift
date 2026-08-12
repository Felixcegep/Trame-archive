//
//  WorkoutTypes.swift
//  GymTracker
//

import Foundation

enum WorkoutStatus: String, Codable {
    case active
    case completed
}

enum SetType: String, Codable, CaseIterable {
    case warmup
    case normal
    case dropSet
    case failure
    case backoff
    case topSet
    case amrap
    case technique
    case dailyMaximum
    case test
    case recovery

    var title: String {
        switch self {
        case .warmup: String(localized: "Warm-up")
        case .normal: String(localized: "Normal")
        case .dropSet: String(localized: "Drop set")
        case .failure: String(localized: "Failure")
        case .backoff: String(localized: "Back-off")
        case .topSet: String(localized: "Top set")
        case .amrap: String(localized: "AMRAP")
        case .technique: String(localized: "Technique")
        case .dailyMaximum: String(localized: "Daily maximum")
        case .test: String(localized: "Test")
        case .recovery: String(localized: "Recovery")
        }
    }

    var shortLabel: String? {
        switch self {
        case .normal: nil
        case .warmup: "W"
        case .dropSet: "D"
        case .failure: "F"
        case .backoff: "B"
        case .topSet: "T"
        case .amrap: "A"
        // Not "T": that is the top set, and a top set is close to the opposite
        // of a technique set — the heaviest thing in the session versus a
        // deliberately light one. Two set types cannot share a badge.
        case .technique: "Q"
        case .dailyMaximum: "M"
        case .test: "X"
        case .recovery: "R"
        }
    }
}

enum LiftQuality: String, Codable, CaseIterable, Hashable {
    case excellent
    case acceptable
    case technicallyPoor
    case missed

    var title: String {
        switch self {
        case .excellent: String(localized: "Excellent")
        case .acceptable: String(localized: "Acceptable")
        case .technicallyPoor: String(localized: "Technically poor")
        case .missed: String(localized: "Missed")
        }
    }
}

nonisolated enum WeightType: String, Codable, CaseIterable, Sendable {
    case kg
    case lbs
}

nonisolated enum DistanceType: String, Codable, CaseIterable, Sendable {
    case meters
    case kilometers
    case miles

    nonisolated var symbol: String {
        switch self {
        case .meters: "m"
        case .kilometers: "km"
        case .miles: "mi"
        }
    }
}

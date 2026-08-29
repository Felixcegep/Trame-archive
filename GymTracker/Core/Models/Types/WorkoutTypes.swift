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
    /// Held flexibility work performed inside a gym session — a duration set
    /// that is neither a warm-up nor a competitive effort. A full mobility
    /// session remains its own domain; this is the single stretch a lifter
    /// slots between working sets.
    case stretch

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
        case .stretch: String(localized: "Stretch")
        }
    }

    /// Roles that stay visible in performed history but never feed strength
    /// volume, records, e1RM, or progression metrics.
    var isStrengthAnalyticsExcluded: Bool {
        self == .warmup || self == .stretch
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

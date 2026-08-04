//
//  CoreTypes.swift
//  GymTracker
//

import Foundation

nonisolated enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case metric
    case imperial
}

enum ExerciseMechanics: String, Codable, CaseIterable {
    case compound = "Compound"
    case isolation = "Isolation"
}

enum ForceType: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case staticHold = "Static"
    case mixed = "Mixed"
}

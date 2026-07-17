//
//  ClassificationTypes.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-17.
//

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

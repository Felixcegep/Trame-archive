//
//  Muscle.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

enum Muscle: String, Codable, CaseIterable {

    // MARK: - Upper Body

    // Chest
    case upperChest
    case middleChest
    case lowerChest

    // Shoulders
    case frontDeltoid
    case lateralDeltoid
    case rearDeltoid

    // Arms
    case bicep
    case brachialis
    case brachioradialis

    case tricepLongHead
    case tricepLateralHead
    case tricepMedialHead

    // Back
    case latissimusDorsi
    case trapezius
    case rhomboids
    case teresMajor

    // Forearms
    case forearms

    // MARK: - Core

    case rectusAbdominis
    case obliques
    case transverseAbdominis

    // MARK: - Lower Body

    // Glutes
    case gluteMaximus
    case gluteMedius
    case gluteMinimus

    // Legs
    case quadriceps
    case hamstrings
    case adductors
    case abductors
    case calves
    case tibialisAnterior

    // MARK: - Lower Back

    case erectorSpinae

    // MARK: - Other

    case neck
}




//
//  Muscle.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation

nonisolated enum Muscle: String, Codable, CaseIterable, Sendable {
    

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

extension Muscle {
    nonisolated enum Group: String, CaseIterable, Sendable {
        case chest = "Chest"
        case shoulders = "Shoulders"
        case arms = "Arms"
        case back = "Back"
        case core = "Core"
        case glutes = "Glutes"
        case legs = "Legs"
        case other = "Other Muscles"

        nonisolated var muscles: [Muscle] {
            Muscle.allCases.filter { $0.group == self }
        }
    }

    nonisolated var group: Group {
        switch self {
        case .upperChest, .middleChest, .lowerChest:
            return .chest
        case .frontDeltoid, .lateralDeltoid, .rearDeltoid:
            return .shoulders
        case .bicep, .brachialis, .brachioradialis,
             .tricepLongHead, .tricepLateralHead, .tricepMedialHead, .forearms:
            return .arms
        case .latissimusDorsi, .trapezius, .rhomboids, .teresMajor, .erectorSpinae:
            return .back
        case .rectusAbdominis, .obliques, .transverseAbdominis:
            return .core
        case .gluteMaximus, .gluteMedius, .gluteMinimus:
            return .glutes
        case .quadriceps, .hamstrings, .adductors, .abductors, .calves, .tibialisAnterior:
            return .legs
        case .neck:
            return .other
        }
    }
}

extension Muscle {
    nonisolated private static let displayNames: [Muscle: String] = {
        Dictionary(uniqueKeysWithValues: allCases.map { muscle in
            let name = muscle.rawValue.reduce("") { result, character in
                if character.isUppercase {
                    return result + " " + String(character)
                }
                return result + String(character)
            }
            .capitalized
            return (muscle, NSLocalizedString(name, comment: ""))
        })
    }()

    nonisolated var displayName: String {
        Self.displayNames[self] ?? rawValue
    }
}

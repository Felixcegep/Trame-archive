//
//  LoggingTypes.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-17.
//

enum Laterality: String, Codable, CaseIterable {
    case bilateral = "Bilateral"
    case unilateral = "Unilateral"
}

enum RepCountingStyle: String, Codable, CaseIterable {
    case total = "Total"
    case perSide = "Per Side"
}

enum WeightEntryStyle: String, Codable, CaseIterable {
    case totalLoad = "Total Load"
    case perLoadUnit = "Per Load Unit"
}

/// Derived multipliers that turn a single logged set (one weight, one rep count)
/// into true training volume, accounting for unilateral per-side reps and
/// per-hand/per-unit loads like dumbbells.
struct LoggingSemantics: Equatable, Sendable {
    var laterality: Laterality
    var repCountingStyle: RepCountingStyle
    var weightEntryStyle: WeightEntryStyle
    var loadUnitCount: Int

    static let `default` = LoggingSemantics(
        laterality: .bilateral,
        repCountingStyle: .total,
        weightEntryStyle: .totalLoad,
        loadUnitCount: 1
    )

    /// Reps logged per side already account for both limbs, so volume needs an
    /// extra ×2 to reflect total work performed across a full set.
    var sideMultiplier: Float {
        laterality == .unilateral && repCountingStyle == .perSide ? 2 : 1
    }

    /// Weight logged per unit (e.g. one dumbbell) needs multiplying by the
    /// number of units actually loaded to reach true total load.
    var loadMultiplier: Float {
        weightEntryStyle == .perLoadUnit ? Float(loadUnitCount) : 1
    }
}

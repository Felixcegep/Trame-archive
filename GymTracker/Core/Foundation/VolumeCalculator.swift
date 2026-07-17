import Foundation

/// Single source of truth for turning a logged set (weight × reps) into true
/// training volume once laterality and per-unit loading are accounted for.
///
/// Estimated-1RM and load-record PRs deliberately do NOT go through this
/// calculator: a personal best for a dumbbell exercise is the per-hand
/// number a lifter actually moved, not tonnage doubled across both hands.
enum VolumeCalculator {
    static func setVolume(
        weight: Float,
        weightType: WeightType,
        repetitions: Float,
        semantics: LoggingSemantics,
        in unit: WeightType
    ) -> Float {
        let convertedWeight = UnitConversion.weight(weight, from: weightType, to: unit)
        return convertedWeight * repetitions * semantics.sideMultiplier * semantics.loadMultiplier
    }
}

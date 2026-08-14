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
        // Persisted legacy data can predate the completion validator.  An
        // invalid scalar must not poison an entire chart/reduction with NaN
        // or infinity, and non-positive load/repetition values are not a
        // completed volume contribution.
        guard weight.isFinite,
              repetitions.isFinite,
              weight > 0,
              repetitions > 0
        else { return 0 }
        let convertedWeight = UnitConversion.weight(weight, from: weightType, to: unit)
        guard convertedWeight.isFinite else { return 0 }
        let volume = convertedWeight * repetitions * semantics.sideMultiplier * semantics.loadMultiplier
        return volume.isFinite && volume > 0 ? volume : 0
    }
}

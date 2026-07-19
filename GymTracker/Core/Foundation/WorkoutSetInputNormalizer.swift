import Foundation

/// Normalizes editable active-workout input to the user's preferred units.
///
/// Completed sets are historical evidence. They must never be rewritten as a
/// side effect of rendering an active-workout row or changing preferences.
enum WorkoutSetInputNormalizer {
    @discardableResult
    static func synchronize(_ set: ExerciseSet, to preferredSystem: UnitSystem) -> Bool {
        guard !set.done else { return false }

        let preferredWeightType: WeightType = preferredSystem == .metric ? .kg : .lbs
        let preferredDistanceType: DistanceType = preferredSystem == .metric ? .kilometers : .miles
        var didChange = false

        if set.weightType != preferredWeightType {
            set.weight = UnitConversion.weight(
                set.weight,
                from: set.weightType,
                to: preferredWeightType
            )
            set.weightType = preferredWeightType
            didChange = true
        }

        if set.distanceType != preferredDistanceType {
            if let distance = set.distance {
                set.distance = UnitConversion.distance(
                    distance,
                    from: set.distanceType,
                    to: preferredDistanceType
                )
            }
            set.distanceType = preferredDistanceType
            didChange = true
        }

        if set.usedMetric != preferredSystem {
            set.usedMetric = preferredSystem
            didChange = true
        }

        return didChange
    }
}

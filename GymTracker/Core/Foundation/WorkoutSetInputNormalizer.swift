import Foundation

/// Normalizes editable active-workout input to the user's preferred units.
///
/// Completed sets are historical evidence. They must never be rewritten as a
/// side effect of rendering an active-workout row or changing preferences.
enum WorkoutSetInputNormalizer {
    /// - Parameter loadIncrement: the jump the exercise's equipment makes in
    ///   the preferred unit. Supplied by the caller rather than derived here so
    ///   this stays a pure unit utility with no catalogue dependency — it is
    ///   compiled into the widget extension, which does not include the
    ///   Program Engine. When it is `nil` the converted weight is left exactly
    ///   as the conversion produced it, which is the previous behaviour.
    @discardableResult
    static func synchronize(
        _ set: ExerciseSet,
        to preferredSystem: UnitSystem,
        loadIncrement: Double? = nil
    ) -> Bool {
        guard !set.done else { return false }

        let preferredWeightType: WeightType = preferredSystem == .metric ? .kg : .lbs
        let preferredDistanceType: DistanceType = preferredSystem == .metric ? .kilometers : .miles
        var didChange = false

        if set.weightType != preferredWeightType {
            let converted = UnitConversion.weight(
                set.weight,
                from: set.weightType,
                to: preferredWeightType
            )
            // A converted load is otherwise unloadable: 50 kg arrives as
            // 110.231 lb, and every later ± press inherits the remainder.
            set.weight = snapped(converted, to: loadIncrement)
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

    private static func snapped(_ value: Float, to increment: Double?) -> Float {
        guard value.isFinite, let increment, increment > 0 else { return value }
        return Float((Double(value) / increment).rounded() * increment)
    }
}

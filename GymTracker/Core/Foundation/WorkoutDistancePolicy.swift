import Foundation

nonisolated struct DistanceMeasurement: Equatable, Sendable {
    let value: Float
    let unit: DistanceType
}

/// Authoritative value-layer interpretation of workout distance.
///
/// Existing rows remain value + `distanceType` evidence. New writes use metres
/// with `.meters`; callers must always cross this policy rather than assuming
/// the stored number already uses a particular display unit.
nonisolated enum WorkoutDistancePolicy {
    nonisolated static func meters(storedValue: Float, storedUnit: DistanceType) -> Float {
        UnitConversion.distance(storedValue, from: storedUnit, to: .meters)
    }

    @MainActor static func meters(of set: ExerciseSet) -> Float? {
        set.distance.map { meters(storedValue: $0, storedUnit: set.distanceType) }
    }

    nonisolated static func preferredDisplayUnit(
        forMeters meters: Float?,
        system: UnitSystem
    ) -> DistanceType {
        guard system == .metric else { return .miles }
        return (meters ?? 0) >= 1_000 ? .kilometers : .meters
    }

    nonisolated static func displayMeasurement(
        storedValue: Float,
        storedUnit: DistanceType,
        system: UnitSystem
    ) -> DistanceMeasurement {
        let meters = meters(storedValue: storedValue, storedUnit: storedUnit)
        let unit = preferredDisplayUnit(forMeters: meters, system: system)
        return DistanceMeasurement(
            value: UnitConversion.distance(meters, from: .meters, to: unit),
            unit: unit
        )
    }

    @MainActor static func displayMeasurement(
        for set: ExerciseSet,
        system: UnitSystem? = nil
    ) -> DistanceMeasurement? {
        guard let storedValue = set.distance else { return nil }
        return displayMeasurement(
            storedValue: storedValue,
            storedUnit: set.distanceType,
            system: system ?? set.usedMetric
        )
    }

    /// Converts typed/display input to canonical metres for a newly written or
    /// editable set. Completed historical rows are never passed here merely to
    /// render or switch preferences.
    @MainActor static func storeDisplayValue(
        _ value: Float?,
        displayUnit: DistanceType,
        on set: ExerciseSet
    ) {
        set.distance = value.map { UnitConversion.distance($0, from: displayUnit, to: .meters) }
        set.distanceType = .meters
    }

    @MainActor static func canonicalizeEditable(_ set: ExerciseSet) -> Bool {
        guard !set.done, set.distanceType != .meters else { return false }
        set.distance = set.distance.map { meters(storedValue: $0, storedUnit: set.distanceType) }
        set.distanceType = .meters
        return true
    }
}

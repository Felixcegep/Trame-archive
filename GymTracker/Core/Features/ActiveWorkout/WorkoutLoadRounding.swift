import Foundation

/// Keeps loads that cross a unit boundary on the grid the equipment can
/// actually be set to.
///
/// Prescriptions are already rounded when they are generated, in the unit they
/// were authored in (`ProgramPrescriptionSnapshotService`). Converting one
/// afterwards re-introduces precision no bar can hold: a 50 kg target becomes
/// 110.231 lb, which then renders as "110.23" and puts every subsequent ±
/// press off-grid — 115.23, 120.23 — because the stepper moves in whole plate
/// jumps from wherever it starts.
///
/// So conversion and rounding belong together. Every site that turns a load
/// into a different unit for a lifter to read or to lift goes through
/// ``converted(_:from:to:for:)``.
///
/// Two deliberate limits:
///
/// - Same-unit values pass through untouched. A lifter who types 2.5 kg keeps
///   2.5 kg; only a crossing introduces the unloadable precision this fixes.
/// - An exercise whose equipment the catalogue does not describe is left
///   alone. Snapping an unknown implement to a barbell's plate grid would be a
///   guess, and a wrong guess here is worse than a long number.
///
/// Performed values are never rounded through here. What a lifter actually
/// lifted is historical truth and is reported as recorded.
enum WorkoutLoadRounding {
    /// The jump this exercise's equipment actually makes, or `nil` when the
    /// catalogue does not describe it well enough to say.
    static func equipmentIncrement(for exercise: Exercise, unit: WeightType) -> Double? {
        EquipmentLoadRounding.increment(
            equipment: exercise.equipmentType,
            resistance: exercise.resistanceType,
            isPlateLoaded: exercise.isPlateLoaded,
            unit: unit
        )
    }

    /// The equipment jump, falling back to the unit's generic progression step.
    /// Used for the set-entry stepper, where an unknown implement still needs
    /// *some* sensible step — unlike rounding, where guessing is worse than
    /// leaving the value alone.
    static func stepperIncrement(for exercise: Exercise, unit: WeightType) -> Double {
        equipmentIncrement(for: exercise, unit: unit)
            ?? Double(Constants.Progression.increment(for: unit))
    }

    /// Snaps a load to the equipment's grid. Returns the value unchanged when
    /// the equipment is unknown or the value is not finite.
    static func rounded(_ value: Float, for exercise: Exercise, unit: WeightType) -> Float {
        guard value.isFinite,
              let increment = equipmentIncrement(for: exercise, unit: unit),
              increment > 0
        else {
            return value
        }
        return Float((Double(value) / increment).rounded() * increment)
    }

    /// Converts a load into `target` and, when that was an actual unit
    /// crossing, snaps it to what the equipment can hold.
    static func converted(
        _ value: Float,
        from source: WeightType,
        to target: WeightType,
        for exercise: Exercise
    ) -> Float {
        let converted = UnitConversion.weight(value, from: source, to: target)
        guard source != target else { return converted }
        return rounded(converted, for: exercise, unit: target)
    }
}

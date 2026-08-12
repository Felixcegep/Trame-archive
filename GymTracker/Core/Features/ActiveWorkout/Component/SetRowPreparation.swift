import Foundation

enum SetRowPreparation {
    static func synchronizeUnits(
        for exerciseSet: ExerciseSet,
        in exerciseEntry: ExerciseEntry,
        preferredSystem: UnitSystem
    ) -> Bool {
        let preferredWeightType: WeightType = preferredSystem == .metric ? .kg : .lbs
        return WorkoutSetInputNormalizer.synchronize(
            exerciseSet,
            to: preferredSystem,
            // Resolved here, where the exercise is in scope. The normalizer
            // itself must stay free of catalogue types — see its parameter doc.
            loadIncrement: WorkoutLoadRounding.equipmentIncrement(
                for: exerciseEntry.exercise,
                unit: preferredWeightType
            )
        )
    }

    static func prefillPrescribedDuration(
        for exerciseSet: ExerciseSet,
        in exerciseEntry: ExerciseEntry
    ) -> Bool {
        guard !exerciseSet.done,
              !exerciseSet.separatesProgramPerformedEvidence,
              exerciseEntry.trackingTypeSnapshot.usesDuration,
              (exerciseSet.duration ?? 0) <= 0 else { return false }
        let prescribedSeconds = exerciseEntry.prescribedRepRangeMaximum
            ?? exerciseEntry.prescribedRepRangeMinimum
            ?? 0
        guard prescribedSeconds > 0 else { return false }
        exerciseSet.duration = TimeInterval(prescribedSeconds)
        return true
    }

    /// Whether every metric this exercise tracks is still unfilled.
    ///
    /// Mirrors `SetRowFieldStack.storedText` exactly: a field is empty when its
    /// cell would render the placeholder rather than a value. The two must agree
    /// — this predicate decides whether to *commit* the number the cell is
    /// already showing in grey, so a disagreement would either write a value
    /// over one the lifter can see, or leave a visible suggestion uncommitted.
    ///
    /// Zero is empty here, matching the rest of the row. That is deliberate and
    /// not the same claim as `WorkoutSetCompletionValidator`, which asks whether
    /// a set may be *logged*; a bodyweight set legitimately completes at zero
    /// load, but it has not been "filled in" by the lifter either.
    static func isUnfilled(_ exerciseSet: ExerciseSet, for trackingType: TrackingType) -> Bool {
        if trackingType.usesReps, exerciseSet.repetitions != 0 { return false }
        if trackingType.usesWeight, exerciseSet.weight != 0 { return false }
        if trackingType.usesDuration, (exerciseSet.duration ?? 0) > 0 { return false }
        if trackingType.usesDistance, (exerciseSet.distance ?? 0) > 0 { return false }
        if trackingType.usesCalories, (exerciseSet.calories ?? 0) > 0 { return false }
        return true
    }

    /// Whether a set carries any prescribed target of its own.
    ///
    /// A prescribed set is one a plan has an opinion about, and that opinion
    /// outranks what the lifter happened to do last time. Automatic
    /// previous-performance fill is therefore refused here and stays available
    /// as the explicit "Use last time" action, which is what marks the set
    /// `isUserOverridden` — a deviation from the plan should be something the
    /// lifter chose, never something a screen did on their behalf while it was
    /// appearing.
    static func hasPrescription(_ exerciseSet: ExerciseSet) -> Bool {
        exerciseSet.prescribedSetType != nil
            || exerciseSet.prescribedRepetitions != nil
            || exerciseSet.prescribedRepRangeMinimum != nil
            || exerciseSet.prescribedRepRangeMaximum != nil
            || exerciseSet.prescribedSuggestedLoad != nil
            || exerciseSet.prescribedCalories != nil
            || exerciseSet.prescriptionDefinitionData != nil
    }

    /// Whether a target exists anywhere the set is governed by — its own
    /// fields, or the entry it belongs to.
    ///
    /// The set-level check alone is not enough to decide whether an automatic
    /// fill is safe. `ProgramPrescriptionSnapshotService` writes a rep range
    /// and a suggested load onto the *entry* as well as onto its sets, and a
    /// hand-built template can carry the entry's targets with no set-level
    /// snapshot at all. Reading only the set would let a plan prescribing
    /// 3 × 8–10 be silently refilled with last session's 12.
    ///
    /// Kept separate from `hasPrescription` because the two answer different
    /// questions: that one asks whether *this set* is deviating from a target
    /// (which is what `isUserOverridden` records), this one asks whether any
    /// target exists to defer to.
    static func hasAnyPrescription(_ exerciseSet: ExerciseSet, in exerciseEntry: ExerciseEntry) -> Bool {
        hasPrescription(exerciseSet)
            || exerciseEntry.prescribedRepRangeMinimum != nil
            || exerciseEntry.prescribedRepRangeMaximum != nil
            || exerciseEntry.prescribedSuggestedLoad != nil
    }
}

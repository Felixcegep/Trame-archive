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
}

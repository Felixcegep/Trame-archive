import Foundation

enum SetRowPreparation {
    static func synchronizeUnits(
        for exerciseSet: ExerciseSet,
        preferredSystem: UnitSystem
    ) -> Bool {
        WorkoutSetInputNormalizer.synchronize(exerciseSet, to: preferredSystem)
    }

    static func prefillPrescribedDuration(
        for exerciseSet: ExerciseSet,
        in exerciseEntry: ExerciseEntry
    ) -> Bool {
        guard !exerciseSet.done,
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

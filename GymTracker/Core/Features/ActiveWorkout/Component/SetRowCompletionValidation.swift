enum SetRowCompletionValidation {
    static func message(
        for exerciseSet: ExerciseSet,
        trackingType: TrackingType
    ) -> String {
        if trackingType.usesReps, exerciseSet.repetitions <= 0 {
            return "Enter reps before completing this set."
        }
        if trackingType.usesDuration, (exerciseSet.duration ?? 0) <= 0 {
            return "Enter a duration before completing this set."
        }
        if trackingType.usesCalories, (exerciseSet.calories ?? 0) <= 0 {
            return "Enter calories before completing this set."
        }
        if trackingType.usesDistance, (exerciseSet.distance ?? 0) <= 0 {
            return "Enter a distance before completing this set."
        }
        return "Enter a value before completing this set."
    }
}

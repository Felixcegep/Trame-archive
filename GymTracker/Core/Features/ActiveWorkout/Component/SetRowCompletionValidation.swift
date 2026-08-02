enum SetRowCompletionValidation {
    static func message(
        for exerciseSet: ExerciseSet,
        trackingType: TrackingType
    ) -> String {
        let result = WorkoutSetCompletionValidator.validate(
            .init(set: exerciseSet, trackingType: trackingType)
        )
        switch result.firstInvalidReason {
        case .missingRepetitions:
            return "Enter reps before completing this set."
        case .missingDuration:
            return "Enter a duration before completing this set."
        case .missingDistance:
            return "Enter a distance before completing this set."
        case .missingCalories:
            return "Enter calories before completing this set."
        case nil:
            return "Enter a value before completing this set."
        }
    }
}

enum SetRowCompletionValidation {
    static func message(
        for exerciseSet: ExerciseSet,
        trackingType: TrackingType
    ) -> String {
        let result = WorkoutSetCompletionValidator.validate(
            .init(set: exerciseSet, trackingType: trackingType)
        )
        let input = WorkoutSetCompletionValidator.Input(
            set: exerciseSet,
            trackingType: trackingType
        )
        if case .invalid(let reasons) = result,
           case .any = WorkoutSetCompletionValidator.resolvedRule(for: input) {
            let choices = reasons.map { $0.metric.title.lowercased() }
            return "Enter \(joined(choices, conjunction: "or")) before completing this set."
        }
        if case .invalid(let reasons) = result, reasons.count > 1 {
            let requirements = reasons.map { $0.metric.title.lowercased() }
            return "Enter \(joined(requirements, conjunction: "and")) before completing this set."
        }
        switch result.firstInvalidReason {
        case .missingRepetitions:
            return "Enter reps before completing this set."
        case .missingLoad:
            return "Enter a load before completing this set."
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

    private static func joined(_ values: [String], conjunction: String) -> String {
        guard let last = values.last else { return String(localized: "a value") }
        guard values.count > 1 else { return last }
        return "\(values.dropLast().joined(separator: ", ")) \(conjunction) \(last)"
    }
}

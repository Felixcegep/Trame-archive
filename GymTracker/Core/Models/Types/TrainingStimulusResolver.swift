import Foundation

/// Domain-level default-stimulus inference shared by the plan editor, template
/// resolution, and backup validation. The return type is optional because an
/// exercise whose semantics do not support an unambiguous inference must stay
/// unclassified — absence is different from intent.
enum TrainingStimulusResolver {
    static func inferredStimulus(for exercise: Exercise) -> TrainingStimulus? {
        inferredStimulus(category: exercise.category, trackingType: exercise.trackingType)
    }

    static func inferredStimulus(
        category: ExerciseCategory?,
        trackingType: TrackingType
    ) -> TrainingStimulus? {
        if category == .mobility || category == .flexibility { return .mobility }
        if category == .cardio { return .endurance }
        if trackingType.usesDuration && !trackingType.usesWeight { return .endurance }
        return nil
    }
}

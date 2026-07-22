import Foundation

enum TrackingProfileValidationError: Error, Equatable, LocalizedError {
    case invalidCombination(stimulus: TrainingStimulus, trackingType: TrackingType)

    var errorDescription: String? {
        switch self {
        case let .invalidCombination(stimulus, trackingType):
            return "The combination of \(stimulus.title) stimulus and \(trackingType.rawValue) tracking is invalid."
        }
    }
}

struct TrackingProfileValidator {
    static func validate(
        stimulus: TrainingStimulus,
        trackingType: TrackingType,
        exercise: Exercise? = nil
    ) -> Result<Void, TrackingProfileValidationError> {
        switch (stimulus, trackingType) {
        case (.hypertrophy, .calories):
            return .failure(.invalidCombination(stimulus: stimulus, trackingType: trackingType))
        case (.strength, .calories):
            return .failure(.invalidCombination(stimulus: stimulus, trackingType: trackingType))
        default:
            return .success(())
        }
    }
}

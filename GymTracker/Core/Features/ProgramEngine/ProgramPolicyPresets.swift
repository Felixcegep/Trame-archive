import Foundation

#if !GYMTRACKER_EXTENSION

/// Reusable, data-only policy recipes for the visual builder. Presets create
/// ordinary rule definitions; they never introduce program-name branches into
/// execution.
enum ProgramPolicyPreset: String, CaseIterable, Identifiable, Codable, Hashable {
    case linearLoad
    case doubleProgression
    case failureDeload
    case stageLadder
    case rpeRecommendation
    case durationProgression
    case distanceProgression
    case technicalQuality

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linearLoad: return "Linear load"
        case .doubleProgression: return "Double progression"
        case .failureDeload: return "Failure deload"
        case .stageLadder: return "Stage ladder"
        case .rpeRecommendation: return "RPE recommendation"
        case .durationProgression: return "Duration progression"
        case .distanceProgression: return "Distance progression"
        case .technicalQuality: return "Technical quality"
        }
    }

    func rules() -> [ProgressionRuleDefinition] {
        switch self {
        case .linearLoad:
            return [ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )]
        case .doubleProgression:
            return [ProgressionRuleDefinition(
                metric: .repetitions,
                trigger: .allSetsReachedUpperRepBound,
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )]
        case .failureDeload:
            return [ProgressionRuleDefinition(
                metric: .load,
                trigger: .failureCountReached(3),
                successAction: .reduceLoadPercentage(0.1),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .recommendation
            )]
        case .stageLadder:
            return [
                ProgressionRuleDefinition(
                    metric: .load,
                    trigger: .failureCountReached(1),
                    successAction: .changeStage("6x2"),
                    cadence: .nextExerciseOccurrence,
                    scope: .exerciseExposure,
                    applicationMode: .automatic
                ),
                ProgressionRuleDefinition(
                    metric: .load,
                    trigger: .failureCountReached(2),
                    successAction: .changeStage("10x1"),
                    cadence: .nextExerciseOccurrence,
                    scope: .exerciseExposure,
                    applicationMode: .automatic
                ),
                ProgressionRuleDefinition(
                    metric: .load,
                    trigger: .failureCountReached(3),
                    successAction: .startDeload,
                    cadence: .nextExerciseOccurrence,
                    scope: .exerciseExposure,
                    applicationMode: .automatic
                )
            ]
        case .rpeRecommendation:
            return [ProgressionRuleDefinition(
                metric: .rpe,
                trigger: .actualRPEAboveTarget(tolerance: 1),
                successAction: .generateRecommendation,
                failureAction: .noChange,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .recommendation
            )]
        case .durationProgression:
            return [ProgressionRuleDefinition(
                metric: .duration,
                trigger: .allRequiredSetsCompleted,
                successAction: .addDuration(60),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )]
        case .distanceProgression:
            return [ProgressionRuleDefinition(
                metric: .distance,
                trigger: .allRequiredSetsCompleted,
                successAction: .addDistance(250),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )]
        case .technicalQuality:
            return [ProgressionRuleDefinition(
                metric: .successfulAttempts,
                trigger: .successfulAttemptRatioReached(0.9),
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextWorkout,
                scope: .exerciseExposure,
                applicationMode: .recommendation
            )]
        }
    }
}

#endif

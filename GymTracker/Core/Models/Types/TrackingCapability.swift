import Foundation

/// A value-layer vocabulary for the evidence a workout set can record.
///
/// `ExerciseSet` keeps its existing typed properties. This enum describes
/// capabilities and completion rules; it is deliberately not a persisted
/// metric dictionary.
nonisolated enum TrackingMetric: String, Codable, Hashable, CaseIterable, Sendable {
    case repetitions
    case load
    case duration
    case distance
    case calories
    case meanVelocity
    case peakVelocity
    case jumpHeight
    case contactTime
    case throwDistance
    case cadence

    /// Metrics the current set-entry surfaces can collect and focus directly.
    /// Advanced measurements remain typed optional evidence until their own
    /// completion interaction is promoted.
    static let completionWritable: Set<TrackingMetric> = [
        .repetitions, .load, .duration, .distance, .calories
    ]

    var title: String {
        switch self {
        case .repetitions: String(localized: "Repetitions")
        case .load: String(localized: "Load")
        case .duration: String(localized: "Duration")
        case .distance: String(localized: "Distance")
        case .calories: String(localized: "Calories")
        case .meanVelocity: String(localized: "Mean velocity")
        case .peakVelocity: String(localized: "Peak velocity")
        case .jumpHeight: String(localized: "Jump height")
        case .contactTime: String(localized: "Contact time")
        case .throwDistance: String(localized: "Throw distance")
        case .cadence: String(localized: "Cadence")
        }
    }
}

/// How performed evidence unlocks completion for one prescribed set.
nonisolated enum MetricCompletionRule: Codable, Hashable, Sendable {
    case all(Set<TrackingMetric>)
    case any(Set<TrackingMetric>)
    case prescribedTargets
}

/// Derived capabilities for a legacy tracking type.
///
/// Profiles are values and are not written into completed rows. This preserves
/// the existing `TrackingType` contract while allowing authored completion
/// semantics to be validated centrally.
nonisolated struct TrackingCapabilityProfile: Codable, Hashable, Sendable {
    var supportedMetrics: Set<TrackingMetric>
    var primaryMetric: TrackingMetric?
    var secondaryMetrics: Set<TrackingMetric>
    var defaultCompletionRule: MetricCompletionRule

    var completionWritableMetrics: Set<TrackingMetric> {
        supportedMetrics.intersection(TrackingMetric.completionWritable)
    }
}

extension TrackingType {
    /// How this exercise is logged, named once, for the surfaces that show
    /// numbers before they show captions.
    ///
    /// `nil` for weight and reps: the value captions already read "Reps" and
    /// "Weight", and restating them as a phrase above the same two numbers is
    /// the parent-context repetition the design rules ask to remove. Every
    /// other type either drops a field the lifter expects — no load on a
    /// bodyweight movement — or means something different by the field it
    /// keeps, and the panel is where that has to be said.
    ///
    /// Calories are also `nil`: the single value pill is already named
    /// "Calories" and nothing about it is surprising.
    nonisolated var loggingOrientation: String? {
        switch self {
        case .weightAndReps, .calories: nil
        case .repsOnly: String(localized: "Bodyweight reps")
        case .weightedBodyweight: String(localized: "Added weight + reps")
        case .assistedBodyweight: String(localized: "Assisted reps")
        case .duration: String(localized: "Hold time")
        case .durationAndDistance: String(localized: "Time + distance")
        }
    }

    nonisolated var capabilityProfile: TrackingCapabilityProfile {
        switch self {
        case .weightAndReps, .weightedBodyweight, .assistedBodyweight:
            TrackingCapabilityProfile(
                supportedMetrics: [.repetitions, .load],
                primaryMetric: .repetitions,
                secondaryMetrics: [.load],
                defaultCompletionRule: .all([.repetitions])
            )
        case .repsOnly:
            TrackingCapabilityProfile(
                supportedMetrics: [.repetitions],
                primaryMetric: .repetitions,
                secondaryMetrics: [],
                defaultCompletionRule: .all([.repetitions])
            )
        case .duration:
            TrackingCapabilityProfile(
                supportedMetrics: [.duration],
                primaryMetric: .duration,
                secondaryMetrics: [],
                defaultCompletionRule: .all([.duration])
            )
        case .durationAndDistance:
            TrackingCapabilityProfile(
                supportedMetrics: [.duration, .distance],
                primaryMetric: .duration,
                secondaryMetrics: [.distance],
                defaultCompletionRule: .all([.duration, .distance])
            )
        case .calories:
            TrackingCapabilityProfile(
                supportedMetrics: [.calories],
                primaryMetric: .calories,
                secondaryMetrics: [],
                defaultCompletionRule: .all([.calories])
            )
        }
    }
}

/// Minimal decoder shared with the app extension. Program recipe types remain
/// app-only, but completion still has to read the immutable rule snapshot from
/// `ExerciseSet.prescriptionDefinitionData` in Live Activity and App Intent
/// workflows.
nonisolated struct WorkoutMetricCompletionSnapshot: Decodable, Sendable {
    let completionRule: MetricCompletionRule?
    let completionTargetMetrics: Set<TrackingMetric>

    private enum CodingKeys: String, CodingKey {
        case completionRule, completionTargetMetrics
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        completionRule = try values.decodeIfPresent(
            MetricCompletionRule.self,
            forKey: .completionRule
        )
        completionTargetMetrics = try values.decodeIfPresent(
            Set<TrackingMetric>.self,
            forKey: .completionTargetMetrics
        ) ?? []
    }
}

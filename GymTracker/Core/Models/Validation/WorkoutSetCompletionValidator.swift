import Foundation

/// Pure, cross-surface authority for whether the current performed values may
/// complete one top-level workout set.
///
/// Nested segments and complex components remain evidence owned by the parent
/// set. An Olympic parent attempt cannot complete until every prescribed
/// component has an explicit outcome; completing the parent never fabricates
/// component evidence.
nonisolated enum WorkoutSetCompletionValidator {
    nonisolated struct Input: Equatable, Sendable {
        let trackingType: TrackingType
        let repetitions: Float
        let load: Float
        let duration: TimeInterval?
        let distance: Float?
        let calories: Double?
        let completionRule: MetricCompletionRule?
        let prescribedMetrics: Set<TrackingMetric>
        let evidenceShape: EvidenceShape
        let hasUnresolvedComplexComponents: Bool

        nonisolated init(
            trackingType: TrackingType,
            repetitions: Float,
            load: Float = 0,
            duration: TimeInterval?,
            distance: Float?,
            calories: Double?,
            completionRule: MetricCompletionRule? = nil,
            prescribedMetrics: Set<TrackingMetric> = [],
            evidenceShape: EvidenceShape = .plain,
            hasUnresolvedComplexComponents: Bool = false
        ) {
            self.trackingType = trackingType
            self.repetitions = repetitions
            self.load = load
            self.duration = duration
            self.distance = distance
            self.calories = calories
            self.completionRule = completionRule
            self.prescribedMetrics = prescribedMetrics
            self.evidenceShape = evidenceShape
            self.hasUnresolvedComplexComponents = hasUnresolvedComplexComponents
        }
    }

    nonisolated enum EvidenceShape: Equatable, Sendable {
        case plain
        case segmented
        case complex
        case segmentedComplex
    }

    nonisolated enum InvalidReason: Equatable, Sendable {
        case missingRepetitions
        case missingLoad
        case missingDuration
        case missingDistance
        case missingCalories
        case unresolvedComplexComponents

        nonisolated var metric: TrackingMetric {
            switch self {
            case .missingRepetitions: .repetitions
            case .missingLoad: .load
            case .missingDuration: .duration
            case .missingDistance: .distance
            case .missingCalories: .calories
            case .unresolvedComplexComponents: .repetitions
            }
        }
    }

    nonisolated enum Result: Equatable, Sendable {
        case valid
        case invalid([InvalidReason])

        nonisolated var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        nonisolated var firstInvalidReason: InvalidReason? {
            guard case .invalid(let reasons) = self else { return nil }
            return reasons.first
        }
    }

    nonisolated static func validate(_ input: Input) -> Result {
        if input.hasUnresolvedComplexComponents {
            return .invalid([.unresolvedComplexComponents])
        }
        switch resolvedRule(for: input) {
        case .all(let metrics):
            let reasons = orderedMetrics(in: metrics).compactMap { missingReason(for: $0, input: input) }
            return reasons.isEmpty ? .valid : .invalid(reasons)
        case .any(let metrics):
            let ordered = orderedMetrics(in: metrics)
            if ordered.contains(where: { missingReason(for: $0, input: input) == nil }) {
                return .valid
            }
            return .invalid(ordered.compactMap { missingReason(for: $0, input: input) })
        case .prescribedTargets:
            // `resolvedRule` always resolves this case to a concrete `.all`
            // rule or the exact legacy default.
            return validate(Input(
                trackingType: input.trackingType,
                repetitions: input.repetitions,
                load: input.load,
                duration: input.duration,
                distance: input.distance,
                calories: input.calories,
                completionRule: input.trackingType.capabilityProfile.defaultCompletionRule,
                evidenceShape: input.evidenceShape
            ))
        }
    }

    nonisolated static func resolvedRule(for input: Input) -> MetricCompletionRule {
        let profile = input.trackingType.capabilityProfile
        guard let authored = input.completionRule else {
            return profile.defaultCompletionRule
        }
        switch authored {
        case .all(let metrics):
            guard !metrics.isEmpty, metrics.isSubset(of: profile.completionWritableMetrics) else {
                return profile.defaultCompletionRule
            }
            return .all(metrics)
        case .any(let metrics):
            guard !metrics.isEmpty, metrics.isSubset(of: profile.completionWritableMetrics) else {
                return profile.defaultCompletionRule
            }
            return .any(metrics)
        case .prescribedTargets:
            let targets = input.prescribedMetrics.intersection(profile.completionWritableMetrics)
            guard !targets.isEmpty else { return profile.defaultCompletionRule }
            return .all(targets)
        }
    }

    nonisolated private static func orderedMetrics(
        in metrics: Set<TrackingMetric>
    ) -> [TrackingMetric] {
        TrackingMetric.allCases.filter(metrics.contains)
    }

    nonisolated private static func missingReason(
        for metric: TrackingMetric,
        input: Input
    ) -> InvalidReason? {
        switch metric {
        case .repetitions:
            return input.repetitions.isFinite && input.repetitions > 0 ? nil : .missingRepetitions
        case .load:
            return input.load.isFinite && input.load > 0 ? nil : .missingLoad
        case .duration:
            guard let duration = input.duration, duration.isFinite, duration > 0 else {
                return .missingDuration
            }
            return nil
        case .distance:
            guard let distance = input.distance, distance.isFinite, distance > 0 else {
                return .missingDistance
            }
            return nil
        case .calories:
            guard let calories = input.calories, calories.isFinite, calories > 0 else {
                return .missingCalories
            }
            return nil
        case .meanVelocity, .peakVelocity, .jumpHeight, .contactTime,
                .throwDistance, .cadence:
            // Advanced evidence is intentionally not a completion metric until
            // the active set UI can collect and focus it as a first-class value.
            return nil
        }
    }
}

extension WorkoutSetCompletionValidator.Input {
    init(set: ExerciseSet, trackingType: TrackingType) {
        let evidenceShape: WorkoutSetCompletionValidator.EvidenceShape
        switch (set.segments.isEmpty, set.complexComponents.isEmpty) {
        case (true, true): evidenceShape = .plain
        case (false, true): evidenceShape = .segmented
        case (true, false): evidenceShape = .complex
        case (false, false): evidenceShape = .segmentedComplex
        }
        let snapshot = set.prescriptionDefinitionData.flatMap {
            try? JSONDecoder().decode(WorkoutMetricCompletionSnapshot.self, from: $0)
        }
        self.init(
            trackingType: trackingType,
            repetitions: set.repetitions,
            load: set.weight,
            duration: set.duration,
            distance: set.distance,
            calories: set.calories,
            completionRule: snapshot?.completionRule,
            prescribedMetrics: snapshot?.completionTargetMetrics ?? [],
            evidenceShape: evidenceShape,
            hasUnresolvedComplexComponents: set.complexComponents.contains {
                $0.outcome == .notStarted
            }
        )
    }
}

import Foundation

/// Pure, cross-surface authority for whether the current performed values may
/// complete one top-level workout set.
///
/// Nested segments and complex components remain evidence owned by the parent
/// set. Their presence is captured in `evidenceShape` for conformance tests,
/// but it does not add a second completion gate: existing mutation paths
/// synchronize that evidence when the parent transitions.
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

        nonisolated init(
            trackingType: TrackingType,
            repetitions: Float,
            load: Float = 0,
            duration: TimeInterval?,
            distance: Float?,
            calories: Double?,
            completionRule: MetricCompletionRule? = nil,
            prescribedMetrics: Set<TrackingMetric> = [],
            evidenceShape: EvidenceShape = .plain
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

        nonisolated var metric: TrackingMetric {
            switch self {
            case .missingRepetitions: .repetitions
            case .missingLoad: .load
            case .missingDuration: .duration
            case .missingDistance: .distance
            case .missingCalories: .calories
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
        case .repetitions: input.repetitions > 0 ? nil : .missingRepetitions
        case .load: input.load > 0 ? nil : .missingLoad
        case .duration: (input.duration ?? 0) > 0 ? nil : .missingDuration
        case .distance: (input.distance ?? 0) > 0 ? nil : .missingDistance
        case .calories: (input.calories ?? 0) > 0 ? nil : .missingCalories
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
            evidenceShape: evidenceShape
        )
    }
}

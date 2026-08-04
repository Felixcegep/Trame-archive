import Foundation

/// Pure authority for whether performed mobility evidence can complete one
/// side-specific result. It validates presence, not prescription attainment:
/// a partial result may remain valuable history without being rewritten as a
/// completed target.
nonisolated enum MobilityCompletionValidator {
    nonisolated struct Input: Equatable, Sendable {
        let profile: MobilityMetricProfile
        let completionRule: MobilityCompletionRule?
        let targets: MobilityMetricTargets
        let performedDurationSeconds: Int?
        let performedRepetitions: Int?
        let performedLoadValue: Double?
        let performedLoadUnit: MobilityLoadUnit?
        let performedBreathingCycles: Int?
        let performedAssistanceLevel: Int?
        let performedSupportLevel: MobilitySupportLevel?
        let movementQuality: MobilityMovementQuality?
        let sensation: MobilitySensation?
        let phaseSequenceCompleted: Bool
    }

    nonisolated enum InvalidReason: Equatable, Sendable {
        case missingDuration
        case missingRepetitions
        case missingLoad
        case missingBreathingCycles
        case missingAssistanceLevel
        case missingSupportLevel
        case missingMovementQuality
        case missingPerceivedStretch
        case incompletePhaseSequence
        case unsupportedCompletionRule
    }

    nonisolated enum Result: Equatable, Sendable {
        case valid
        case invalid([InvalidReason])

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    nonisolated static func validate(_ input: Input) -> Result {
        switch resolvedRule(for: input) {
        case .phaseSequenceCompleted:
            return input.phaseSequenceCompleted
                ? .valid
                : .invalid([.incompletePhaseSequence])
        case .all(let metrics):
            let reasons = ordered(metrics).compactMap { missingReason(for: $0, input: input) }
            return reasons.isEmpty ? .valid : .invalid(reasons)
        case .any(let metrics):
            let metrics = ordered(metrics)
            guard metrics.isEmpty == false else {
                return .invalid([.unsupportedCompletionRule])
            }
            if metrics.contains(where: { missingReason(for: $0, input: input) == nil }) {
                return .valid
            }
            return .invalid(metrics.compactMap { missingReason(for: $0, input: input) })
        case .prescribedTargets:
            // `resolvedRule` reduces this to the exact target metric set or to
            // the profile's legacy-compatible default.
            return .invalid([.unsupportedCompletionRule])
        }
    }

    nonisolated static func resolvedRule(for input: Input) -> MobilityCompletionRule {
        let authored = input.completionRule ?? input.profile.defaultCompletionRule
        switch authored {
        case .all(let metrics):
            let supported = metrics.intersection(input.profile.completionWritableMetrics)
            guard metrics.isEmpty == false, supported == metrics else {
                return input.profile.defaultCompletionRule
            }
            return .all(metrics)
        case .any(let metrics):
            let supported = metrics.intersection(input.profile.completionWritableMetrics)
            guard metrics.isEmpty == false, supported == metrics else {
                return input.profile.defaultCompletionRule
            }
            return .any(metrics)
        case .prescribedTargets:
            let metrics = input.targets.prescribedMetrics
                .intersection(input.profile.completionWritableMetrics)
            guard metrics.isEmpty == false else { return input.profile.defaultCompletionRule }
            return .all(metrics)
        case .phaseSequenceCompleted:
            return input.profile.defaultCompletionRule == .phaseSequenceCompleted
                ? .phaseSequenceCompleted
                : input.profile.defaultCompletionRule
        }
    }

    private nonisolated static func ordered(_ metrics: Set<MobilityMetric>) -> [MobilityMetric] {
        MobilityMetric.allCases.filter(metrics.contains)
    }

    private nonisolated static func missingReason(
        for metric: MobilityMetric,
        input: Input
    ) -> InvalidReason? {
        switch metric {
        case .duration, .contractionDuration:
            return (input.performedDurationSeconds ?? 0) > 0 ? nil : .missingDuration
        case .repetitions:
            return (input.performedRepetitions ?? 0) > 0 ? nil : .missingRepetitions
        case .load:
            return (input.performedLoadValue ?? 0) > 0 && input.performedLoadUnit != nil
                ? nil : .missingLoad
        case .breathingCycles:
            return (input.performedBreathingCycles ?? 0) > 0 ? nil : .missingBreathingCycles
        case .assistanceLevel:
            return input.performedAssistanceLevel != nil ? nil : .missingAssistanceLevel
        case .supportLevel:
            return input.performedSupportLevel != nil ? nil : .missingSupportLevel
        case .movementQuality:
            return input.movementQuality != nil ? nil : .missingMovementQuality
        case .perceivedStretch:
            return input.sensation != nil ? nil : .missingPerceivedStretch
        case .cycles:
            return input.phaseSequenceCompleted ? nil : .incompletePhaseSequence
        case .rangeDistance, .jointAngle, .reach:
            return .unsupportedCompletionRule
        }
    }
}


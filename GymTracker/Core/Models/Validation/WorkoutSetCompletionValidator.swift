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
        let duration: TimeInterval?
        let distance: Float?
        let calories: Double?
        let evidenceShape: EvidenceShape

        nonisolated init(
            trackingType: TrackingType,
            repetitions: Float,
            duration: TimeInterval?,
            distance: Float?,
            calories: Double?,
            evidenceShape: EvidenceShape = .plain
        ) {
            self.trackingType = trackingType
            self.repetitions = repetitions
            self.duration = duration
            self.distance = distance
            self.calories = calories
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
        case missingDuration
        case missingDistance
        case missingCalories
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
        var reasons: [InvalidReason] = []
        if input.trackingType.usesReps, input.repetitions <= 0 {
            reasons.append(.missingRepetitions)
        }
        if input.trackingType.usesDuration, (input.duration ?? 0) <= 0 {
            reasons.append(.missingDuration)
        }
        if input.trackingType.usesDistance, (input.distance ?? 0) <= 0 {
            reasons.append(.missingDistance)
        }
        if input.trackingType.usesCalories, (input.calories ?? 0) <= 0 {
            reasons.append(.missingCalories)
        }
        return reasons.isEmpty ? .valid : .invalid(reasons)
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
        self.init(
            trackingType: trackingType,
            repetitions: set.repetitions,
            duration: set.duration,
            distance: set.distance,
            calories: set.calories,
            evidenceShape: evidenceShape
        )
    }
}

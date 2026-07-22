import Foundation

/// Centralized eligibility and comparability rules for expanded strength
/// formats. A completed workout remains the outer history boundary; this
/// policy prevents format-specific evidence from being misread as a normal
/// load, rep, or e1RM record.
enum StrengthAnalyticsPolicy {
    static func isEligibleForTraditionalSetRecord(_ set: ExerciseSet) -> Bool {
        set.done
            && set.setType != .warmup
            && set.setMethod == .standard
            && set.segments.isEmpty
            && set.complexComponents.isEmpty
            && set.specializedMetricKind == .none
            && !set.isVelocityProbe
    }

    static func isEligibleForVelocityRecord(_ set: ExerciseSet) -> Bool {
        guard set.done,
              let source = set.velocityMeasurementSource,
              source != .estimated
        else { return false }
        return (set.meanVelocity ?? 0) > 0 || (set.peakVelocity ?? 0) > 0
    }

    static func isEligibleForSpecializedMetricRecord(_ set: ExerciseSet) -> Bool {
        guard set.done,
              set.specializedMetricKind != .none,
              let source = set.specializedMetricMeasurementSource,
              source != .estimated,
              let metric = specializedMetricValue(for: set),
              metric.value > 0
        else { return false }
        return true
    }

    static func specializedMetricValue(for set: ExerciseSet) -> (value: Double, unit: String)? {
        switch set.specializedMetricKind {
        case .jumpHeight:
            return set.jumpHeightMeters.map { ($0, "m") }
        case .contactTime:
            return set.contactTimeMilliseconds.map { ($0, "ms") }
        case .throwDistance:
            return set.throwDistanceMeters.map { ($0, "m") }
        case .kettlebellCadence:
            return set.kettlebellCadenceRPM.map { ($0, "rpm") }
        case .none:
            return nil
        }
    }

    static func prefersLowerSpecializedMetric(_ kind: SpecializedPerformanceMetricKind) -> Bool {
        kind == .contactTime
    }

    static func blockCandidate(
        for block: WorkoutExecutionBlock,
        in workout: Workout
    ) -> BlockRecordCandidate? {
        guard block.scoreKind != .none else { return nil }
        guard block.status == .completed || block.status == .capped else { return nil }
        if block.scoreKind == .duration, block.status != .completed { return nil }

        let key = blockComparisonKey(block, workout: workout)
        switch block.scoreKind {
        case .roundsAndRepetitions:
            let value = Double(block.completedRounds) * 100_000 + Double(block.additionalRepetitions)
            return BlockRecordCandidate(
                comparisonKey: key,
                title: block.name ?? block.kind.title,
                scoreKind: block.scoreKind,
                value: value,
                displayValue: "\(block.completedRounds) + \(block.additionalRepetitions)",
                lowerIsBetter: false,
                date: workout.startTime
            )
        case .duration:
            guard let value = block.scoreValue, value > 0 else { return nil }
            return BlockRecordCandidate(
                comparisonKey: key,
                title: block.name ?? block.kind.title,
                scoreKind: block.scoreKind,
                value: value,
                displayValue: timeText(value),
                lowerIsBetter: true,
                date: workout.startTime
            )
        case .completedWork, .distance, .calories, .load, .points:
            guard let value = block.scoreValue, value > 0 else { return nil }
            return BlockRecordCandidate(
                comparisonKey: key,
                title: block.name ?? block.kind.title,
                scoreKind: block.scoreKind,
                value: value,
                displayValue: value.formatted(),
                lowerIsBetter: false,
                date: workout.startTime
            )
        case .none:
            return nil
        }
    }

    private static func blockComparisonKey(_ block: WorkoutExecutionBlock, workout: Workout) -> String {
        let componentIDs = WorkoutExecutionBlockService.entries(in: block, workout: workout)
            .map { $0.exercise.id.uuidString }
            .joined(separator: ",")
        let targetRounds = block.targetRounds.map(String.init) ?? ""
        let repetitionStart = block.repetitionStart.map(String.init) ?? ""
        let repetitionEnd = block.repetitionEnd.map(String.init) ?? ""
        let repetitionStep = block.repetitionStep.map(String.init) ?? ""
        let duration = block.prescribedDurationSeconds.map(String.init) ?? ""
        let cap = block.timeCapSeconds.map(String.init) ?? ""
        let interval = block.intervalSeconds.map(String.init) ?? ""
        let fields = [
            block.kind.rawValue,
            block.scoreKind.rawValue,
            componentIDs,
            targetRounds,
            block.repetitionScheme.rawValue,
            repetitionStart,
            repetitionEnd,
            repetitionStep,
            duration,
            cap,
            interval
        ]
        return fields.joined(separator: "|")
    }

    private static func timeText(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

struct BlockRecordCandidate: Equatable {
    let comparisonKey: String
    let title: String
    let scoreKind: BlockScoreKind
    let value: Double
    let displayValue: String
    let lowerIsBetter: Bool
    let date: Date
}

import Foundation

/// Centralized eligibility and comparability rules for expanded strength
/// formats. A completed workout remains the outer history boundary; this
/// policy prevents format-specific evidence from being misread as a normal
/// load, rep, or e1RM record.
enum StrengthAnalyticsPolicy {
    /// Eligibility for a traditional strength projection must use the
    /// performed entry's historical policy.  Relying only on the set's
    /// inverse relationship is fragile for detached/restored graphs and can
    /// let a warm-up, complex, or specialized set leak into a PR projection.
    static func isEligibleForTraditionalSetRecord(
        _ set: ExerciseSet,
        entry: ExerciseEntry
    ) -> Bool {
        guard set.done,
              set.setType != .warmup,
              set.resolvedSetMethod == .standard,
              set.segments.isEmpty,
              set.complexComponents.isEmpty,
              set.resolvedSpecializedMetricKind == .none,
              !set.isVelocityProbe
        else { return false }
        return SportAnalyticsPolicyResolver.policy(for: entry)
            .contributesToStrengthVolume(set: set, entry: entry)
    }

    /// The `entry`/`policy` gate below is additive: every set that satisfied
    /// this check before `SportAnalyticsPolicy` existed still does, because
    /// `StandardStrengthAnalyticsPolicy.contributesToStrengthVolume` always
    /// returns `true` and every pre-existing entry resolves to that policy
    /// (no exercise has an authored `sportDiscipline` yet). A set whose
    /// `exerciseEntry` was already released (nil) also passes unconditionally
    /// rather than being silently excluded.
    static func isEligibleForTraditionalSetRecord(_ set: ExerciseSet) -> Bool {
        guard let entry = set.exerciseEntry else {
            return set.done
                && set.setType != .warmup
                && set.resolvedSetMethod == .standard
                && set.segments.isEmpty
                && set.complexComponents.isEmpty
                && set.resolvedSpecializedMetricKind == .none
                && !set.isVelocityProbe
        }
        return isEligibleForTraditionalSetRecord(set, entry: entry)
    }

    /// The grouping key a load/record comparison must use so a strongman
    /// load never competes against a differently-conventioned load logged
    /// for the same exercise. Every non-strongman set (the entire existing
    /// catalog) resolves to the same fixed suffix, so the composed key is
    /// still unique per exercise exactly as before.
    static func loadComparisonGroupKey(_ set: ExerciseSet) -> String {
        StrongmanLoadComparability.comparisonGroupKey(set.strongmanLoadConvention)
    }

    static func isEligibleForVelocityRecord(_ set: ExerciseSet) -> Bool {
        guard set.done,
              let source = set.velocityMeasurementSource,
              source != .estimated
        else { return false }
        return [set.meanVelocity, set.peakVelocity].contains {
            guard let value = $0 else { return false }
            return value.isFinite && value > 0
        }
    }

    static func isEligibleForSpecializedMetricRecord(_ set: ExerciseSet) -> Bool {
        guard set.done,
              set.resolvedSpecializedMetricKind != .none,
              let source = set.specializedMetricMeasurementSource,
              source != .estimated,
              let metric = specializedMetricValue(for: set),
              metric.value.isFinite,
              metric.value > 0
        else { return false }
        return true
    }

    static func specializedMetricValue(for set: ExerciseSet) -> (value: Double, unit: String)? {
        switch set.resolvedSpecializedMetricKind {
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
            guard let value = block.scoreValue, value.isFinite, value > 0 else { return nil }
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
            guard let value = block.scoreValue, value.isFinite, value > 0 else { return nil }
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
        // Compares one completed block against another across sessions, so the
        // components are keyed by their historical identity. Keying on the
        // live relationship would have let a catalogue change silently make
        // two structurally identical blocks stop comparing.
        let componentIDs = WorkoutExecutionBlockService.entries(in: block, workout: workout)
            .map(HistoricalExerciseIdentityPolicy.comparisonKey(for:))
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

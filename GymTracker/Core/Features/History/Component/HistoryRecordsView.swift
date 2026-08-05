import SwiftData
import SwiftUI

struct HistoryRecordsView: View {
    let workouts: [Workout]

    var body: some View {
        let loadRecords = bestLoadRecords
        let repRecords = bestRepRecords
        let velocity = velocityRecords
        let specialized = specializedMetricRecords
        let blockScores = blockScoreRecords
        let notable = notableSessions

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Records")
                        .font(AppFont.displayMedium)
                    Text("Personal bests from completed workouts.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }

                if loadRecords.isEmpty && repRecords.isEmpty && velocity.isEmpty && specialized.isEmpty && blockScores.isEmpty && notable.isEmpty {
                    ContentUnavailableView(
                        "No records yet",
                        systemImage: AppIcon.trophy,
                        description: Text("Complete weighted or rep-based sets to establish personal bests.")
                    )
                } else {
                    if !loadRecords.isEmpty {
                        recordsSection("Best load", icon: AppIcon.workout, records: loadRecords)
                    }
                    if !repRecords.isEmpty {
                        recordsSection("Best reps", icon: AppIcon.number, records: repRecords)
                    }
                    if !velocity.isEmpty {
                        recordsSection("Velocity records", icon: AppIcon.progression, records: velocity)
                    }
                    if !specialized.isEmpty {
                        recordsSection("Power & implement records", icon: AppIcon.trophy, records: specialized)
                    }
                    if !blockScores.isEmpty {
                        recordsSection("Format records", icon: AppIcon.relationship, records: blockScores)
                    }
                    if !notable.isEmpty {
                        notableSection(notable)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
    }

    private func recordsSection(_ title: String, icon: String, records: [HistoryRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label(title, systemImage: icon)
                .font(AppFont.titleSmallSemibold)
            ForEach(records) { record in
                recordRow(record)
            }
        }
    }

    private func notableSection(_ sessions: [HistorySessionRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("Notable sessions", systemImage: AppIcon.favoriteFilled)
                .font(AppFont.titleSmallSemibold)
            ForEach(sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(session.title)
                            .font(AppFont.bodyMedium)
                        Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    Spacer()
                    Text("\(Formatters.formatFloat(session.volume)) \(session.unit) volume")
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymPrimary)
                }
                .padding(Spacing.m)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
    }

    private func recordRow(_ record: HistoryRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(record.exercise)
                    .font(AppFont.bodyMedium)
                Text(record.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer()
            Text(record.valueText)
                .font(AppFont.headlineMonospaced)
                .foregroundStyle(Color.gymPrimary)
        }
        .padding(Spacing.m)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .combine)
    }

    private var bestLoadRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises where exercise.trackingTypeSnapshot.usesWeight {
                for set in exercise.orderedSets where StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set) && set.weight > 0 {
                    // A differing load convention (total vs. per-hand, etc.)
                    // must never compete for the same record line — see
                    // `StrongmanLoadComparability`. Every non-strongman set
                    // resolves to the same fixed suffix, so this key is
                    // identical to the pre-existing `occurrenceComparisonKey`
                    // for the entire existing catalog.
                    let key = exercise.occurrenceComparisonKey + "|" + StrengthAnalyticsPolicy.loadComparisonGroupKey(set)
                    let candidate = HistoryRecord(exercise: exercise.occurrenceDisplayName, value: set.weight, unit: set.weightType.rawValue, date: workout.startTime, kind: "load")
                    if candidate.value > (best[key]?.value ?? 0) { best[key] = candidate }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var bestRepRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises where exercise.trackingTypeSnapshot.usesReps {
                for set in exercise.orderedSets where StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set) && set.repetitions > 0 {
                    let key = exercise.occurrenceComparisonKey
                    let candidate = HistoryRecord(exercise: exercise.occurrenceDisplayName, value: set.repetitions, unit: "reps", date: workout.startTime, kind: "reps")
                    if candidate.value > (best[key]?.value ?? 0) { best[key] = candidate }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var velocityRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises {
                for set in exercise.orderedSets where StrengthAnalyticsPolicy.isEligibleForVelocityRecord(set) {
                    let velocity = max(set.meanVelocity ?? 0, set.peakVelocity ?? 0)
                    let candidate = HistoryRecord(
                        exercise: exercise.occurrenceDisplayName,
                        value: Float(velocity),
                        unit: "m/s",
                        date: workout.startTime,
                        kind: "velocity"
                    )
                    let key = exercise.occurrenceComparisonKey
                    if candidate.value > (best[key]?.value ?? 0) {
                        best[key] = candidate
                    }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var specializedMetricRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises {
                for set in exercise.orderedSets where StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(set) {
                    guard let metric = StrengthAnalyticsPolicy.specializedMetricValue(for: set) else { continue }
                    let kind = set.resolvedSpecializedMetricKind
                    let key = "\(exercise.occurrenceComparisonKey)|\(kind.rawValue)"
                    let candidate = HistoryRecord(
                        exercise: "\(exercise.occurrenceDisplayName) · \(kind.title)",
                        value: Float(metric.value),
                        unit: metric.unit,
                        date: workout.startTime,
                        kind: "specialized-\(kind.rawValue)"
                    )
                    guard let prior = best[key] else { best[key] = candidate; continue }
                    let isImprovement = StrengthAnalyticsPolicy.prefersLowerSpecializedMetric(kind)
                        ? candidate.value < prior.value
                        : candidate.value > prior.value
                    if isImprovement { best[key] = candidate }
                }
            }
        }
        return best.values.sorted { $0.date > $1.date }
    }

    private var blockScoreRecords: [HistoryRecord] {
        var best: [String: BlockRecordCandidate] = [:]
        for workout in workouts {
            for block in workout.orderedExecutionBlocks {
                guard let candidate = StrengthAnalyticsPolicy.blockCandidate(for: block, in: workout) else { continue }
                guard let prior = best[candidate.comparisonKey] else { best[candidate.comparisonKey] = candidate; continue }
                if candidate.lowerIsBetter ? candidate.value < prior.value : candidate.value > prior.value {
                    best[candidate.comparisonKey] = candidate
                }
            }
        }
        return best.values.map {
            HistoryRecord(
                exercise: $0.title,
                value: Float($0.value),
                unit: $0.scoreKind.title,
                date: $0.date,
                kind: "block-\($0.comparisonKey)",
                displayValueText: $0.displayValue
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var notableSessions: [HistorySessionRecord] {
        // Sets carry their own `weightType`, so summing each set "in its own
        // unit" (as this used to do) mixes kg and lbs into one meaningless
        // number whenever a session logs both. Every set must be converted
        // to a single unit before summing — the user's display unit, since
        // this total is shown to the user (see `HistoryProgressView`'s
        // identical `displayWeightType` for the established convention;
        // internal-math call sites like `PlanProgressionEvaluationService`
        // use a fixed `.kg` instead because they don't render to the UI).
        let displayWeightType: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        return workouts.map { workout in
            let volume = workout.orderedExercises.reduce(Float.zero) { total, exercise in
                let trackingType = exercise.trackingTypeSnapshot
                guard trackingType.usesWeight && trackingType.usesReps else { return total }
                return total + exercise.orderedSets.filter(\.done).reduce(Float.zero) { subtotal, set in
                    subtotal + VolumeCalculator.setVolume(
                        weight: set.weight,
                        weightType: set.weightType,
                        repetitions: set.repetitions,
                        semantics: exercise.loggingSemanticsSnapshot,
                        in: displayWeightType
                    )
                }
            }
            return HistorySessionRecord(title: workout.displayTitle, volume: volume, unit: displayWeightType.rawValue, date: workout.startTime)
        }
        .filter { $0.volume > 0 }
        .sorted { $0.volume > $1.volume }
        .prefix(3)
        .map { $0 }
    }
}

struct HistoryRecord: Identifiable {
    let exercise: String
    let value: Float
    let unit: String
    let date: Date
    let kind: String
    var displayValueText: String? = nil

    var id: String { "\(kind)-\(exercise)-\(date.timeIntervalSinceReferenceDate)" }
    var valueText: String { displayValueText ?? "\(Formatters.formatFloat(value)) \(unit)" }
}

struct HistorySessionRecord: Identifiable {
    let title: String
    let volume: Float
    let unit: String
    let date: Date
    var id: String { "\(title)-\(date.timeIntervalSinceReferenceDate)" }
}

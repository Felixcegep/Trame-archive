import Foundation
import CryptoKit

/// Immutable render input for History's exercise-progress destination.
///
/// HistoryView already applies the completed-workout boundary. Keeping this
/// as a value projection means a SwiftData observation update always
/// produces fresh charts without maintaining a second, potentially stale,
/// cache in the view.
struct HistoryProgressProjection {
    let exerciseSeries: [HistoryExerciseSeries]
    let frequencyPoints: [HistoryFrequencyPoint]

    static func make(
        workouts: [Workout],
        displayWeightType: WeightType,
        calendar: Calendar = .autoupdatingCurrent,
        referenceDate: Date = .now
    ) -> Self {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return Self(exerciseSeries: [], frequencyPoints: [])
        }

        let weeks: [(start: Date, end: Date)] = (0..<8).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset - 7, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)
            else { return nil }
            return (start, end)
        }
        var frequencyCounts = Array(repeating: 0, count: weeks.count)
        var seriesByIdentity: [String: HistoryExerciseSeries] = [:]

        // Series points must remain chronological, so order the history once
        // before gathering both chart outputs. The old view performed this
        // sort for trends and then made a second full-history pass for
        // frequency.
        for workout in workouts.sorted(by: { $0.startTime < $1.startTime }) {
            if let index = weeks.firstIndex(where: { workout.startTime >= $0.start && workout.startTime < $0.end }) {
                frequencyCounts[index] += 1
            }

            for exercise in workout.orderedExercises {
                let trackingType = exercise.trackingTypeSnapshot
                let semantics = exercise.loggingSemanticsSnapshot
                // Progress charts are strength projections too: warm-ups,
                // segmented/non-standard methods, complexes, and specialized
                // evidence remain visible in History detail but cannot alter
                // conventional load, volume, or repetition trends.
                let eligibleSets = exercise.orderedSets.filter {
                    StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord($0, entry: exercise)
                }
                let setsByLoadGroup = Dictionary(grouping: eligibleSets) {
                    StrengthAnalyticsPolicy.loadComparisonGroupKey($0)
                }

                for (loadGroupKey, groupedSets) in setsByLoadGroup {
                    var maxLoad: Float?
                    var volume: Float = 0
                    var repetitions: Float = 0

                    for set in groupedSets {
                        if trackingType.usesWeight,
                           set.weight.isFinite,
                           set.weight > 0,
                           (!trackingType.usesReps || (set.repetitions.isFinite && set.repetitions > 0)) {
                            let converted = UnitConversion.weight(
                                set.weight,
                                from: set.weightType,
                                to: displayWeightType
                            )
                            if converted.isFinite {
                                maxLoad = max(maxLoad ?? converted, converted)
                            }
                        }
                        if trackingType.usesWeight && trackingType.usesReps,
                           set.weight.isFinite,
                           set.weight > 0,
                           set.repetitions.isFinite,
                           set.repetitions > 0 {
                            let value = VolumeCalculator.setVolume(
                                weight: set.weight,
                                weightType: set.weightType,
                                repetitions: set.repetitions,
                                semantics: semantics,
                                in: displayWeightType
                            )
                            if value.isFinite, value > 0 {
                                volume += value
                            }
                        }
                        if trackingType.usesReps, set.repetitions.isFinite, set.repetitions > 0 {
                            repetitions += set.repetitions
                        }
                    }

                    guard maxLoad != nil || volume > 0 || repetitions > 0 else { continue }
                    let identity = HistoricalExerciseIdentityPolicy.identity(of: exercise)
                    let seriesKey = "\(identity.uuidString)|\(loadGroupKey)"
                    var series = seriesByIdentity[seriesKey] ?? HistoryExerciseSeries(
                        id: stableSeriesID(identity: identity, loadGroupKey: loadGroupKey),
                        name: exercise.nameSnapshot,
                        unit: trackingType.usesWeight ? displayWeightType.rawValue : ""
                    )
                    // The ascending history traversal lets the last occurrence
                    // retain the current historical display name after a rename.
                    series.name = exercise.nameSnapshot
                    if let maxLoad {
                        series.loadPoints.append(HistoryMetricPoint(date: workout.startTime, value: maxLoad))
                    }
                    if volume > 0 {
                        series.volumePoints.append(HistoryMetricPoint(date: workout.startTime, value: volume))
                    }
                    if repetitions > 0 {
                        series.repsPoints.append(HistoryMetricPoint(date: workout.startTime, value: repetitions))
                    }
                    seriesByIdentity[seriesKey] = series
                }
            }
        }

        let exerciseSeries = seriesByIdentity.values.sorted {
            if $0.totalPointCount != $1.totalPointCount {
                return $0.totalPointCount > $1.totalPointCount
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        let frequencyPoints = weeks.enumerated().map { index, interval in
            HistoryFrequencyPoint(start: interval.start, count: frequencyCounts[index])
        }
        return Self(exerciseSeries: exerciseSeries, frequencyPoints: frequencyPoints)
    }

    private static func stableSeriesID(identity: UUID, loadGroupKey: String) -> UUID {
        guard loadGroupKey != "legacyOrNonStrongman" else { return identity }
        var bytes = Array(SHA256.hash(data: Data("\(identity.uuidString)|\(loadGroupKey)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

/// Immutable render input for History's records destination. One traversal of
/// the completed graph gathers every record category and the notable-session
/// cards, instead of re-walking it once per section during each body update.
struct HistoryRecordsProjection {
    let loadRecords: [HistoryRecord]
    let repRecords: [HistoryRecord]
    let velocityRecords: [HistoryRecord]
    let specializedMetricRecords: [HistoryRecord]
    let blockScoreRecords: [HistoryRecord]
    let notableSessions: [HistorySessionRecord]

    static func make(workouts: [Workout], displayWeightType: WeightType) -> Self {
        var bestLoad: [String: HistoryRecord] = [:]
        var bestReps: [String: HistoryRecord] = [:]
        var bestVelocity: [String: HistoryRecord] = [:]
        var bestSpecialized: [String: HistoryRecord] = [:]
        var bestBlockScores: [String: BlockRecordCandidate] = [:]
        var notableSessions: [HistorySessionRecord] = []

        for workout in workouts {
            var workoutVolume: Float = 0

            for exercise in workout.orderedExercises {
                let trackingType = exercise.trackingTypeSnapshot
                let semantics = exercise.loggingSemanticsSnapshot

                for set in exercise.orderedSets {
                    let isTraditionalRecord = (trackingType.usesWeight || trackingType.usesReps)
                        && StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set, entry: exercise)
                    if isTraditionalRecord,
                       trackingType.usesWeight,
                       trackingType.usesReps,
                       set.weight.isFinite,
                       set.weight > 0,
                       set.repetitions.isFinite,
                       set.repetitions > 0 {
                        let volume = VolumeCalculator.setVolume(
                            weight: set.weight,
                            weightType: set.weightType,
                            repetitions: set.repetitions,
                            semantics: semantics,
                            in: displayWeightType
                        )
                        if volume.isFinite, volume > 0 {
                            workoutVolume += volume
                        }
                    }

                    if trackingType.usesWeight,
                       isTraditionalRecord,
                       set.weight.isFinite,
                       set.weight > 0,
                       (!trackingType.usesReps || (set.repetitions.isFinite && set.repetitions > 0)) {
                        let normalizedLoad = UnitConversion.weight(
                            set.weight,
                            from: set.weightType,
                            to: displayWeightType
                        )
                        if normalizedLoad.isFinite {
                            let key = exercise.occurrenceComparisonKey + "|" + StrengthAnalyticsPolicy.loadComparisonGroupKey(set)
                            let candidate = HistoryRecord(
                                exercise: exercise.occurrenceDisplayName,
                                value: normalizedLoad,
                                unit: displayWeightType.rawValue,
                                date: workout.startTime,
                                kind: "load"
                            )
                            if candidate.value > (bestLoad[key]?.value ?? 0) {
                                bestLoad[key] = candidate
                            }
                        }
                    }

                    if trackingType.usesReps,
                       isTraditionalRecord,
                       set.repetitions.isFinite,
                       set.repetitions > 0 {
                        let key = exercise.occurrenceComparisonKey
                        let candidate = HistoryRecord(
                            exercise: exercise.occurrenceDisplayName,
                            value: set.repetitions,
                            unit: "reps",
                            date: workout.startTime,
                            kind: "reps"
                        )
                        if candidate.value > (bestReps[key]?.value ?? 0) {
                            bestReps[key] = candidate
                        }
                    }

                    if StrengthAnalyticsPolicy.isEligibleForVelocityRecord(set) {
                        let velocities = [set.meanVelocity, set.peakVelocity].compactMap { value in
                            value.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
                        }
                        guard let value = velocities.max().map({ Float($0) }), value.isFinite else { continue }
                        let key = exercise.occurrenceComparisonKey
                        let candidate = HistoryRecord(
                            exercise: exercise.occurrenceDisplayName,
                            value: value,
                            unit: "m/s",
                            date: workout.startTime,
                            kind: "velocity"
                        )
                        if candidate.value > (bestVelocity[key]?.value ?? 0) {
                            bestVelocity[key] = candidate
                        }
                    }

                    if StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(set),
                       let metric = StrengthAnalyticsPolicy.specializedMetricValue(for: set) {
                        let kind = set.resolvedSpecializedMetricKind
                        guard metric.value.isFinite, metric.value > 0 else { continue }
                        let key = "\(exercise.occurrenceComparisonKey)|\(kind.rawValue)"
                        let candidate = HistoryRecord(
                            exercise: "\(exercise.occurrenceDisplayName) · \(kind.title)",
                            value: Float(metric.value),
                            unit: metric.unit,
                            date: workout.startTime,
                            kind: "specialized-\(kind.rawValue)"
                        )
                        let improves = bestSpecialized[key].map {
                            StrengthAnalyticsPolicy.prefersLowerSpecializedMetric(kind)
                                ? candidate.value < $0.value
                                : candidate.value > $0.value
                        } ?? true
                        if improves {
                            bestSpecialized[key] = candidate
                        }
                    }
                }
            }

            if workoutVolume > 0 {
                retainNotableSession(HistorySessionRecord(
                    title: workout.displayTitle,
                    volume: workoutVolume,
                    unit: displayWeightType.rawValue,
                    date: workout.startTime
                ), in: &notableSessions)
            }

            for block in workout.orderedExecutionBlocks {
                guard let candidate = StrengthAnalyticsPolicy.blockCandidate(for: block, in: workout) else { continue }
                guard let prior = bestBlockScores[candidate.comparisonKey] else {
                    bestBlockScores[candidate.comparisonKey] = candidate
                    continue
                }
                if candidate.lowerIsBetter ? candidate.value < prior.value : candidate.value > prior.value {
                    bestBlockScores[candidate.comparisonKey] = candidate
                }
            }
        }

        return Self(
            loadRecords: bestLoad.values.sorted(by: Self.sortByValueThenDate),
            repRecords: bestReps.values.sorted(by: Self.sortByValueThenDate),
            velocityRecords: bestVelocity.values.sorted(by: Self.sortByValueThenDate),
            specializedMetricRecords: bestSpecialized.values.sorted(by: Self.sortByDateThenIdentity),
            blockScoreRecords: bestBlockScores.values.map(Self.record(from:)).sorted(by: Self.sortByDateThenIdentity),
            notableSessions: notableSessions
        )
    }

    private static func retainNotableSession(
        _ candidate: HistorySessionRecord,
        in sessions: inout [HistorySessionRecord]
    ) {
        let insertionIndex = sessions.firstIndex {
            sortSessionsByVolumeThenDate(candidate, $0)
        } ?? sessions.endIndex
        sessions.insert(candidate, at: insertionIndex)
        if sessions.count > 3 {
            sessions.removeLast()
        }
    }

    nonisolated private static func record(from candidate: BlockRecordCandidate) -> HistoryRecord {
        HistoryRecord(
            exercise: candidate.title,
            value: Float(candidate.value),
            unit: candidate.scoreKind.title,
            date: candidate.date,
            kind: "block-\(candidate.comparisonKey)",
            displayValueText: candidate.displayValue
        )
    }

    nonisolated private static func sortByValueThenDate(_ lhs: HistoryRecord, _ rhs: HistoryRecord) -> Bool {
        if lhs.value != rhs.value { return lhs.value > rhs.value }
        return sortByDateThenIdentity(lhs, rhs)
    }

    nonisolated private static func sortByDateThenIdentity(_ lhs: HistoryRecord, _ rhs: HistoryRecord) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        if lhs.exercise != rhs.exercise { return lhs.exercise < rhs.exercise }
        return lhs.kind < rhs.kind
    }

    nonisolated private static func sortSessionsByVolumeThenDate(_ lhs: HistorySessionRecord, _ rhs: HistorySessionRecord) -> Bool {
        if lhs.volume != rhs.volume { return lhs.volume > rhs.volume }
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        return lhs.title < rhs.title
    }
}

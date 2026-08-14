import Foundation
import SwiftData

struct PersonalRecordItem: Equatable, Sendable, Identifiable {
    /// A display name/date pair is not an identity: two historical
    /// occurrences can legitimately share both.  The source reference keeps
    /// SwiftUI identity stable even when duplicate exercises are logged in
    /// one workout.
    var id: String { "\(exerciseIdentity):\(kind):\(source.id)" }
    let exerciseName: String
    let exerciseIdentity: String
    let kind: String
    let value: Float
    let displayValue: String
    let unit: String
    let date: Date
    let source: AnalyticsSourceReference
}

struct ProgressOverviewWorkoutAnalyticsProjection: Sendable {
    let selectedRecords: [PersonalRecordItem]
    let exerciseSeries: [ExerciseProgressSeries]
}

/// Pure service for computing personal records and notable historical milestones across completed workouts.
@MainActor
struct PersonalRecordAnalyticsService {
    let modelContext: ModelContext

    private struct RecordProjectionOutput {
        let records: [[PersonalRecordItem]]
        let exerciseSeries: [ExerciseProgressSeries]
    }

    func personalRecords(
        dateRange: AnalyticsDateRange = .allTime,
        referenceDate: Date = .now,
        displayWeightType: WeightType = .kg
    ) throws -> [PersonalRecordItem] {
        let predicate: Predicate<Workout>?
        if let interval = dateRange.dateInterval(endingAt: referenceDate) {
            let start = interval.start
            let end = interval.end
            predicate = #Predicate<Workout> { workout in
                workout.startTime >= start && workout.startTime <= end
            }
        } else {
            predicate = nil
        }

        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Workout.startTime, order: .forward)]
        )
        return Self.personalRecords(
            workouts: try modelContext.fetch(descriptor),
            dateRange: dateRange,
            referenceDate: referenceDate,
            displayWeightType: displayWeightType
        )
    }

    /// Pure projection entry point for a caller that already owns the history
    /// query. Completed snapshots remain the only accepted evidence.
    static func personalRecords(
        workouts: [Workout],
        dateRange: AnalyticsDateRange = .allTime,
        referenceDate: Date = .now,
        displayWeightType: WeightType = .kg
    ) -> [PersonalRecordItem] {
        projectRecords(
            workouts: workouts,
            intervals: [dateRange.dateInterval(endingAt: referenceDate)],
            displayWeightType: displayWeightType
        ).records[0]
    }

    /// Produces records and exercise series in one graph traversal for the
    /// Progress overview. Both projections consume the same eligible sets.
    static func overviewAnalytics(
        workouts: [Workout],
        dateRange: AnalyticsDateRange,
        referenceDate: Date = .now,
        displayWeightType: WeightType = .kg
    ) -> ProgressOverviewWorkoutAnalyticsProjection {
        let projection = projectRecords(
            workouts: workouts,
            intervals: [dateRange.dateInterval(endingAt: referenceDate)],
            displayWeightType: displayWeightType,
            seriesIntervalIndex: 0
        )
        return ProgressOverviewWorkoutAnalyticsProjection(
            selectedRecords: projection.records[0],
            exerciseSeries: projection.exerciseSeries
        )
    }

    private static func projectRecords(
        workouts: [Workout],
        intervals: [DateInterval?],
        displayWeightType: WeightType,
        seriesIntervalIndex: Int? = nil
    ) -> RecordProjectionOutput {
        typealias Candidate = (
            value: Float,
            set: ExerciseSet,
            exercise: ExerciseEntry,
            workout: Workout
        )

        var maxLoadByInterval = intervals.map { _ in [String: Candidate]() }
        var maxVolumeByInterval = intervals.map { _ in [String: Candidate]() }
        var seriesByIdentity: [String: ExerciseProgressSeries] = [:]
        // ProgressHub observes workouts newest-first, while chart points must
        // remain chronological (the former store-backed path explicitly
        // fetched them in ascending order). Only the combined series path
        // pays for this ordering; records alone are order-independent.
        let projectionWorkouts = seriesIntervalIndex == nil ? workouts : workouts.sorted {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.id.uuidString < $1.id.uuidString
        }

        for workout in projectionWorkouts where workout.status == .completed {
            var matchingIntervals: [Int] = []
            for index in intervals.indices {
                if intervals[index].map({
                    workout.startTime >= $0.start && workout.startTime <= $0.end
                }) ?? true {
                    matchingIntervals.append(index)
                }
            }
            guard matchingIntervals.isEmpty == false else { continue }
            let collectsSeries = seriesIntervalIndex.map { matchingIntervals.contains($0) } ?? false

            for exercise in workout.orderedExercises {
                let identityKey = HistoricalExerciseIdentityPolicy.comparisonKey(for: exercise)
                let trackingType = exercise.trackingTypeSnapshot
                let completedSets = exercise.orderedSets.filter {
                    StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord($0, entry: exercise)
                }
                let setsByLoadGroup = Dictionary(grouping: completedSets) {
                    StrengthAnalyticsPolicy.loadComparisonGroupKey($0)
                }

                for (loadGroupKey, groupedSets) in setsByLoadGroup {
                    let comparisonKey = "\(identityKey)|\(loadGroupKey)"
                    var seriesMaxLoad: Float?
                    var seriesVolume: Float = 0
                    var seriesRepetitions: Float = 0

                    for set in groupedSets {
                        let hasValidWeight = set.weight.isFinite && set.weight > 0
                        let hasValidRepetitions = set.repetitions.isFinite && set.repetitions > 0
                        let isSeriesEligible = (!trackingType.usesWeight || hasValidWeight)
                            && (!trackingType.usesReps || hasValidRepetitions)

                        if trackingType.usesWeight,
                           hasValidWeight,
                           (!trackingType.usesReps || hasValidRepetitions) {
                            let loadInDisplayUnit = UnitConversion.weight(set.weight, from: set.weightType, to: displayWeightType)
                            if loadInDisplayUnit.isFinite {
                                if collectsSeries && isSeriesEligible {
                                    seriesMaxLoad = max(seriesMaxLoad ?? loadInDisplayUnit, loadInDisplayUnit)
                                }
                                for index in matchingIntervals {
                                    if let currentMax = maxLoadByInterval[index][comparisonKey] {
                                        if loadInDisplayUnit > currentMax.value {
                                            maxLoadByInterval[index][comparisonKey] = (loadInDisplayUnit, set, exercise, workout)
                                        }
                                    } else {
                                        maxLoadByInterval[index][comparisonKey] = (loadInDisplayUnit, set, exercise, workout)
                                    }
                                }
                            }
                        }

                        if trackingType.usesWeight && trackingType.usesReps && isSeriesEligible {
                            let volumeInDisplayUnit = VolumeCalculator.setVolume(
                                weight: set.weight,
                                weightType: set.weightType,
                                repetitions: set.repetitions,
                                semantics: exercise.loggingSemanticsSnapshot,
                                in: displayWeightType
                            )
                            if volumeInDisplayUnit.isFinite, volumeInDisplayUnit > 0 {
                                if collectsSeries {
                                    seriesVolume += volumeInDisplayUnit
                                }
                                for index in matchingIntervals {
                                    if let currentMax = maxVolumeByInterval[index][comparisonKey] {
                                        if volumeInDisplayUnit > currentMax.value {
                                            maxVolumeByInterval[index][comparisonKey] = (volumeInDisplayUnit, set, exercise, workout)
                                        }
                                    } else {
                                        maxVolumeByInterval[index][comparisonKey] = (volumeInDisplayUnit, set, exercise, workout)
                                    }
                                }
                            }
                        }

                        if collectsSeries && isSeriesEligible && trackingType.usesReps {
                            seriesRepetitions += set.repetitions
                        }
                    }

                    if collectsSeries,
                       seriesMaxLoad != nil || seriesVolume > 0 || seriesRepetitions > 0 {
                        let source = AnalyticsSourceReference(
                            workoutID: workout.id,
                            entryID: exercise.id
                        )
                        let seriesIdentity = loadGroupKey == "legacyOrNonStrongman"
                            ? identityKey
                            : comparisonKey
                        var series = seriesByIdentity[comparisonKey] ?? ExerciseProgressSeries(
                            identity: seriesIdentity,
                            name: exercise.nameSnapshot,
                            unit: trackingType.usesWeight ? displayWeightType.rawValue : "",
                            loadPoints: [],
                            volumePoints: [],
                            repsPoints: [],
                            quality: .insufficient
                        )
                        series.name = exercise.nameSnapshot
                        if let seriesMaxLoad {
                            series.loadPoints.append(ExerciseProgressPoint(
                                date: workout.startTime,
                                value: seriesMaxLoad,
                                source: source
                            ))
                        }
                        if seriesVolume > 0 {
                            series.volumePoints.append(ExerciseProgressPoint(
                                date: workout.startTime,
                                value: seriesVolume,
                                source: source
                            ))
                        }
                        if seriesRepetitions > 0 {
                            series.repsPoints.append(ExerciseProgressPoint(
                                date: workout.startTime,
                                value: seriesRepetitions,
                                source: source
                            ))
                        }
                        seriesByIdentity[comparisonKey] = series
                    }
                }
            }
        }

        let records = intervals.indices.map { index in
            makeRecords(
                maxLoadByIdentity: maxLoadByInterval[index],
                maxVolumeByIdentity: maxVolumeByInterval[index],
                displayWeightType: displayWeightType
            )
        }
        let exerciseSeries: [ExerciseProgressSeries] = seriesByIdentity.values.map { series in
            let pointCount = max(
                series.loadPoints.count,
                max(series.volumePoints.count, series.repsPoints.count)
            )
            return ExerciseProgressSeries(
                identity: series.identity,
                name: series.name,
                unit: series.unit,
                loadPoints: series.loadPoints,
                volumePoints: series.volumePoints,
                repsPoints: series.repsPoints,
                quality: AnalyticsDataQuality.evaluate(sampleCount: pointCount)
            )
        }.sorted { lhs, rhs in
            lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
        return RecordProjectionOutput(records: records, exerciseSeries: exerciseSeries)
    }

    private static func makeRecords(
        maxLoadByIdentity: [String: (value: Float, set: ExerciseSet, exercise: ExerciseEntry, workout: Workout)],
        maxVolumeByIdentity: [String: (value: Float, set: ExerciseSet, exercise: ExerciseEntry, workout: Workout)],
        displayWeightType: WeightType
    ) -> [PersonalRecordItem] {
        var records: [PersonalRecordItem] = []

        for (_, entry) in maxLoadByIdentity {
            let formatStr = displayWeightType == .kg ? "%.1f kg" : "%.1f lbs"
            records.append(PersonalRecordItem(
                exerciseName: entry.exercise.nameSnapshot,
                exerciseIdentity: HistoricalExerciseIdentityPolicy.comparisonKey(for: entry.exercise),
                kind: "Max Weight",
                value: entry.value,
                displayValue: String(format: formatStr, entry.value),
                unit: displayWeightType.rawValue,
                date: entry.workout.startTime,
                source: AnalyticsSourceReference(
                    workoutID: entry.workout.id,
                    entryID: entry.exercise.id,
                    setID: entry.set.id
                )
            ))
        }

        for (_, entry) in maxVolumeByIdentity {
            let formatStr = displayWeightType == .kg ? "%.0f kg" : "%.0f lbs"
            records.append(PersonalRecordItem(
                exerciseName: entry.exercise.nameSnapshot,
                exerciseIdentity: HistoricalExerciseIdentityPolicy.comparisonKey(for: entry.exercise),
                kind: "Best Set Volume",
                value: entry.value,
                displayValue: String(format: formatStr, entry.value),
                unit: displayWeightType.rawValue,
                date: entry.workout.startTime,
                source: AnalyticsSourceReference(
                    workoutID: entry.workout.id,
                    entryID: entry.exercise.id,
                    setID: entry.set.id
                )
            ))
        }

        return records.sorted { $0.date > $1.date }
    }
}

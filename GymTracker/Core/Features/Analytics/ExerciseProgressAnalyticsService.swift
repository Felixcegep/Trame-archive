import Foundation
import SwiftData

struct ExerciseProgressPoint: Equatable, Sendable, Identifiable {
    var id: String { "\(date.timeIntervalSince1970):\(source.id)" }
    let date: Date
    let value: Float
    let source: AnalyticsSourceReference
}

struct ExerciseProgressSeries: Equatable, Sendable, Identifiable {
    var id: String { identity }
    let identity: String
    var name: String
    let unit: String
    var loadPoints: [ExerciseProgressPoint]
    var volumePoints: [ExerciseProgressPoint]
    var repsPoints: [ExerciseProgressPoint]
    let quality: AnalyticsDataQuality
}

/// Pure service for extracting and aggregating per-exercise historical progress series.
@MainActor
struct ExerciseProgressAnalyticsService {
    let modelContext: ModelContext

    func series(
        dateRange: AnalyticsDateRange = .allTime,
        referenceDate: Date = .now,
        displayWeightType: WeightType = .kg
    ) throws -> [ExerciseProgressSeries] {
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
        return Self.series(
            workouts: try modelContext.fetch(descriptor),
            dateRange: dateRange,
            referenceDate: referenceDate,
            displayWeightType: displayWeightType
        )
    }

    /// Pure projection entry point for callers that already observe workout
    /// history, avoiding another persistence fetch for the same date range.
    static func series(
        workouts: [Workout],
        dateRange: AnalyticsDateRange = .allTime,
        referenceDate: Date = .now,
        displayWeightType: WeightType = .kg
    ) -> [ExerciseProgressSeries] {
        let interval = dateRange.dateInterval(endingAt: referenceDate)
        let workouts = workouts
            .filter { workout in
                workout.status == .completed && (interval.map {
                    workout.startTime >= $0.start && workout.startTime <= $0.end
                } ?? true)
            }
            .sorted {
                if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
                return $0.id.uuidString < $1.id.uuidString
            }

        var byIdentity: [String: ExerciseProgressSeries] = [:]

        for workout in workouts {
            for exercise in workout.orderedExercises {
                let trackingType = exercise.trackingTypeSnapshot
                let completedSets = exercise.orderedSets.filter {
                    StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord($0, entry: exercise)
                        && (!trackingType.usesWeight || ($0.weight.isFinite && $0.weight > 0))
                        && (!trackingType.usesReps || ($0.repetitions.isFinite && $0.repetitions > 0))
                }
                let identityKey = HistoricalExerciseIdentityPolicy.comparisonKey(for: exercise)

                // A load convention is part of the historical measurement. A
                // yoke's total load and a farmer's carry's per-hand load must
                // never share one progress line or volume maximum.
                let setsByLoadGroup = Dictionary(grouping: completedSets) {
                    StrengthAnalyticsPolicy.loadComparisonGroupKey($0)
                }
                for (loadGroupKey, groupedSets) in setsByLoadGroup {
                    let load = trackingType.usesWeight
                        ? groupedSets
                            .compactMap { set -> Float? in
                                guard set.weight.isFinite, set.weight > 0 else { return nil }
                                let converted = UnitConversion.weight(set.weight, from: set.weightType, to: displayWeightType)
                                return converted.isFinite ? converted : nil
                            }
                            .max()
                        : nil

                    let semantics = exercise.loggingSemanticsSnapshot
                    let volume = trackingType.usesWeight && trackingType.usesReps
                        ? groupedSets.reduce(Float.zero) { total, set in
                            let value = VolumeCalculator.setVolume(
                                weight: set.weight,
                                weightType: set.weightType,
                                repetitions: set.repetitions,
                                semantics: semantics,
                                in: displayWeightType
                            )
                            return total + (value.isFinite && value > 0 ? value : 0)
                        }
                        : 0

                    let reps = groupedSets.reduce(Float.zero) { total, set in
                        guard trackingType.usesReps, set.repetitions.isFinite, set.repetitions > 0 else { return total }
                        return total + set.repetitions
                    }

                    guard load != nil || volume > 0 || reps > 0 else { continue }
                    let seriesKey = "\(identityKey)|\(loadGroupKey)"
                    let seriesIdentity = loadGroupKey == "legacyOrNonStrongman"
                        ? identityKey
                        : seriesKey
                    let sourceRef = AnalyticsSourceReference(workoutID: workout.id, entryID: exercise.id)

                    var currentSeries = byIdentity[seriesKey] ?? ExerciseProgressSeries(
                        identity: seriesIdentity,
                        name: exercise.nameSnapshot,
                        unit: trackingType.usesWeight ? displayWeightType.rawValue : "",
                        loadPoints: [],
                        volumePoints: [],
                        repsPoints: [],
                        quality: .insufficient
                    )

                    currentSeries.name = exercise.nameSnapshot
                    if let load {
                        currentSeries.loadPoints.append(ExerciseProgressPoint(date: workout.startTime, value: load, source: sourceRef))
                    }
                    if volume > 0 {
                        currentSeries.volumePoints.append(ExerciseProgressPoint(date: workout.startTime, value: volume, source: sourceRef))
                    }
                    if reps > 0 {
                        currentSeries.repsPoints.append(ExerciseProgressPoint(date: workout.startTime, value: reps, source: sourceRef))
                    }
                    byIdentity[seriesKey] = currentSeries
                }
            }
        }

        return byIdentity.values.map { series in
            let maxPoints = max(series.loadPoints.count, max(series.volumePoints.count, series.repsPoints.count))
            return ExerciseProgressSeries(
                identity: series.identity,
                name: series.name,
                unit: series.unit,
                loadPoints: series.loadPoints,
                volumePoints: series.volumePoints,
                repsPoints: series.repsPoints,
                quality: AnalyticsDataQuality.evaluate(sampleCount: maxPoints)
            )
        }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

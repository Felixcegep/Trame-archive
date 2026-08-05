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
struct ExerciseProgressAnalyticsService: Sendable {
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
        let workouts = try modelContext.fetch(descriptor).filter { $0.status == .completed }

        var byIdentity: [String: ExerciseProgressSeries] = [:]

        for workout in workouts {
            for exercise in workout.orderedExercises {
                let trackingType = exercise.trackingTypeSnapshot
                let completedSets = exercise.orderedSets.filter(\.done)
                guard !completedSets.isEmpty else { continue }

                let load = completedSets
                    .map { UnitConversion.weight($0.weight, from: $0.weightType, to: displayWeightType) }
                    .max()

                let semantics = exercise.loggingSemanticsSnapshot
                let volume = trackingType.usesWeight && trackingType.usesReps
                    ? completedSets.reduce(Float.zero) { total, set in
                        total + VolumeCalculator.setVolume(
                            weight: set.weight,
                            weightType: set.weightType,
                            repetitions: set.repetitions,
                            semantics: semantics,
                            in: displayWeightType
                        )
                    }
                    : 0

                let reps = completedSets.reduce(Float.zero) { $0 + (trackingType.usesReps ? $1.repetitions : 0) }

                guard load != nil || volume > 0 || reps > 0 else { continue }
                let identityKey = HistoricalExerciseIdentityPolicy.comparisonKey(for: exercise)
                let sourceRef = AnalyticsSourceReference(workoutID: workout.id, entryID: exercise.id)

                var currentSeries = byIdentity[identityKey] ?? ExerciseProgressSeries(
                    identity: identityKey,
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
                byIdentity[identityKey] = currentSeries
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

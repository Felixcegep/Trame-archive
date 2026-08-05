import Foundation
import SwiftData

struct PersonalRecordItem: Equatable, Sendable, Identifiable {
    var id: String { "\(exerciseName):\(kind):\(date.timeIntervalSince1970)" }
    let exerciseName: String
    let exerciseIdentity: String
    let kind: String
    let value: Float
    let displayValue: String
    let unit: String
    let date: Date
    let source: AnalyticsSourceReference
}

/// Pure service for computing personal records and notable historical milestones across completed workouts.
struct PersonalRecordAnalyticsService: Sendable {
    let modelContext: ModelContext

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
        let workouts = try modelContext.fetch(descriptor).filter { $0.status == .completed }

        var maxLoadByIdentity: [String: (value: Float, set: ExerciseSet, exercise: ExerciseEntry, workout: Workout)] = [:]
        var maxVolumeByIdentity: [String: (value: Float, set: ExerciseSet, exercise: ExerciseEntry, workout: Workout)] = [:]

        for workout in workouts {
            for exercise in workout.orderedExercises {
                let identityKey = HistoricalExerciseIdentityPolicy.comparisonKey(for: exercise)
                let trackingType = exercise.trackingTypeSnapshot
                let completedSets = exercise.orderedSets.filter(\.done)

                for set in completedSets {
                    if trackingType.usesWeight {
                        let loadInDisplayUnit = UnitConversion.weight(set.weight, from: set.weightType, to: displayWeightType)
                        if let currentMax = maxLoadByIdentity[identityKey] {
                            if loadInDisplayUnit > currentMax.value {
                                maxLoadByIdentity[identityKey] = (loadInDisplayUnit, set, exercise, workout)
                            }
                        } else {
                            maxLoadByIdentity[identityKey] = (loadInDisplayUnit, set, exercise, workout)
                        }
                    }

                    if trackingType.usesWeight && trackingType.usesReps {
                        let volumeInDisplayUnit = VolumeCalculator.setVolume(
                            weight: set.weight,
                            weightType: set.weightType,
                            repetitions: set.repetitions,
                            semantics: exercise.loggingSemanticsSnapshot,
                            in: displayWeightType
                        )
                        if let currentMax = maxVolumeByIdentity[identityKey] {
                            if volumeInDisplayUnit > currentMax.value {
                                maxVolumeByIdentity[identityKey] = (volumeInDisplayUnit, set, exercise, workout)
                            }
                        } else {
                            maxVolumeByIdentity[identityKey] = (volumeInDisplayUnit, set, exercise, workout)
                        }
                    }
                }
            }
        }

        var records: [PersonalRecordItem] = []

        for (identityKey, entry) in maxLoadByIdentity {
            let formatStr = displayWeightType == .kg ? "%.1f kg" : "%.1f lbs"
            records.append(PersonalRecordItem(
                exerciseName: entry.exercise.nameSnapshot,
                exerciseIdentity: identityKey,
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

        for (identityKey, entry) in maxVolumeByIdentity {
            let formatStr = displayWeightType == .kg ? "%.0f kg" : "%.0f lbs"
            records.append(PersonalRecordItem(
                exerciseName: entry.exercise.nameSnapshot,
                exerciseIdentity: identityKey,
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

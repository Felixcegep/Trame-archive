import Foundation
import SwiftData

// MARK: - Value types

struct ExerciseSessionSet: Equatable, Sendable {
    let orderIndex: Int
    let repetitions: Float
    let weight: Float
    let weightType: WeightType
    let setType: SetType
}

struct ExerciseSession: Equatable, Sendable {
    let workoutID: UUID?
    let workoutDate: Date
    let sets: [ExerciseSessionSet]

    init(workoutID: UUID? = nil, workoutDate: Date, sets: [ExerciseSessionSet]) {
        self.workoutID = workoutID
        self.workoutDate = workoutDate
        self.sets = sets
    }

    /// Sets that count toward strength metrics; a warm-up never does.
    var workingSets: [ExerciseSessionSet] {
        sets.filter { $0.setType != .warmup }
    }
}

enum SessionTrend: String, Equatable, Sendable {
    case increased
    case decreased
    case same
}

struct SessionComparison: Equatable, Sendable {
    let previousDate: Date
    let latestDate: Date
    let unit: WeightType
    let previousVolume: Float
    let latestVolume: Float
    let volumeTrend: SessionTrend
    let previousBestLoad: Float
    let latestBestLoad: Float
    let bestLoadTrend: SessionTrend
}

struct ExerciseBestSet: Equatable, Sendable {
    let workoutDate: Date
    let repetitions: Float
    let weight: Float
    let unit: WeightType
}

struct RepRangeBest: Equatable, Sendable {
    let rangeName: String
    let bestSet: ExerciseBestSet
}

struct OneRepMaxEstimate: Equatable, Sendable {
    let estimatedLoad: Float
    let unit: WeightType
    let sourceWeight: Float
    let sourceRepetitions: Float
    let workoutDate: Date
}

struct ExerciseVolumeWeek: Equatable, Sendable {
    let weekStart: Date
    let totalVolume: Float
}

struct ExerciseNote: Equatable, Sendable {
    let workoutDate: Date
    let text: String
}

struct ExerciseDetailAnalytics: Equatable, Sendable {
    let unit: WeightType?
    let latestSession: ExerciseSession?
    let sessionComparison: SessionComparison?
    let bestLoadSet: ExerciseBestSet?
    let bestRepetitionSet: ExerciseBestSet?
    let bestSetsByRepRange: [RepRangeBest]
    let estimatedOneRepMax: OneRepMaxEstimate?
    let weeklyVolume: [ExerciseVolumeWeek]
    let notes: [ExerciseNote]
}

/// Read-only analytics for the per-exercise detail page. Every figure is
/// derived from `completed` workouts only, so an active or discarded workout
/// can never influence a PR, trend, or volume number.
struct ExerciseDetailAnalyticsService {
    let modelContext: ModelContext

    /// Rep brackets a lifter actually programs around. A bucket only appears
    /// in the result when history has a qualifying set for it.
    private enum RepRangeBucket: CaseIterable {
        case strength
        case hypertrophy
        case endurance

        var name: String {
            switch self {
            case .strength: "1–5"
            case .hypertrophy: "6–12"
            case .endurance: "13+"
            }
        }

        func contains(_ repetitions: Float) -> Bool {
            let reps = Int(repetitions.rounded())
            return switch self {
            case .strength: (1...5).contains(reps)
            case .hypertrophy: (6...12).contains(reps)
            case .endurance: reps >= 13
            }
        }
    }

    func analytics(
        for exercise: Exercise,
        referenceDate: Date = .now,
        weekCount: Int = 8
    ) throws -> ExerciseDetailAnalytics {
        let workouts = try completedWorkouts(before: referenceDate)
        let sessions = sessions(from: workouts, for: exercise)
        let notes = notes(from: workouts, for: exercise)

        guard let latestSession = sessions.last else {
            return ExerciseDetailAnalytics(
                unit: nil,
                latestSession: nil,
                sessionComparison: nil,
                bestLoadSet: nil,
                bestRepetitionSet: nil,
                bestSetsByRepRange: [],
                estimatedOneRepMax: nil,
                weeklyVolume: weeklyVolume(in: [], unit: .kg, endingAt: referenceDate, count: weekCount),
                notes: notes
            )
        }

        let unit = latestSession.workingSets.last?.weightType ?? latestSession.sets.last?.weightType ?? .kg
        let previousSession = sessions.dropLast().last
        let includesLoad = includesLoadMetrics(exercise.trackingType)
        let includesReps = exercise.trackingType.usesReps

        return ExerciseDetailAnalytics(
            unit: unit,
            latestSession: latestSession,
            sessionComparison: previousSession.map {
                sessionComparison(previous: $0, latest: latestSession, unit: unit)
            },
            bestLoadSet: includesLoad ? bestLoadSet(in: sessions, unit: unit) : nil,
            bestRepetitionSet: includesReps ? bestRepetitionSet(in: sessions, unit: unit) : nil,
            bestSetsByRepRange: includesLoad ? bestSetsByRepRange(in: sessions, unit: unit) : [],
            estimatedOneRepMax: includesLoad ? estimatedOneRepMax(in: sessions, unit: unit) : nil,
            weeklyVolume: includesLoad
                ? weeklyVolume(in: sessions, unit: unit, endingAt: referenceDate, count: weekCount)
                : weeklyVolume(in: [], unit: .kg, endingAt: referenceDate, count: weekCount),
            notes: notes
        )
    }

    // MARK: Fetching

    private func completedWorkouts(before date: Date) throws -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [
                SortDescriptor(\Workout.startTime, order: .forward),
                SortDescriptor(\Workout.id, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor).filter { $0.status == .completed && $0.startTime <= date }
    }

    /// Chronological (oldest first) sessions so the latest is always `.last`.
    private func sessions(from workouts: [Workout], for exercise: Exercise) -> [ExerciseSession] {
        workouts.compactMap { workout -> ExerciseSession? in
            guard let entry = workout.orderedExercises.first(where: {
                $0.exercise.persistentModelID == exercise.persistentModelID
            }) else { return nil }

            let sets = entry.orderedSets
                .filter(\.done)
                .map {
                    ExerciseSessionSet(
                        orderIndex: $0.orderIndex,
                        repetitions: $0.repetitions,
                        weight: $0.weight,
                        weightType: $0.weightType,
                        setType: $0.setType
                    )
                }
            guard !sets.isEmpty else { return nil }
            return ExerciseSession(workoutID: workout.id, workoutDate: workout.startTime, sets: sets)
        }
    }

    private func notes(from workouts: [Workout], for exercise: Exercise) -> [ExerciseNote] {
        workouts.compactMap { workout -> ExerciseNote? in
            guard let entry = workout.orderedExercises.first(where: {
                $0.exercise.persistentModelID == exercise.persistentModelID
            }) else { return nil }
            let text = entry.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return nil }
            return ExerciseNote(workoutDate: workout.startTime, text: text)
        }
    }

    // MARK: Metrics

    /// Assisted-bodyweight load moves opposite to strength (less assistance
    /// is the improvement), so it is excluded from every load-based PR here,
    /// the same exclusion `ProgressionSnapshotService` applies to recommendations.
    private func includesLoadMetrics(_ trackingType: TrackingType) -> Bool {
        trackingType == .weightAndReps || trackingType == .weightedBodyweight
    }

    private func volume(of sets: [ExerciseSessionSet], in unit: WeightType) -> Float {
        sets.reduce(Float(0)) { partial, set in
            partial + set.repetitions * UnitConversion.weight(set.weight, from: set.weightType, to: unit)
        }
    }

    private func trend(_ previous: Float, _ latest: Float, tolerance: Float = 0.0001) -> SessionTrend {
        if latest > previous + tolerance { return .increased }
        if latest < previous - tolerance { return .decreased }
        return .same
    }

    private func sessionComparison(
        previous: ExerciseSession,
        latest: ExerciseSession,
        unit: WeightType
    ) -> SessionComparison {
        let previousVolume = volume(of: previous.workingSets, in: unit)
        let latestVolume = volume(of: latest.workingSets, in: unit)
        let previousBestLoad = previous.workingSets
            .map { UnitConversion.weight($0.weight, from: $0.weightType, to: unit) }
            .max() ?? 0
        let latestBestLoad = latest.workingSets
            .map { UnitConversion.weight($0.weight, from: $0.weightType, to: unit) }
            .max() ?? 0

        return SessionComparison(
            previousDate: previous.workoutDate,
            latestDate: latest.workoutDate,
            unit: unit,
            previousVolume: previousVolume,
            latestVolume: latestVolume,
            volumeTrend: trend(previousVolume, latestVolume),
            previousBestLoad: previousBestLoad,
            latestBestLoad: latestBestLoad,
            bestLoadTrend: trend(previousBestLoad, latestBestLoad)
        )
    }

    private struct DatedSet {
        let date: Date
        let set: ExerciseSessionSet
    }

    private func workingSets(in sessions: [ExerciseSession]) -> [DatedSet] {
        sessions.flatMap { session in
            session.workingSets.map { DatedSet(date: session.workoutDate, set: $0) }
        }
    }

    private func bestLoadSet(in sessions: [ExerciseSession], unit: WeightType) -> ExerciseBestSet? {
        workingSets(in: sessions)
            .map { entry in
                ExerciseBestSet(
                    workoutDate: entry.date,
                    repetitions: entry.set.repetitions,
                    weight: UnitConversion.weight(entry.set.weight, from: entry.set.weightType, to: unit),
                    unit: unit
                )
            }
            .filter { $0.weight > 0 }
            .max { lhs, rhs in
                lhs.weight == rhs.weight ? lhs.workoutDate > rhs.workoutDate : lhs.weight < rhs.weight
            }
    }

    private func bestRepetitionSet(in sessions: [ExerciseSession], unit: WeightType) -> ExerciseBestSet? {
        workingSets(in: sessions)
            .filter { $0.set.repetitions > 0 }
            .map { entry in
                ExerciseBestSet(
                    workoutDate: entry.date,
                    repetitions: entry.set.repetitions,
                    weight: UnitConversion.weight(entry.set.weight, from: entry.set.weightType, to: unit),
                    unit: unit
                )
            }
            .max { lhs, rhs in
                lhs.repetitions == rhs.repetitions ? lhs.workoutDate > rhs.workoutDate : lhs.repetitions < rhs.repetitions
            }
    }

    private func bestSetsByRepRange(in sessions: [ExerciseSession], unit: WeightType) -> [RepRangeBest] {
        let candidates = workingSets(in: sessions)
        var results: [RepRangeBest] = []
        for bucket in RepRangeBucket.allCases {
            guard let best = bestSet(among: candidates, in: bucket, unit: unit) else { continue }
            results.append(RepRangeBest(rangeName: bucket.name, bestSet: best))
        }
        return results
    }

    private func bestSet(
        among candidates: [DatedSet],
        in bucket: RepRangeBucket,
        unit: WeightType
    ) -> ExerciseBestSet? {
        let bucketed = candidates.filter { bucket.contains($0.set.repetitions) }
        var converted: [ExerciseBestSet] = []
        for entry in bucketed {
            let weight = UnitConversion.weight(entry.set.weight, from: entry.set.weightType, to: unit)
            guard weight > 0 else { continue }
            converted.append(
                ExerciseBestSet(
                    workoutDate: entry.date,
                    repetitions: entry.set.repetitions,
                    weight: weight,
                    unit: unit
                )
            )
        }
        return converted.max { lhs, rhs in
            lhs.weight == rhs.weight ? lhs.workoutDate > rhs.workoutDate : lhs.weight < rhs.weight
        }
    }

    /// Estimated 1RM uses the Epley formula — `weight × (1 + reps ÷ 30)` —
    /// applied to every working set so results stay explainable from one
    /// documented rule rather than switching formulas per exercise or rep count.
    private func estimatedOneRepMax(in sessions: [ExerciseSession], unit: WeightType) -> OneRepMaxEstimate? {
        workingSets(in: sessions)
            .filter { $0.set.repetitions > 0 && $0.set.weight > 0 }
            .map { entry -> OneRepMaxEstimate in
                let convertedWeight = UnitConversion.weight(entry.set.weight, from: entry.set.weightType, to: unit)
                let estimated = convertedWeight * (1 + entry.set.repetitions / 30)
                return OneRepMaxEstimate(
                    estimatedLoad: estimated,
                    unit: unit,
                    sourceWeight: convertedWeight,
                    sourceRepetitions: entry.set.repetitions,
                    workoutDate: entry.date
                )
            }
            .max { lhs, rhs in
                lhs.estimatedLoad == rhs.estimatedLoad ? lhs.workoutDate > rhs.workoutDate : lhs.estimatedLoad < rhs.estimatedLoad
            }
    }

    private func weeklyVolume(
        in sessions: [ExerciseSession],
        unit: WeightType,
        endingAt referenceDate: Date,
        count: Int
    ) -> [ExerciseVolumeWeek] {
        let calendar = Calendar.current
        guard count > 0, let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }

        return (0..<count).reversed().compactMap { offset -> ExerciseVolumeWeek? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart)
            else { return nil }

            let totalVolume = sessions
                .filter { interval.contains($0.workoutDate) }
                .reduce(Float(0)) { $0 + volume(of: $1.workingSets, in: unit) }
            return ExerciseVolumeWeek(weekStart: weekStart, totalVolume: totalVolume)
        }
    }
}

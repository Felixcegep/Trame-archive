import Foundation
import SwiftData

// MARK: - Value types

struct ExerciseSessionSet: Equatable, Sendable {
    let orderIndex: Int
    let repetitions: Float
    let weight: Float
    let weightType: WeightType
    let setType: SetType
    let setMethod: SetMethod
    let hasSegments: Bool
    /// Whether `SportAnalyticsPolicyResolver` allows this specific set to
    /// feed the Epley e1RM estimate. Defaults to `true`, matching every
    /// pre-existing session (which always resolves to
    /// `StandardStrengthAnalyticsPolicy`, itself unconditionally `true` for a
    /// set with no Olympic complex components).
    let contributesToE1RM: Bool

    init(
        orderIndex: Int,
        repetitions: Float,
        weight: Float,
        weightType: WeightType,
        setType: SetType,
        setMethod: SetMethod = .standard,
        hasSegments: Bool = false,
        contributesToE1RM: Bool = true
    ) {
        self.orderIndex = orderIndex
        self.repetitions = repetitions
        self.weight = weight
        self.weightType = weightType
        self.setType = setType
        self.setMethod = setMethod
        self.hasSegments = hasSegments
        self.contributesToE1RM = contributesToE1RM
    }
}

struct ExerciseSession: Equatable, Sendable {
    let workoutID: UUID?
    let workoutDate: Date
    let sets: [ExerciseSessionSet]
    let semantics: LoggingSemantics
    /// The tracking type this occurrence was actually logged under —
    /// `ExerciseEntry.trackingTypeSnapshot`, frozen at entry-creation time.
    /// `Exercise.trackingType` is user-editable at any point, so metric
    /// eligibility must be decided from this snapshot, never from the live
    /// exercise definition.
    let trackingTypeSnapshot: TrackingType

    init(
        workoutID: UUID? = nil,
        workoutDate: Date,
        sets: [ExerciseSessionSet],
        semantics: LoggingSemantics = .default,
        trackingTypeSnapshot: TrackingType
    ) {
        self.workoutID = workoutID
        self.workoutDate = workoutDate
        self.sets = sets
        self.semantics = semantics
        self.trackingTypeSnapshot = trackingTypeSnapshot
    }

    /// Sets that count toward strength metrics; a warm-up never does.
    var workingSets: [ExerciseSessionSet] {
        sets.filter { $0.setType != .warmup && $0.setMethod == .standard && !$0.hasSegments }
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
    let workingSetCount: Int
    let sessionCount: Int
}

struct ExerciseNote: Equatable, Sendable {
    let workoutDate: Date
    let text: String
}

struct ExerciseDetailAnalytics: Equatable, Sendable {
    let sessionCount: Int
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
                sessionCount: 0,
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
        // Eligibility must come from history, not from `exercise.trackingType`:
        // that field is user-editable at any time, and a definition-based
        // check would let editing it *retroactively* rewrite what past
        // sessions show (e.g. an exercise switched from "weight and reps" to
        // "reps only" would silently drop load PRs that were genuinely
        // logged). Each session's `trackingTypeSnapshot` records what the
        // exercise actually was at the moment it was logged, so we ask: did
        // ANY occurrence in range record this metric? That way a tracking
        // type change going forward never erases evidence already recorded,
        // and a series spanning a change reports the union of what both
        // sides logged rather than whatever the exercise happens to be today.
        let includesLoad = sessions.contains { includesLoadMetrics($0.trackingTypeSnapshot) }
        let includesReps = sessions.contains { $0.trackingTypeSnapshot.usesReps }

        return ExerciseDetailAnalytics(
            sessionCount: sessions.count,
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
        // Completion status and the upper date bound are plain stored
        // properties, so both can be pushed into the predicate and let
        // SwiftData filter at the store instead of materializing every
        // workout ever recorded. What can't move: matching a workout's
        // logged exercises back to `exercise` via
        // `HistoricalExerciseIdentityPolicy` (falling back through
        // `exerciseIDSnapshot` when the live relationship has been
        // repointed) is identity resolution, not a stored-property
        // comparison, so it stays an in-memory filter in
        // `sessions(from:for:)` / `notes(from:for:)`, same as before.
        // Only the date bound goes into the predicate. Completion status
        // deliberately does not: SwiftData rejects a captured enum constant at
        // runtime — "Unsupported Predicate: Captured/constant values of type
        // 'WorkoutStatus' are not supported" — and it does so as a thrown
        // error at fetch time, not a compile error, so this is the kind of
        // change that looks correct until it is actually run. The date bound
        // is what removes the unbounded scan anyway; filtering the remaining
        // in-range workouts by status in memory is cheap.
        let predicate = #Predicate<Workout> { workout in
            workout.startTime <= date
        }
        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\Workout.startTime, order: .forward),
                SortDescriptor(\Workout.id, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor).filter { $0.status == .completed }
    }

    /// Chronological (oldest first) sessions so the latest is always `.last`.
    private func sessions(from workouts: [Workout], for exercise: Exercise) -> [ExerciseSession] {
        workouts.flatMap { workout in
            HistoricalExerciseIdentityPolicy.entries(
                for: exercise,
                in: workout
            ).compactMap { entry -> ExerciseSession? in
                let policy = SportAnalyticsPolicyResolver.policy(for: entry)
                let sets = entry.orderedSets
                    .filter(\.done)
                    .map {
                        ExerciseSessionSet(
                            orderIndex: $0.orderIndex,
                            repetitions: $0.repetitions,
                            weight: $0.weight,
                            weightType: $0.weightType,
                            setType: $0.setType,
                            setMethod: $0.resolvedSetMethod,
                            hasSegments: !$0.segments.isEmpty,
                            contributesToE1RM: policy.contributesToE1RM(set: $0, entry: entry)
                        )
                    }
                guard !sets.isEmpty else { return nil }
                return ExerciseSession(
                    workoutID: workout.id,
                    workoutDate: workout.startTime,
                    sets: sets,
                    semantics: entry.loggingSemanticsSnapshot,
                    trackingTypeSnapshot: entry.trackingTypeSnapshot
                )
            }
        }
    }

    private func notes(from workouts: [Workout], for exercise: Exercise) -> [ExerciseNote] {
        workouts.flatMap { workout in
            HistoricalExerciseIdentityPolicy.entries(
                for: exercise,
                in: workout
            ).compactMap { entry -> ExerciseNote? in
                let text = entry.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { return nil }
                return ExerciseNote(workoutDate: workout.startTime, text: text)
            }
        }
    }

    // MARK: Metrics

    /// Assisted-bodyweight load moves opposite to strength (less assistance
    /// is the improvement), so it is excluded from every load-based PR here,
    /// the same exclusion `ProgressionSnapshotService` applies to recommendations.
    private func includesLoadMetrics(_ trackingType: TrackingType) -> Bool {
        trackingType == .weightAndReps || trackingType == .weightedBodyweight
    }

    private func volume(of sets: [ExerciseSessionSet], semantics: LoggingSemantics, in unit: WeightType) -> Float {
        sets.reduce(Float(0)) { partial, set in
            partial + VolumeCalculator.setVolume(
                weight: set.weight,
                weightType: set.weightType,
                repetitions: set.repetitions,
                semantics: semantics,
                in: unit
            )
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
        let previousVolume = volume(of: previous.workingSets, semantics: previous.semantics, in: unit)
        let latestVolume = volume(of: latest.workingSets, semantics: latest.semantics, in: unit)
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

    /// Epley's prediction error grows with rep count: extrapolating from a
    /// high-rep set overstates 1RM far more than extrapolating from a low-rep
    /// one. Sports-science guidance for linear 1RM formulas (Epley included)
    /// caps the input at roughly 10 reps; beyond that, a set's estimate is no
    /// longer trustworthy enough to headline. Concretely, without this cap a
    /// 20-rep set at 100 kg produces 100 × (1 + 20/30) ≈ 166.7, outranking a
    /// genuine heavy triple at 150 kg (150 × 1.1 = 165) — the estimate would
    /// be driven by the highest-rep set logged, not the strongest one.
    static let e1RMMaxRepetitions: Float = 10

    /// Estimated 1RM uses the Epley formula — `weight × (1 + reps ÷ 30)` —
    /// applied to every qualifying working set at or below
    /// `e1RMMaxRepetitions`, so results stay explainable from one documented
    /// rule and one documented bound rather than switching formulas per
    /// exercise or rep count.
    private func estimatedOneRepMax(in sessions: [ExerciseSession], unit: WeightType) -> OneRepMaxEstimate? {
        workingSets(in: sessions)
            .filter {
                $0.set.repetitions > 0
                    && $0.set.repetitions <= Self.e1RMMaxRepetitions
                    && $0.set.weight > 0
                    && $0.set.contributesToE1RM
            }
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

            let weekSessions = sessions.filter { interval.contains($0.workoutDate) }
            let totalVolume = weekSessions
                .reduce(Float(0)) { $0 + volume(of: $1.workingSets, semantics: $1.semantics, in: unit) }
            return ExerciseVolumeWeek(
                weekStart: weekStart,
                totalVolume: totalVolume,
                workingSetCount: weekSessions.reduce(0) { $0 + $1.workingSets.count },
                sessionCount: weekSessions.count
            )
        }
    }
}

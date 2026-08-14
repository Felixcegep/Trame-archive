import Foundation

/// Explicit, authored movement roles used to interpret the ordered component
/// snapshots of an Olympic attempt. The projection never guesses a role from a
/// display name; callers provide the stable exercise IDs they trust.
nonisolated enum WeightliftingComponentRole: String, Codable, CaseIterable, Hashable, Sendable {
    case clean
    case jerk
    case snatch
    case other
    case unknown
}

/// A named intensity grouping supplied by an authored prescription. This is an
/// identifier, not a percentage range: the analytics layer never invents
/// intensity thresholds from performed load or e1RM.
nonisolated struct WeightliftingAuthoredIntensityGroup: Codable, Hashable, Sendable {
    let id: String

    init(id: String) {
        self.id = id
    }
}

/// The only interpretation inputs accepted by the weightlifting projection.
/// Both maps are optional so legacy snapshots remain visible as complex
/// outcomes while metrics that require missing authored context stay absent.
nonisolated struct WeightliftingAnalyticsConfiguration: Sendable {
    var componentRolesByExerciseID: [UUID: WeightliftingComponentRole]
    var intensityGroupsByPrescribedSetTypeRaw: [String: WeightliftingAuthoredIntensityGroup]

    init(
        componentRolesByExerciseID: [UUID: WeightliftingComponentRole] = [:],
        intensityGroupsByPrescribedSetTypeRaw: [String: WeightliftingAuthoredIntensityGroup] = [:]
    ) {
        self.componentRolesByExerciseID = componentRolesByExerciseID
        self.intensityGroupsByPrescribedSetTypeRaw = intensityGroupsByPrescribedSetTypeRaw
    }

    func componentRole(for component: ComplexComponentResult) -> WeightliftingComponentRole {
        componentRolesByExerciseID[component.exerciseID] ?? .unknown
    }

    func intensityGroup(for set: ExerciseSet) -> WeightliftingAuthoredIntensityGroup? {
        guard let prescribedSetType = set.prescribedSetType else { return nil }
        return intensityGroupsByPrescribedSetTypeRaw[prescribedSetType.rawValue]
    }
}

struct WeightliftingBestLift: Equatable {
    let workoutID: UUID
    let setID: UUID
    let date: Date
    let weight: Float
    let weightType: WeightType
}

struct WeightliftingComponentSuccessSummary: Equatable {
    let role: WeightliftingComponentRole
    let attempts: Int
    let successes: Int

    var successRate: Double? {
        guard attempts > 0 else { return nil }
        return Double(successes) / Double(attempts)
    }
}

struct WeightliftingComponentFailureDistribution: Equatable {
    let role: WeightliftingComponentRole
    let completed: Int
    let partial: Int
    let missed: Int
    let skipped: Int
    let notStarted: Int

    var failures: Int { partial + missed + skipped }
}

struct WeightliftingSuccessRateByIntensityGroup: Equatable {
    let group: WeightliftingAuthoredIntensityGroup
    let attempts: Int
    let successes: Int

    var successRate: Double? {
        guard attempts > 0 else { return nil }
        return Double(successes) / Double(attempts)
    }
}

struct WeightliftingComponentOutcomeEvidence: Equatable {
    let exerciseID: UUID
    let exerciseNameSnapshot: String
    let orderIndex: Int
    let role: WeightliftingComponentRole
    let prescribedRepetitions: Int
    let performedRepetitions: Int
    let outcome: ComplexComponentOutcome
    let liftQuality: LiftQuality?
}

struct WeightliftingComplexOutcome: Equatable {
    let workoutID: UUID
    let setID: UUID
    let date: Date
    let weight: Float
    let weightType: WeightType
    let outcome: OlympicAttemptOutcome
    let liftQuality: LiftQuality?
    let components: [WeightliftingComponentOutcomeEvidence]
}

/// A descriptive per-session quality count. It intentionally exposes counts
/// rather than a technical score, grade, or causal trend claim.
struct WeightliftingQualityTrendPoint: Equatable {
    let workoutID: UUID
    let date: Date
    let excellent: Int
    let acceptable: Int
    let technicallyPoor: Int
    let missed: Int

    var sampleCount: Int { excellent + acceptable + technicallyPoor + missed }
}

struct WeightliftingAnalyticsProjection: Equatable {
    /// Nil when evidence uses more than one weight unit; grouped results stay
    /// available through `bestCompleteSuccessfulLiftsByUnit` without silently
    /// ranking kilograms against pounds.
    let bestCompleteSuccessfulLift: WeightliftingBestLift?
    let bestCompleteSuccessfulLiftsByUnit: [WeightliftingBestLift]
    let cleanSuccess: WeightliftingComponentSuccessSummary?
    let jerkAfterCleanSuccess: WeightliftingComponentSuccessSummary?
    let componentFailureDistribution: [WeightliftingComponentFailureDistribution]
    let successRatesByIntensityGroup: [WeightliftingSuccessRateByIntensityGroup]
    let complexOutcomes: [WeightliftingComplexOutcome]
    let qualityTrend: [WeightliftingQualityTrendPoint]

    static func project(
        workouts: [Workout],
        configuration: WeightliftingAnalyticsConfiguration = .init()
    ) -> Self {
        let attempts = workouts
            .filter { $0.status == .completed }
            .flatMap { workout in
                workout.orderedExercises
                    .filter { $0.sportDisciplineSnapshotRaw == SportDiscipline.olympicWeightlifting.rawValue }
                    .flatMap { entry in
                        entry.orderedSets
                            .filter { $0.done && !$0.complexComponents.isEmpty }
                            .map { set in Attempt(workout: workout, entry: entry, exerciseSet: set, configuration: configuration) }
                    }
            }
            .sorted { Attempt.order(lhs: $0, rhs: $1) }

        let outcomes = attempts.map(\.outcome)
        let bestByUnit = bestSuccessfulLifts(from: attempts)
        let componentSummaries = componentSuccessSummaries(from: attempts)
        let groupedRates = successRates(from: attempts)

        return Self(
            bestCompleteSuccessfulLift: bestByUnit.count == 1 ? bestByUnit.first : nil,
            bestCompleteSuccessfulLiftsByUnit: bestByUnit,
            cleanSuccess: componentSummaries[.clean],
            jerkAfterCleanSuccess: jerkAfterCleanSummary(from: attempts),
            componentFailureDistribution: failureDistribution(from: attempts),
            successRatesByIntensityGroup: groupedRates,
            complexOutcomes: outcomes,
            qualityTrend: qualityTrend(from: attempts)
        )
    }

    private struct Attempt {
        let workout: Workout
        let entry: ExerciseEntry
        let exerciseSet: ExerciseSet
        /// Cache the sorted SwiftData children at the projection boundary.
        /// Several analytics below inspect the same attempt.
        let orderedComponents: [ComplexComponentResult]
        let configuration: WeightliftingAnalyticsConfiguration

        init(
            workout: Workout,
            entry: ExerciseEntry,
            exerciseSet: ExerciseSet,
            configuration: WeightliftingAnalyticsConfiguration
        ) {
            self.workout = workout
            self.entry = entry
            self.exerciseSet = exerciseSet
            self.orderedComponents = exerciseSet.orderedComplexComponents
            self.configuration = configuration
        }

        var outcome: WeightliftingComplexOutcome {
            let mapped = orderedComponents.map {
                WeightliftingComponentOutcomeEvidence(
                    exerciseID: $0.exerciseID,
                    exerciseNameSnapshot: $0.exerciseNameSnapshot,
                    orderIndex: $0.orderIndex,
                    role: configuration.componentRole(for: $0),
                    prescribedRepetitions: $0.prescribedRepetitions,
                    performedRepetitions: $0.performedRepetitions,
                    outcome: $0.outcome,
                    liftQuality: $0.liftQuality
                )
            }
            return WeightliftingComplexOutcome(
                workoutID: workout.id,
                setID: exerciseSet.id,
                date: workout.startTime,
                weight: exerciseSet.weight,
                weightType: exerciseSet.weightType,
                outcome: exerciseSet.olympicAttemptOutcome ?? .notStarted,
                liftQuality: exerciseSet.liftQuality,
                components: mapped
            )
        }

        var isCompleteSuccess: Bool {
            guard exerciseSet.olympicAttemptOutcome == .made else { return false }
            return orderedComponents.allSatisfy {
                $0.outcome == .completed && $0.performedRepetitions >= $0.prescribedRepetitions
            }
        }

        static func order(lhs: Attempt, rhs: Attempt) -> Bool {
            if lhs.workout.startTime != rhs.workout.startTime {
                return lhs.workout.startTime < rhs.workout.startTime
            }
            if lhs.workout.id != rhs.workout.id {
                return lhs.workout.id.uuidString < rhs.workout.id.uuidString
            }
            if lhs.entry.orderIndex != rhs.entry.orderIndex {
                return lhs.entry.orderIndex < rhs.entry.orderIndex
            }
            if lhs.exerciseSet.orderIndex != rhs.exerciseSet.orderIndex {
                return lhs.exerciseSet.orderIndex < rhs.exerciseSet.orderIndex
            }
            return lhs.exerciseSet.id.uuidString < rhs.exerciseSet.id.uuidString
        }
    }

    private static func bestSuccessfulLifts(from attempts: [Attempt]) -> [WeightliftingBestLift] {
        var bestByUnit: [String: Attempt] = [:]
        for attempt in attempts where
            attempt.isCompleteSuccess
                && attempt.exerciseSet.weight.isFinite
                && attempt.exerciseSet.weight > 0 {
            let key = attempt.exerciseSet.weightType.rawValue
            guard let current = bestByUnit[key] else {
                bestByUnit[key] = attempt
                continue
            }
            let isBetter: Bool
            if attempt.exerciseSet.weight != current.exerciseSet.weight {
                isBetter = attempt.exerciseSet.weight > current.exerciseSet.weight
            } else if attempt.workout.startTime != current.workout.startTime {
                isBetter = attempt.workout.startTime > current.workout.startTime
            } else {
                isBetter = attempt.exerciseSet.id.uuidString < current.exerciseSet.id.uuidString
            }
            if isBetter {
                bestByUnit[key] = attempt
            }
        }
        return bestByUnit.values.map { best in
            return WeightliftingBestLift(
                workoutID: best.workout.id,
                setID: best.exerciseSet.id,
                date: best.workout.startTime,
                weight: best.exerciseSet.weight,
                weightType: best.exerciseSet.weightType
            )
        }
        .sorted { lhs, rhs in
            if lhs.weightType.rawValue != rhs.weightType.rawValue {
                return lhs.weightType.rawValue < rhs.weightType.rawValue
            }
            return lhs.setID.uuidString < rhs.setID.uuidString
        }
    }

    private static func componentSuccessSummaries(
        from attempts: [Attempt]
    ) -> [WeightliftingComponentRole: WeightliftingComponentSuccessSummary] {
        var counts: [WeightliftingComponentRole: (attempts: Int, successes: Int)] = [:]
        for attempt in attempts {
            for role in [WeightliftingComponentRole.clean, .jerk, .snatch] {
                let components = attempt.orderedComponents.filter { attempt.configuration.componentRole(for: $0) == role }
                guard !components.isEmpty else { continue }
                let success = components.allSatisfy {
                    $0.outcome == .completed && $0.performedRepetitions >= $0.prescribedRepetitions
                }
                counts[role, default: (0, 0)].attempts += 1
                if success { counts[role, default: (0, 0)].successes += 1 }
            }
        }
        return counts.reduce(into: [:]) { result, element in
            result[element.key] = WeightliftingComponentSuccessSummary(
                role: element.key,
                attempts: element.value.attempts,
                successes: element.value.successes
            )
        }
    }

    private static func jerkAfterCleanSummary(from attempts: [Attempt]) -> WeightliftingComponentSuccessSummary? {
        var total = 0
        var successes = 0
        for attempt in attempts {
            let roles = attempt.orderedComponents.map { attempt.configuration.componentRole(for: $0) }
            guard let cleanIndex = roles.firstIndex(of: .clean),
                  let jerkIndex = roles[(cleanIndex + 1)...].firstIndex(of: .jerk)
            else { continue }
            total += 1
            let clean = attempt.orderedComponents[cleanIndex]
            let jerk = attempt.orderedComponents[jerkIndex]
            if [clean, jerk].allSatisfy({ $0.outcome == .completed && $0.performedRepetitions >= $0.prescribedRepetitions }) {
                successes += 1
            }
        }
        guard total > 0 else { return nil }
        return WeightliftingComponentSuccessSummary(role: .jerk, attempts: total, successes: successes)
    }

    private static func failureDistribution(from attempts: [Attempt]) -> [WeightliftingComponentFailureDistribution] {
        var counts: [WeightliftingComponentRole: (completed: Int, partial: Int, missed: Int, skipped: Int, notStarted: Int)] = [:]
        for attempt in attempts {
            for component in attempt.orderedComponents {
                let role = attempt.configuration.componentRole(for: component)
                switch component.outcome {
                case .completed: counts[role, default: (0, 0, 0, 0, 0)].completed += 1
                case .partial: counts[role, default: (0, 0, 0, 0, 0)].partial += 1
                case .missed: counts[role, default: (0, 0, 0, 0, 0)].missed += 1
                case .skipped: counts[role, default: (0, 0, 0, 0, 0)].skipped += 1
                case .notStarted: counts[role, default: (0, 0, 0, 0, 0)].notStarted += 1
                }
            }
        }
        return counts.map { role, count in
            WeightliftingComponentFailureDistribution(
                role: role,
                completed: count.completed,
                partial: count.partial,
                missed: count.missed,
                skipped: count.skipped,
                notStarted: count.notStarted
            )
        }
        .sorted { $0.role.rawValue < $1.role.rawValue }
    }

    private static func successRates(from attempts: [Attempt]) -> [WeightliftingSuccessRateByIntensityGroup] {
        var counts: [String: (group: WeightliftingAuthoredIntensityGroup, attempts: Int, successes: Int)] = [:]
        for attempt in attempts {
            guard let group = attempt.configuration.intensityGroup(for: attempt.exerciseSet),
                  [.made, .partial, .missed].contains(attempt.exerciseSet.olympicAttemptOutcome ?? .notStarted)
            else { continue }
            var current = counts[group.id] ?? (group, 0, 0)
            current.attempts += 1
            if attempt.isCompleteSuccess { current.successes += 1 }
            counts[group.id] = current
        }
        return counts.values
            .map { WeightliftingSuccessRateByIntensityGroup(group: $0.group, attempts: $0.attempts, successes: $0.successes) }
            .sorted { $0.group.id < $1.group.id }
    }

    private static func qualityTrend(from attempts: [Attempt]) -> [WeightliftingQualityTrendPoint] {
        let grouped = Dictionary(
            grouping: attempts.filter { $0.exerciseSet.liftQuality != nil },
            by: { $0.workout.id }
        )
        return grouped.values.compactMap { sessionAttempts in
            guard let first = sessionAttempts.first else { return nil }
            var counts = (excellent: 0, acceptable: 0, technicallyPoor: 0, missed: 0)
            for attempt in sessionAttempts {
                switch attempt.exerciseSet.liftQuality {
                case .excellent: counts.excellent += 1
                case .acceptable: counts.acceptable += 1
                case .technicallyPoor: counts.technicallyPoor += 1
                case .missed: counts.missed += 1
                case nil: break
                }
            }
            return WeightliftingQualityTrendPoint(
                workoutID: first.workout.id,
                date: first.workout.startTime,
                excellent: counts.excellent,
                acceptable: counts.acceptable,
                technicallyPoor: counts.technicallyPoor,
                missed: counts.missed
            )
        }
        .sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.workoutID.uuidString < rhs.workoutID.uuidString
        }
    }
}

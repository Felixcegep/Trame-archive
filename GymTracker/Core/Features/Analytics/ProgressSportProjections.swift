import Foundation

// MARK: - Shared Progress sport projections

/// A bounded, historical slice used by the Global Progress focus chart.
///
/// A completed workout contributes at most one unit to a period. When a
/// workout contains several snapshot disciplines that unit is divided evenly
/// between them. This keeps a HYROX session with many stations from outweighing
/// a strength session simply because it has more entries.
struct ProgressSportFocusPeriod: Identifiable, Equatable, Sendable {
    struct Slice: Identifiable, Equatable, Sendable {
        let id: String
        let discipline: SportDiscipline?
        let workoutCount: Int
        let proportion: Double
        let evidence: [AnalyticsSourceReference]

        var isUnknown: Bool { discipline == nil }
    }

    let id: Date
    let interval: DateInterval
    let completedWorkoutCount: Int
    let slices: [Slice]

    var hasEvidence: Bool { completedWorkoutCount > 0 }
}

struct ProgressSportFocusTimeline: Equatable, Sendable {
    let periods: [ProgressSportFocusPeriod]
    let quality: AnalyticsDataQuality

    static let empty = Self(periods: [], quality: .insufficient)

    static func project(
        workouts: [Workout],
        interval: DateInterval,
        calendar: Calendar = .current
    ) -> Self {
        let completed = workouts.filter { $0.isCompleted && interval.contains($0.startTime) }
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: interval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: interval.end)
        else { return .empty }

        let workoutsByWeek = Dictionary(grouping: completed) { workout in
            calendar.dateInterval(of: .weekOfYear, for: workout.startTime)?.start
                ?? calendar.startOfDay(for: workout.startTime)
        }
        var weeks: [ProgressSportFocusPeriod] = []
        var cursor = firstWeek.start
        while cursor < interval.end {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let bounded = DateInterval(start: max(week.start, interval.start), end: min(week.end, interval.end))
            // Workouts were bounded above, so the calendar bucket is enough;
            // avoid rescanning the entire range once for every displayed week.
            let inWeek = (workoutsByWeek[week.start] ?? []).filter { bounded.contains($0.startTime) }
            let slices = makeSlices(for: inWeek)
            weeks.append(
                ProgressSportFocusPeriod(
                    id: week.start,
                    interval: bounded,
                    completedWorkoutCount: inWeek.count,
                    slices: slices
                )
            )
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week.start), next > cursor else { break }
            cursor = next
        }

        // `lastWeek` is intentionally evaluated above so a malformed calendar
        // cannot silently produce a partial timeline. It also makes the range
        // contract explicit while keeping empty weeks visible.
        _ = lastWeek
        return Self(periods: weeks, quality: .evaluate(sampleCount: completed.count))
    }

    private static func makeSlices(for workouts: [Workout]) -> [ProgressSportFocusPeriod.Slice] {
        guard workouts.isEmpty == false else { return [] }
        var evidenceByDiscipline: [SportDiscipline?: [AnalyticsSourceReference]] = [:]
        var workoutIDsByDiscipline: [SportDiscipline?: Set<UUID>] = [:]
        var contributionByDiscipline: [SportDiscipline?: Double] = [:]

        for workout in workouts {
            let entries = workout.orderedExercises
            var referencesByDiscipline: [SportDiscipline: [AnalyticsSourceReference]] = [:]
            var unknownReferences: [AnalyticsSourceReference] = []
            for entry in entries {
                let reference = AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id)
                if let discipline = entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) {
                    referencesByDiscipline[discipline, default: []].append(reference)
                } else {
                    unknownReferences.append(reference)
                }
            }
            let disciplines = Set(referencesByDiscipline.keys)
            let known = disciplines.isEmpty == false
            let shareDisciplines: [SportDiscipline?] = known ? disciplines.map(Optional.some) : [nil]
            let contribution = 1.0 / Double(shareDisciplines.count)
            for discipline in shareDisciplines {
                workoutIDsByDiscipline[discipline, default: []].insert(workout.id)
                contributionByDiscipline[discipline, default: 0] += contribution
                let refs = discipline.flatMap { referencesByDiscipline[$0] } ?? unknownReferences
                evidenceByDiscipline[discipline, default: []].append(contentsOf: refs)
            }
        }

        let denominator = Double(workouts.count)
        return evidenceByDiscipline.keys
            .sorted { lhs, rhs in
                (lhs?.rawValue ?? "unknown") < (rhs?.rawValue ?? "unknown")
            }
            .map { discipline in
                let count = workoutIDsByDiscipline[discipline]?.count ?? 0
                let evidence = (evidenceByDiscipline[discipline] ?? []).sorted { $0.id < $1.id }
                return ProgressSportFocusPeriod.Slice(
                    id: discipline?.rawValue ?? "unknown",
                    discipline: discipline,
                    workoutCount: count,
                    proportion: denominator == 0 ? 0 : (contributionByDiscipline[discipline] ?? 0) / denominator,
                    evidence: evidence
                )
            }
    }
}

// MARK: - Lens availability

struct ProgressSportLensAvailability: Identifiable, Equatable, Sendable {
    let discipline: SportDiscipline
    let evidenceWorkoutCount: Int
    let evidenceEntryCount: Int
    let quality: AnalyticsDataQuality
    let isProfilePriority: Bool
    let evidence: [AnalyticsSourceReference]

    var id: SportDiscipline { discipline }
    var isAvailable: Bool { evidenceWorkoutCount > 0 }
}

enum ProgressSportLensAvailabilityProjector {
    static func project(
        workouts: [Workout],
        primary: TrainingDisciplinePreference? = nil,
        secondary: [TrainingDisciplinePreference] = []
    ) -> [ProgressSportLensAvailability] {
        let priorities = Set(([primary] + secondary).compactMap { $0 }.compactMap { SportDiscipline(preference: $0) })
        var evidenceByDiscipline: [SportDiscipline: [AnalyticsSourceReference]] = [:]
        var workoutIDsByDiscipline: [SportDiscipline: Set<UUID>] = [:]

        for workout in workouts where workout.isCompleted {
            for entry in workout.orderedExercises {
                guard let raw = entry.sportDisciplineSnapshotRaw,
                      let discipline = SportDiscipline(rawValue: raw)
                else { continue }
                evidenceByDiscipline[discipline, default: []].append(
                    AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id)
                )
                workoutIDsByDiscipline[discipline, default: []].insert(workout.id)
            }
        }

        return SportDiscipline.allCases.map { discipline in
            let matching = evidenceByDiscipline[discipline] ?? []
            let workoutCount = workoutIDsByDiscipline[discipline]?.count ?? 0
            return ProgressSportLensAvailability(
                discipline: discipline,
                evidenceWorkoutCount: workoutCount,
                evidenceEntryCount: matching.count,
                quality: .evaluate(sampleCount: workoutCount),
                isProfilePriority: priorities.contains(discipline),
                evidence: matching.sorted { $0.id < $1.id }
            )
        }
    }
}

// MARK: - Profile suggestion

enum ProgressSuggestionConfidence: String, Equatable, Sendable {
    case low
    case medium
    case high
}

struct SportProfileSuggestion: Equatable, Sendable {
    let discipline: TrainingDisciplinePreference
    let confidence: ProgressSuggestionConfidence
    let share: Double
    let completedWorkoutCount: Int
    let reasons: [String]
    let evidence: [AnalyticsSourceReference]
}

enum SportProfileSuggestionService {
    static func suggest(
        workouts: [Workout],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> SportProfileSuggestion? {
        let completed = workouts.filter(\.isCompleted)
        guard completed.count >= 3 else { return nil }

        var weighted: [SportDiscipline: Double] = [:]
        var evidence: [SportDiscipline: [AnalyticsSourceReference]] = [:]
        var workoutCount: [SportDiscipline: Set<UUID>] = [:]

        for workout in completed {
            let ageDays = max(0, referenceDate.timeIntervalSince(workout.startTime) / 86_400)
            let recencyWeight = exp(-ageDays / 56.0)
            let disciplines = Set(workout.orderedExercises.compactMap { entry in
                entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:))
            }.filter { $0 != .mixed })
            guard disciplines.isEmpty == false else { continue }
            let share = recencyWeight / Double(disciplines.count)
            for discipline in disciplines {
                weighted[discipline, default: 0] += share
                workoutCount[discipline, default: []].insert(workout.id)
                evidence[discipline, default: []].append(contentsOf: workout.orderedExercises.compactMap { entry in
                    guard entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == discipline else { return nil }
                    return AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id)
                })
            }
        }

        guard let winner = weighted.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue > rhs.key.rawValue : lhs.value < rhs.value
        }), let preference = TrainingDisciplinePreference(preference: winner.key)
        else { return nil }

        let total = weighted.values.reduce(0, +)
        guard total > 0 else { return nil }
        let share = winner.value / total
        let count = workoutCount[winner.key]?.count ?? 0
        let confidence: ProgressSuggestionConfidence =
            count >= 6 && share >= 0.70 ? .high : (count >= 4 && share >= 0.50 ? .medium : .low)
        let reason = "\(winner.key.title) appears in \(count) completed workout days and represents \(Int((share * 100).rounded()))% of recent weighted training evidence."
        return SportProfileSuggestion(
            discipline: preference,
            confidence: confidence,
            share: share,
            completedWorkoutCount: count,
            reasons: [reason],
            evidence: (evidence[winner.key] ?? []).sorted { $0.id < $1.id }
        )
    }
}

// MARK: - Honest global/sport highlights

enum ProgressHighlightMetric: String, Equatable, Sendable {
    case completedWorkouts
    case completedEntries
    case trainingTime
    case bestLoad
}

struct ProgressSportHighlight: Identifiable, Equatable, Sendable {
    let id: String
    let discipline: SportDiscipline
    let metric: ProgressHighlightMetric
    let value: Double?
    let unit: String?
    let quality: AnalyticsDataQuality
    let evidence: [AnalyticsSourceReference]
}

struct GlobalProgressProjection: Equatable, Sendable {
    let completedWorkoutCount: Int
    let completedEntryCount: Int
    let trainingTime: TimeInterval?
    let sportHighlights: [ProgressSportHighlight]
    let quality: AnalyticsDataQuality

    static func project(workouts: [Workout]) -> Self {
        let completed = workouts.filter(\.isCompleted)
        let entries = completed.flatMap(\.orderedExercises)
        let durations = completed.compactMap { workout -> TimeInterval? in
            guard let end = workout.endTime else { return nil }
            let duration = end.timeIntervalSince(workout.startTime)
            return duration.isFinite && duration > 0 ? duration : nil
        }
        var highlights: [ProgressSportHighlight] = []
        for discipline in SportDiscipline.allCases where discipline != .mixed {
            let matching = completed.flatMap { workout in
                workout.orderedExercises.filter { entry in
                    entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == discipline
                }.map { (workout, $0) }
            }
            guard matching.isEmpty == false else { continue }
            let refs = matching.map { AnalyticsSourceReference(workoutID: $0.0.id, entryID: $0.1.id) }
            let workoutCount = Set(matching.map { $0.0.id }).count
            highlights.append(.init(id: "\(discipline.rawValue)-workouts", discipline: discipline, metric: .completedWorkouts, value: Double(workoutCount), unit: "workouts", quality: .evaluate(sampleCount: workoutCount), evidence: refs))
            highlights.append(.init(id: "\(discipline.rawValue)-entries", discipline: discipline, metric: .completedEntries, value: Double(matching.count), unit: "entries", quality: .evaluate(sampleCount: matching.count), evidence: refs))

            let loads = matching.flatMap { workout, entry in
                entry.sets.compactMap { set -> (Double, WeightType, AnalyticsSourceReference)? in
                    guard set.done,
                          !set.setType.isStrengthAnalyticsExcluded,
                          set.weight.isFinite,
                          set.weight > 0
                    else { return nil }
                    let policy = SportAnalyticsPolicyResolver.policy(discipline: discipline, strongmanEventFamily: entry.strongmanEventFamilySnapshot)
                    let kinds = policy.supportedRecords(for: entry)
                    guard kinds.contains(.load) || kinds.contains(.bestSuccessfulLift) else { return nil }
                    if kinds.contains(.bestSuccessfulLift), set.olympicAttemptOutcome != .made { return nil }
                    return (Double(set.weight), set.weightType, AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id, setID: set.id))
                }
            }
            let units = Dictionary(grouping: loads, by: { $0.1.rawValue })
            for (unit, values) in units {
                guard let best = values.max(by: { $0.0 < $1.0 }) else { continue }
                highlights.append(.init(id: "\(discipline.rawValue)-load-\(unit)", discipline: discipline, metric: .bestLoad, value: best.0, unit: unit, quality: .evaluate(sampleCount: values.count), evidence: [best.2]))
            }
        }
        return Self(completedWorkoutCount: completed.count, completedEntryCount: entries.count, trainingTime: durations.isEmpty ? nil : durations.reduce(0, +), sportHighlights: highlights, quality: .evaluate(sampleCount: completed.count))
    }
}

extension SportDiscipline {
    var trainingPreference: TrainingDisciplinePreference? { TrainingDisciplinePreference(preference: self) }

    init?(preference: TrainingDisciplinePreference) {
        switch preference {
        case .generalStrength: self = .generalStrength
        case .bodybuilding: self = .bodybuilding
        case .powerlifting: self = .powerlifting
        case .olympicWeightlifting: self = .olympicWeightlifting
        case .strongman: self = .strongman
        case .hybridFitnessRacing: self = .hybridFitnessRacing
        case .cardioEndurance: self = .generalCardio
        case .mixed: self = .mixed
        case .mobilityFlexibility, .generalFitness, .unspecified: return nil
        }
    }
}

extension TrainingDisciplinePreference {
    var sportDiscipline: SportDiscipline? { SportDiscipline(preference: self) }

    init?(preference: SportDiscipline) {
        switch preference {
        case .generalStrength: self = .generalStrength
        case .bodybuilding: self = .bodybuilding
        case .powerlifting: self = .powerlifting
        case .olympicWeightlifting: self = .olympicWeightlifting
        case .strongman: self = .strongman
        case .hybridFitnessRacing: self = .hybridFitnessRacing
        case .generalCardio: self = .cardioEndurance
        case .mixed: self = .mixed
        }
    }
}

// MARK: - Specialized sport lenses

struct ProgressWeekMetric: Identifiable, Equatable, Sendable {
    let id: Date
    let interval: DateInterval
    let value: Double
    let secondaryValue: Double?
    let evidence: [AnalyticsSourceReference]
}

struct StrengthExerciseProgressRecord: Identifiable, Equatable, Sendable {
    var id: String { "\(exerciseID.uuidString)-\(weightUnit.rawValue)" }
    let exerciseID: UUID
    let name: String
    let weightUnit: WeightType
    let bestLoad: Double
    let bestEstimatedOneRepMax: Double?
    let completedWorkingSetCount: Int
    let evidence: [AnalyticsSourceReference]
}

struct PowerliftingLiftIdentity: Equatable, Sendable {
    let squatExerciseID: UUID
    let benchExerciseID: UUID
    let deadliftExerciseID: UUID
}

struct StrengthProgressProjection: Equatable, Sendable {
    let discipline: SportDiscipline
    let exerciseRecords: [StrengthExerciseProgressRecord]
    let weeklyWorkingSets: [ProgressWeekMetric]
    /// Present only when the caller supplies explicit historical exercise IDs
    /// and all three lifts have comparable records in the same weight unit.
    let estimatedThreeLiftSum: Double?
    let estimatedThreeLiftSumUnit: WeightType?
    let quality: AnalyticsDataQuality

    static func project(
        workouts: [Workout],
        discipline: SportDiscipline,
        interval: DateInterval,
        competitionLifts: PowerliftingLiftIdentity? = nil,
        displayWeightType: WeightType = .kg,
        calendar: Calendar = .current
    ) -> Self {
        precondition(discipline == .powerlifting || discipline == .generalStrength)
        let completed = workouts.filter { $0.isCompleted && interval.contains($0.startTime) }
        let evidence = completed.flatMap { workout in
            workout.orderedExercises.compactMap { entry -> (Workout, ExerciseEntry)? in
                guard entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == discipline else { return nil }
                return (workout, entry)
            }
        }
        let candidates = evidence.flatMap { workout, entry in
            let policy = SportAnalyticsPolicyResolver.policy(for: entry)
            return entry.sets.compactMap { set -> StrengthSetCandidate? in
                guard isEligibleStrengthSet(set, entry: entry), set.weight.isFinite, set.weight > 0 else { return nil }
                let reference = AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id, setID: set.id)
                let e1RM: Double?
                if policy.contributesToE1RM(set: set, entry: entry),
                   set.repetitions.isFinite,
                   set.repetitions > 0,
                   set.repetitions <= 10 {
                    let estimate = Double(set.weight) * (1 + Double(set.repetitions) / 30)
                    e1RM = estimate.isFinite ? estimate : nil
                } else {
                    e1RM = nil
                }
                return StrengthSetCandidate(
                    workoutID: workout.id,
                    exerciseID: entry.historicalExerciseID,
                    name: entry.nameSnapshot,
                    unit: set.weightType,
                    load: Double(set.weight),
                    estimatedOneRepMax: e1RM,
                    reference: reference
                )
            }
        }
        let grouped = Dictionary(grouping: candidates) {
            StrengthExerciseUnitKey(exerciseID: $0.exerciseID, unitRawValue: $0.unit.rawValue)
        }
        let referencesByWorkoutID = Dictionary(grouping: candidates, by: \.workoutID)
            .mapValues { $0.map(\.reference) }
        let records = grouped.values.compactMap { values -> StrengthExerciseProgressRecord? in
            guard let first = values.first, let bestLoad = values.max(by: { $0.load < $1.load }) else { return nil }
            let bestE1RM = values.compactMap(\.estimatedOneRepMax).max()
            return StrengthExerciseProgressRecord(
                exerciseID: first.exerciseID,
                name: first.name,
                weightUnit: first.unit,
                bestLoad: bestLoad.load,
                bestEstimatedOneRepMax: bestE1RM,
                completedWorkingSetCount: values.count,
                evidence: values.map(\.reference).sorted { $0.id < $1.id }
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let sum: (Double, WeightType)? = {
            guard discipline == .powerlifting, let competitionLifts else { return nil }
            let ids = [competitionLifts.squatExerciseID, competitionLifts.benchExerciseID, competitionLifts.deadliftExerciseID]
            let unit = displayWeightType
            let matched = ids.compactMap { id -> Double? in
                records
                    .filter { $0.exerciseID == id }
                    .compactMap { record -> Double? in
                        guard let estimate = record.bestEstimatedOneRepMax else { return nil }
                        let converted = UnitConversion.weight(Float(estimate), from: record.weightUnit, to: unit)
                        return converted.isFinite ? Double(converted) : nil
                    }
                    .max()
            }
            guard matched.count == 3 else { return nil }
            return (matched.reduce(0, +), unit)
        }()

        return Self(
            discipline: discipline,
            exerciseRecords: records,
            weeklyWorkingSets: weeklyMetrics(completed, interval: interval, calendar: calendar) { workout in
                let refs = referencesByWorkoutID[workout.id] ?? []
                return (Double(refs.count), nil, refs)
            },
            estimatedThreeLiftSum: sum?.0,
            estimatedThreeLiftSumUnit: sum?.1,
            quality: .evaluate(sampleCount: Set(evidence.map { $0.0.id }).count)
        )
    }
}

private struct StrengthSetCandidate {
    let workoutID: UUID
    let exerciseID: UUID
    let name: String
    let unit: WeightType
    let load: Double
    let estimatedOneRepMax: Double?
    let reference: AnalyticsSourceReference
}

private struct StrengthExerciseUnitKey: Hashable {
    let exerciseID: UUID
    let unitRawValue: String
}

struct HybridRaceSplit: Identifiable, Equatable, Sendable {
    let id: UUID
    let order: Int
    let kind: WorkoutSplitKind
    let duration: TimeInterval
    let distanceMeters: Double?
    let evidence: AnalyticsSourceReference
}

struct HybridRaceSessionProgress: Identifiable, Equatable, Sendable {
    var id: UUID { workoutID }
    let workoutID: UUID
    let date: Date
    let totalTime: TimeInterval
    let runTime: TimeInterval
    let stationTime: TimeInterval
    let transitionTime: TimeInterval
    let splits: [HybridRaceSplit]
}

struct HybridRaceProgressProjection: Equatable, Sendable {
    let sessions: [HybridRaceSessionProgress]
    let bestTotalTime: TimeInterval?
    let quality: AnalyticsDataQuality

    static func project(workouts: [Workout]) -> Self {
        let sessions = workouts.filter(\.isCompleted).compactMap { workout -> HybridRaceSessionProgress? in
            var orderedCandidates: [(entry: Int, set: Int, segment: Int, value: HybridRaceSplit)] = []
            for entry in workout.orderedExercises {
                guard entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == .hybridFitnessRacing,
                      SportAnalyticsPolicyResolver.policy(for: entry).supportedRecords(for: entry).contains(.runSplit)
                else { continue }
                for set in entry.orderedSets {
                    for segment in set.orderedSegments {
                        guard segment.done, let kind = segment.splitKind,
                              [.run, .station, .transition].contains(kind),
                              let duration = segment.splitDuration, duration.isFinite, duration > 0
                        else { continue }
                        let distance = segment.distanceMeters.flatMap {
                            $0.isFinite && $0 > 0 ? $0 : nil
                        }
                        orderedCandidates.append((
                            entry: entry.orderIndex,
                            set: set.orderIndex,
                            segment: segment.orderIndex,
                            value: HybridRaceSplit(
                                id: segment.id,
                                order: 0,
                                kind: kind,
                                duration: duration,
                                distanceMeters: distance,
                                evidence: AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id, setID: set.id)
                            )
                        ))
                    }
                }
            }
            let splits = orderedCandidates
                .sorted {
                    ($0.entry, $0.set, $0.segment, $0.value.id.uuidString)
                        < ($1.entry, $1.set, $1.segment, $1.value.id.uuidString)
                }
                .enumerated()
                .map { index, candidate in
                    HybridRaceSplit(
                        id: candidate.value.id,
                        order: index,
                        kind: candidate.value.kind,
                        duration: candidate.value.duration,
                        distanceMeters: candidate.value.distanceMeters,
                        evidence: candidate.value.evidence
                    )
                }
            guard splits.isEmpty == false else { return nil }
            var totalTime = TimeInterval.zero
            var runTime = TimeInterval.zero
            var stationTime = TimeInterval.zero
            var transitionTime = TimeInterval.zero
            for split in splits {
                totalTime += split.duration
                switch split.kind {
                case .run: runTime += split.duration
                case .station: stationTime += split.duration
                case .transition: transitionTime += split.duration
                case .work, .recovery: break
                }
            }
            return HybridRaceSessionProgress(
                workoutID: workout.id,
                date: workout.startTime,
                totalTime: totalTime,
                runTime: runTime,
                stationTime: stationTime,
                transitionTime: transitionTime,
                splits: splits
            )
        }.sorted { $0.date < $1.date }
        return Self(sessions: sessions, bestTotalTime: sessions.map(\.totalTime).min(), quality: .evaluate(sampleCount: sessions.count))
    }
}

struct StrongmanEventRecord: Identifiable, Equatable, Sendable {
    var id: String { "\(family.rawValue)-\(exerciseID.uuidString)-\(comparisonKey)" }
    let family: StrongmanEventFamily
    let exerciseID: UUID
    let exerciseName: String
    let comparisonKey: String
    let load: Double?
    let weightUnit: WeightType?
    let distanceMeters: Double?
    let duration: TimeInterval?
    let throwDistanceMeters: Double?
    let evidence: AnalyticsSourceReference
}

struct StrongmanProgressProjection: Equatable, Sendable {
    let records: [StrongmanEventRecord]
    let quality: AnalyticsDataQuality

    static func project(workouts: [Workout]) -> Self {
        var best: [String: StrongmanEventRecord] = [:]
        var workoutIDs = Set<UUID>()
        for workout in workouts where workout.isCompleted {
            for entry in workout.orderedExercises {
                guard entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == .strongman,
                      let family = entry.strongmanEventFamilySnapshot
                else { continue }
                let policy = SportAnalyticsPolicyResolver.policy(for: entry)
                for set in entry.sets where set.done && !set.setType.isStrengthAnalyticsExcluded {
                    let kinds = policy.supportedRecords(for: entry)
                    let load = set.weight.isFinite && set.weight > 0 ? Double(set.weight) : nil
                    let distance = set.distance.flatMap { value -> Double? in
                        guard value.isFinite, value > 0 else { return nil }
                        let meters = distanceInMeters(Double(value), unit: set.distanceType)
                        return meters.isFinite && meters > 0 ? meters : nil
                    }
                    let duration = set.duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
                    let throwDistance = set.resolvedSpecializedMetricKind == .throwDistance
                        ? set.throwDistanceMeters.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
                        : nil
                    let hasRequiredEvidence: Bool
                    if kinds.contains(.loadDistance) {
                        hasRequiredEvidence = load != nil && distance != nil
                    } else if kinds.contains(.loadDuration) {
                        hasRequiredEvidence = load != nil && duration != nil
                    } else if kinds.contains(.load) {
                        hasRequiredEvidence = load != nil || throwDistance != nil
                    } else {
                        hasRequiredEvidence = throwDistance != nil
                    }
                    guard hasRequiredEvidence else { continue }
                    let conditionKey = strongmanConditionKey(for: set)
                    let comparisonKey = load == nil ? conditionKey : "\(conditionKey)-\(set.weightType.rawValue)"
                    let key = "\(family.rawValue)-\(entry.historicalExerciseID.uuidString)-\(comparisonKey)"
                    let candidate = StrongmanEventRecord(
                        family: family,
                        exerciseID: entry.historicalExerciseID,
                        exerciseName: entry.nameSnapshot,
                        comparisonKey: comparisonKey,
                        load: kinds.contains(.load) || kinds.contains(.loadDistance) || kinds.contains(.loadDuration) ? load : nil,
                        weightUnit: load == nil ? nil : set.weightType,
                        distanceMeters: kinds.contains(.loadDistance) ? distance : nil,
                        duration: kinds.contains(.loadDuration) ? duration : nil,
                        throwDistanceMeters: throwDistance,
                        evidence: AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id, setID: set.id)
                    )
                    if let current = best[key] {
                        if strongmanScore(candidate, kinds: kinds) > strongmanScore(current, kinds: kinds) { best[key] = candidate }
                    } else {
                        best[key] = candidate
                    }
                    workoutIDs.insert(workout.id)
                }
            }
        }
        return Self(records: best.values.sorted { $0.id < $1.id }, quality: .evaluate(sampleCount: workoutIDs.count))
    }
}

/// Strongman evidence is comparable only inside one fully snapshotted set of
/// conditions. The shared policy guards load convention; Progress tightens
/// that boundary to include the implement and every performance-relevant
/// dimension captured at log time.
private func strongmanConditionKey(for set: ExerciseSet) -> String {
    let convention = StrongmanLoadComparability.comparisonGroupKey(set.strongmanLoadConvention)
    guard let profile = set.strongmanImplementProfile else { return "\(convention)|legacy-conditions" }
    let handleHeight = profile.handleHeightMeters.map { String($0) } ?? ""
    let handleDiameter = profile.handleDiameterMeters.map { String($0) } ?? ""
    let loadingHeight = profile.loadingHeightMeters.map { String($0) } ?? ""
    let incline = profile.inclinePercent.map { String($0) } ?? ""
    let components: [String] = [
        convention,
        profile.kind.rawValue,
        handleHeight,
        handleDiameter,
        loadingHeight,
        profile.surface?.rawValue ?? "",
        incline,
        profile.notes ?? ""
    ]
    return components.joined(separator: "|")
}

private func strongmanScore(_ record: StrongmanEventRecord, kinds: Set<SportRecordKind>) -> Double {
    if kinds.contains(.loadDistance) { return (record.load ?? 0) * (record.distanceMeters ?? 0) }
    if kinds.contains(.loadDuration) { return (record.load ?? 0) * (record.duration ?? 0) }
    return record.throwDistanceMeters ?? record.load ?? 0
}

struct BodybuildingProgressProjection: Equatable, Sendable {
    let weeklyWorkingSets: [ProgressWeekMetric]
    let quality: AnalyticsDataQuality

    static func project(workouts: [Workout], interval: DateInterval, calendar: Calendar = .current) -> Self {
        let completed = workouts.filter { $0.isCompleted && interval.contains($0.startTime) }
        var workoutCount = 0
        let weeks = weeklyMetrics(completed, interval: interval, calendar: calendar) { workout in
            let refs = workout.orderedExercises.compactMap { entry -> [AnalyticsSourceReference]? in
                guard entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == .bodybuilding else { return nil }
                return entry.sets.filter { isEligibleStrengthSet($0, entry: entry) }.map {
                    AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id, setID: $0.id)
                }
            }.flatMap { $0 }
            if refs.isEmpty == false { workoutCount += 1 }
            return (Double(refs.count), nil, refs)
        }
        return Self(weeklyWorkingSets: weeks, quality: .evaluate(sampleCount: workoutCount))
    }
}

struct CardioProgressProjection: Equatable, Sendable {
    let weeklyDistanceAndDuration: [ProgressWeekMetric]
    let totalDistanceMeters: Double?
    let totalDuration: TimeInterval?
    let averagePaceSecondsPerKilometer: Double?
    let quality: AnalyticsDataQuality

    static func project(workouts: [Workout], interval: DateInterval, calendar: Calendar = .current) -> Self {
        let completed = workouts.filter { $0.isCompleted && interval.contains($0.startTime) }
        var qualifyingWorkouts = Set<UUID>()
        let weeks = weeklyMetrics(completed, interval: interval, calendar: calendar) { workout in
            var distance = 0.0
            var duration = 0.0
            var refs: [AnalyticsSourceReference] = []
            for entry in workout.orderedExercises {
                guard entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:)) == .generalCardio else { continue }
                let kinds = SportAnalyticsPolicyResolver.policy(for: entry).supportedRecords(for: entry)
                for set in entry.sets where set.done {
                    if kinds.contains(.distance), let value = set.distance, value.isFinite, value > 0 {
                        let meters = distanceInMeters(Double(value), unit: set.distanceType)
                        if meters.isFinite, meters > 0 { distance += meters }
                    }
                    if kinds.contains(.time), let value = set.duration, value.isFinite, value > 0 { duration += value }
                    let hasDistance = set.distance.map { $0.isFinite && $0 > 0 } ?? false
                    let hasDuration = set.duration.map { $0.isFinite && $0 > 0 } ?? false
                    if hasDistance || hasDuration {
                        refs.append(.init(workoutID: workout.id, entryID: entry.id, setID: set.id))
                    }
                }
            }
            if refs.isEmpty == false { qualifyingWorkouts.insert(workout.id) }
            return (distance, duration, refs)
        }
        let distance = weeks.map(\.value).reduce(0, +)
        let duration = weeks.compactMap(\.secondaryValue).reduce(0, +)
        return Self(
            weeklyDistanceAndDuration: weeks,
            totalDistanceMeters: distance > 0 ? distance : nil,
            totalDuration: duration > 0 ? duration : nil,
            averagePaceSecondsPerKilometer: distance > 0 && duration > 0 ? duration / (distance / 1_000) : nil,
            quality: .evaluate(sampleCount: qualifyingWorkouts.count)
        )
    }
}

struct MixedSportComposition: Identifiable, Equatable, Sendable {
    var id: String { discipline?.rawValue ?? "unknown" }
    let discipline: SportDiscipline?
    let completedWorkoutContribution: Double
    let proportion: Double
    let evidence: [AnalyticsSourceReference]
}

struct MixedProgressProjection: Equatable, Sendable {
    let completedWorkoutCount: Int
    let composition: [MixedSportComposition]
    let averageWorkoutsPerWeek: Double?
    let quality: AnalyticsDataQuality

    static func project(workouts: [Workout], interval: DateInterval, calendar: Calendar = .current) -> Self {
        let completed = workouts.filter { $0.isCompleted && interval.contains($0.startTime) }
        var contributions: [SportDiscipline?: Double] = [:]
        var evidence: [SportDiscipline?: [AnalyticsSourceReference]] = [:]
        for workout in completed {
            var referencesByDiscipline: [SportDiscipline?: [AnalyticsSourceReference]] = [:]
            for entry in workout.orderedExercises {
                let discipline = entry.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:))
                referencesByDiscipline[discipline, default: []].append(
                    AnalyticsSourceReference(workoutID: workout.id, entryID: entry.id)
                )
            }
            let disciplines: Set<SportDiscipline?> = referencesByDiscipline.isEmpty
                ? [nil]
                : Set(referencesByDiscipline.keys)
            let share = disciplines.isEmpty ? 0 : 1 / Double(disciplines.count)
            for discipline in disciplines {
                contributions[discipline, default: 0] += share
                evidence[discipline, default: []].append(
                    contentsOf: referencesByDiscipline[discipline] ?? []
                )
            }
        }
        let composition = contributions.map { discipline, contribution in
            MixedSportComposition(
                discipline: discipline,
                completedWorkoutContribution: contribution,
                proportion: completed.isEmpty ? 0 : contribution / Double(completed.count),
                evidence: (evidence[discipline] ?? []).sorted { $0.id < $1.id }
            )
        }.sorted { $0.proportion > $1.proportion }
        let weekCount = max(1, calendar.dateComponents([.weekOfYear], from: interval.start, to: interval.end).weekOfYear ?? 1)
        return Self(
            completedWorkoutCount: completed.count,
            composition: composition,
            averageWorkoutsPerWeek: completed.isEmpty ? nil : Double(completed.count) / Double(weekCount),
            quality: .evaluate(sampleCount: completed.count)
        )
    }
}

private func weeklyMetrics(
    _ workouts: [Workout],
    interval: DateInterval,
    calendar: Calendar,
    metric: (Workout) -> (Double, Double?, [AnalyticsSourceReference])
) -> [ProgressWeekMetric] {
    guard let first = calendar.dateInterval(of: .weekOfYear, for: interval.start) else { return [] }
    let workoutsByWeek = Dictionary(grouping: workouts) { workout in
        calendar.dateInterval(of: .weekOfYear, for: workout.startTime)?.start
            ?? calendar.startOfDay(for: workout.startTime)
    }
    var cursor = first.start
    var result: [ProgressWeekMetric] = []
    while cursor < interval.end, let week = calendar.dateInterval(of: .weekOfYear, for: cursor) {
        let bounded = DateInterval(start: max(interval.start, week.start), end: min(interval.end, week.end))
        let values = (workoutsByWeek[week.start] ?? [])
            .filter { bounded.contains($0.startTime) }
            .map { metric($0) }
        let secondaryValues = values.compactMap(\.1)
        result.append(.init(
            id: week.start,
            interval: bounded,
            value: values.map(\.0).reduce(0, +),
            secondaryValue: secondaryValues.isEmpty ? nil : secondaryValues.reduce(0, +),
            evidence: values.flatMap(\.2).sorted { $0.id < $1.id }
        ))
        guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week.start), next > cursor else { break }
        cursor = next
    }
    return result
}

private func distanceInMeters(_ value: Double, unit: DistanceType) -> Double {
    switch unit {
    case .meters: value
    case .kilometers: value * 1_000
    case .miles: value * 1_609.344
    }
}

private func isEligibleStrengthSet(_ set: ExerciseSet, entry: ExerciseEntry) -> Bool {
    guard set.done,
          set.setType != .warmup,
          set.resolvedSetMethod == .standard,
          set.segments.isEmpty,
          set.complexComponents.isEmpty,
          set.resolvedSpecializedMetricKind == .none,
          set.isVelocityProbe == false
    else { return false }
    return SportAnalyticsPolicyResolver.policy(for: entry).contributesToStrengthVolume(set: set, entry: entry)
}

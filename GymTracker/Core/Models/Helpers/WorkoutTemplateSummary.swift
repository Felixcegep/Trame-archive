import Foundation

/// What a saved workout mostly trains, derived from the muscles its exercises
/// name rather than from a tag the user has to maintain.
///
/// Deliberately four coarse buckets: the value here is narrowing twenty seeded
/// workouts down to a handful in one tap, which a finer taxonomy (push/pull,
/// per-muscle) would not do — it would only move the scrolling problem into a
/// longer filter strip.
enum WorkoutTemplateFocus: String, CaseIterable, Identifiable, Sendable {
    case fullBody
    case upperBody
    case lowerBody
    case core

    var id: Self { self }

    var title: String {
        switch self {
        case .fullBody: String(localized: "Full body")
        case .upperBody: String(localized: "Upper body")
        case .lowerBody: String(localized: "Lower body")
        case .core: String(localized: "Core")
        }
    }
}

/// The scannable identity of a saved workout: what it trains, roughly how long
/// it takes, and when it was last used.
///
/// Every row of the start picker used to read "5 exercises", which is true of
/// almost every seeded workout and therefore tells a lifter nothing. These
/// values come from the prescription itself, so a long library can be searched,
/// filtered, and compared without opening each workout.
struct WorkoutTemplateSummary: Equatable, Sendable {
    let exerciseCount: Int
    /// Nil when the workout has no exercises to classify.
    let focus: WorkoutTemplateFocus?
    /// Most-trained muscle groups first.
    let muscleGroups: [Muscle.Group]
    /// Nil when the workout has no exercises to estimate from.
    let estimatedMinutes: Int?
    /// When a session was last *started* from this workout, not last finished:
    /// an abandoned session still says "this is what I reach for".
    let lastPerformed: Date?
    /// Terms a search over this workout should also match — its exercises and
    /// the muscle groups they train, not only the workout's own name, so
    /// "bench" finds the day that contains a bench press.
    let searchAliases: [String]
}

extension WorkoutTemplateSummary {
    /// Seconds of work assumed per set. Rest is prescribed per exercise; the
    /// set itself never is, so one flat figure keeps the estimate honest rather
    /// than implying a precision the model does not carry. Every duration this
    /// produces is presented as an approximation.
    private static let workSecondsPerSet = 45
    private static let estimatedMinutesRange = 10...180

    static func make(for template: WorkoutTemplate) -> WorkoutTemplateSummary {
        let templateExercises = template.orderedTemplateExercises

        var groupCounts: [Muscle.Group: Int] = [:]
        var aliases: [String] = []
        var totalSeconds = 0

        for templateExercise in templateExercises {
            let exercise = templateExercise.exercise
            aliases.append(exercise.name)

            // Counted once per group per exercise: a bench press names three
            // chest heads, and weighting it triple would make any chest day
            // look like a chest-only day.
            for group in Set(exercise.primaryMuscles.map(\.group)) where group != .other {
                groupCounts[group, default: 0] += 1
            }

            let sets = max(templateExercise.targetSets, 1)
            totalSeconds += sets * workSecondsPerSet
            totalSeconds += (sets - 1) * max(templateExercise.restSeconds, 0)
        }

        let orderedGroups = groupCounts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
            }
            .map(\.key)

        let focus = resolvedFocus(from: groupCounts)
        aliases.append(contentsOf: orderedGroups.map(\.rawValue))
        if let focus {
            aliases.append(focus.title)
        }

        return WorkoutTemplateSummary(
            exerciseCount: templateExercises.count,
            focus: focus,
            muscleGroups: orderedGroups,
            estimatedMinutes: templateExercises.isEmpty ? nil : estimatedMinutes(fromSeconds: totalSeconds),
            lastPerformed: template.sourceWorkouts.map(\.startTime).max(),
            searchAliases: aliases
        )
    }

    /// "5 exercises · ~45 min · Chest, Shoulders"
    var detailText: String {
        guard exerciseCount > 0 else {
            return String(localized: "No exercises yet")
        }

        var parts: [String] = [
            exerciseCount == 1
                ? String(localized: "1 exercise")
                : String(localized: "\(exerciseCount) exercises")
        ]

        if let estimatedMinutes {
            parts.append(String(localized: "~\(estimatedMinutes) min"))
        }

        // Two groups, not all of them: past that the line truncates on a narrow
        // phone and the truncation lands mid-word on the least useful term.
        let groups = muscleGroups.prefix(2).map(\.rawValue)
        if !groups.isEmpty {
            parts.append(groups.joined(separator: ", "))
        }

        return parts.joined(separator: " · ")
    }

    /// A share rather than a count, so a four-exercise day and a nine-exercise
    /// day are classified the same way. The upper threshold is lower than a
    /// clean sweep because most upper days carry one core or carry finisher,
    /// which should not promote them to "full body".
    private static func resolvedFocus(from groupCounts: [Muscle.Group: Int]) -> WorkoutTemplateFocus? {
        let upper = total(of: [.chest, .shoulders, .arms, .back], in: groupCounts)
        let lower = total(of: [.legs, .glutes], in: groupCounts)
        let core = total(of: [.core], in: groupCounts)
        let overall = upper + lower + core
        guard overall > 0 else { return nil }

        let share = { (value: Int) in Double(value) / Double(overall) }
        if share(upper) >= 0.7 { return .upperBody }
        if share(lower) >= 0.7 { return .lowerBody }
        if share(core) >= 0.6 { return .core }
        return .fullBody
    }

    private static func total(of groups: Set<Muscle.Group>, in counts: [Muscle.Group: Int]) -> Int {
        groups.reduce(0) { $0 + (counts[$1] ?? 0) }
    }

    /// Rounded to five minutes. The inputs are a flat per-set estimate and a
    /// prescribed rest, so a to-the-minute figure would be false precision.
    private static func estimatedMinutes(fromSeconds seconds: Int) -> Int {
        let minutes = Int((Double(seconds) / 60).rounded())
        let roundedToFive = Int((Double(minutes) / 5).rounded()) * 5
        return min(max(roundedToFive, estimatedMinutesRange.lowerBound), estimatedMinutesRange.upperBound)
    }
}

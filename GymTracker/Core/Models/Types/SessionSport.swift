import Foundation

/// What kind of training a finished session actually was.
///
/// Deliberately distinct from ``ExerciseCategory``: that describes one
/// *movement* ("this is a mobility drill"), while this describes a whole
/// *session* ("this was a weightlifting day"). A powerlifting session is full of
/// `.strength` exercises and a CrossFit session mixes three categories — neither
/// is derivable by reading a single exercise's category, which is why this is
/// its own type rather than a reuse.
nonisolated enum SessionSport: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength
    case powerlifting
    case weightlifting
    case bodybuilding
    case calisthenics
    case cardio
    case conditioning
    case mobility
    case sportSpecific
    case mixed
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .strength: String(localized: "Strength")
        case .powerlifting: String(localized: "Powerlifting")
        case .weightlifting: String(localized: "Weightlifting")
        case .bodybuilding: String(localized: "Bodybuilding")
        case .calisthenics: String(localized: "Calisthenics")
        case .cardio: String(localized: "Cardio")
        case .conditioning: String(localized: "Conditioning")
        case .mobility: String(localized: "Mobility")
        case .sportSpecific: String(localized: "Sport-specific")
        case .mixed: String(localized: "Mixed")
        case .other: String(localized: "Other")
        }
    }
}

/// The outcome of guessing a session's sport, kept separate from the guess
/// itself so the UI can tell "confident" from "no idea" and present them
/// differently. A confident wrong answer is worse than an honest question.
struct SessionSportSuggestion: Equatable {
    /// The leading sport, or `nil` when the evidence is contested. `nil` means
    /// *ask*, not *fall back to Strength*.
    let selected: SessionSport?
    /// Sports to offer alongside the selection, most likely first.
    let alternatives: [SessionSport]
    /// How many of the session's exercises supported the leading sport, out of
    /// how many were considered — the caption's numbers.
    let matchedExercises: Int
    let totalExercises: Int

    var isConfident: Bool { selected != nil }
}

/// Guesses a session's sport from the exercises actually performed.
///
/// Every input already exists on `Exercise`; nothing here needs new data entry.
/// The scoring is deliberately simple and legible rather than clever — it is
/// pre-filling one row on the save screen, and the lifter can override it with a
/// single tap.
nonisolated enum SessionSportDetector {

    /// Names that identify a lift beyond what the taxonomy can express. Matched
    /// case-insensitively as substrings, so "Hang Power Clean" and "Clean and
    /// Jerk" both land on weightlifting.
    private static let olympicTerms = ["snatch", "clean", "jerk"]
    private static let powerliftingTerms = ["squat", "bench", "deadlift"]

    /// Scores every exercise against each rule, sums by sport, and returns the
    /// leader when it is clearly ahead.
    ///
    /// - Parameter exercises: the session's exercises, in any order. Entries
    ///   with no logged work should be filtered out by the caller — an exercise
    ///   that was added and skipped is not evidence of anything.
    static func suggest(for exercises: [ExerciseDetectionInput]) -> SessionSportSuggestion {
        guard !exercises.isEmpty else {
            return SessionSportSuggestion(
                selected: nil,
                alternatives: [.strength, .cardio, .mobility],
                matchedExercises: 0,
                totalExercises: 0
            )
        }

        var scores: [SessionSport: Int] = [:]
        var supporters: [SessionSport: Int] = [:]

        for exercise in exercises {
            for (sport, weight) in signals(for: exercise) {
                scores[sport, default: 0] += weight
                supporters[sport, default: 0] += 1
            }
        }

        guard !scores.isEmpty else {
            return SessionSportSuggestion(
                selected: nil,
                alternatives: [.strength, .cardio, .other],
                matchedExercises: 0,
                totalExercises: exercises.count
            )
        }

        // Sort by score, then by name so the result is stable across runs
        // rather than depending on dictionary ordering.
        let ranked = scores
            .sorted { ($0.value, $1.key.rawValue) > ($1.value, $0.key.rawValue) }
            .map(\.key)

        let leader = ranked[0]
        let leaderScore = scores[leader] ?? 0
        let runnerUpScore = ranked.count > 1 ? (scores[ranked[1]] ?? 0) : 0
        let matched = supporters[leader] ?? 0
        let coverage = Double(matched) / Double(exercises.count)

        // Confident only when the leader is clearly ahead *and* speaks for most
        // of the session. Either one alone produces a plausible-sounding guess
        // that is wrong often enough to be worse than asking.
        let isClear = Double(leaderScore) >= Double(runnerUpScore) * 1.5 && coverage >= 0.6

        return SessionSportSuggestion(
            selected: isClear ? leader : nil,
            alternatives: Array(ranked.prefix(isClear ? 3 : 3)).filter { isClear ? $0 != leader : true },
            matchedExercises: matched,
            totalExercises: exercises.count
        )
    }

    private static func signals(for exercise: ExerciseDetectionInput) -> [(SessionSport, Int)] {
        var found: [(SessionSport, Int)] = []
        let name = exercise.name.lowercased()

        if olympicTerms.contains(where: name.contains) {
            found.append((.weightlifting, 5))
        }
        if powerliftingTerms.contains(where: name.contains), exercise.equipment == .barbell {
            found.append((.powerlifting, 4))
        }
        let bodyweightResistances: [ResistanceType] = [.bodyweight, .assistedBodyweight, .weightedBodyweight]
        if exercise.equipment == .bodyweight, bodyweightResistances.contains(exercise.resistance) {
            found.append((.calisthenics, 3))
        }
        if exercise.equipment == .cardioMachine
            || exercise.tracking == .durationAndDistance
            || exercise.tracking == .calories {
            found.append((.cardio, 3))
        }
        if exercise.category == .mobility || exercise.category == .flexibility {
            found.append((.mobility, 3))
        }
        if exercise.isInsideConditioningBlock {
            found.append((.conditioning, 2))
        }
        if exercise.category == .sport {
            found.append((.sportSpecific, 3))
        }

        // The catch-all fires only when nothing narrower did, so ordinary
        // barbell work does not quietly outvote a clear calisthenics signal.
        let resistanceEquipment: [EquipmentType] = [.barbell, .dumbbell, .cable, .machine, .kettlebell]
        if found.isEmpty, exercise.category == .strength, resistanceEquipment.contains(exercise.equipment) {
            found.append((.strength, 2))
        }

        return found
    }
}

/// The slice of an exercise the detector reads. Keeping this a plain struct lets
/// the rules be unit-tested without building a SwiftData graph, and keeps the
/// detector out of the persistence layer.
nonisolated struct ExerciseDetectionInput: Equatable, Sendable {
    let name: String
    let category: ExerciseCategory
    let equipment: EquipmentType
    let resistance: ResistanceType
    let tracking: TrackingType
    let isInsideConditioningBlock: Bool

    init(
        name: String,
        category: ExerciseCategory,
        equipment: EquipmentType,
        resistance: ResistanceType,
        tracking: TrackingType,
        isInsideConditioningBlock: Bool = false
    ) {
        self.name = name
        self.category = category
        self.equipment = equipment
        self.resistance = resistance
        self.tracking = tracking
        self.isInsideConditioningBlock = isInsideConditioningBlock
    }
}

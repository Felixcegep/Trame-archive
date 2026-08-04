import Foundation

/// One timed division of a multi-phase performed effort — a run leg, a
/// station, the transition between them, or a recovery interval inside a
/// fitness-simulation or medley event.
///
/// This reuses `ExerciseSetSegment` rather than a parallel model: a segment
/// is already documented as "an ordered internal effort within one parent
/// `ExerciseSet`," which is exactly what a split is. See
/// `ExerciseSetSegment.splitKind` and its accompanying fields
/// (`startedAt`/`endedAt`/`distanceMeters`/`heartRateBPM`/
/// `perceivedExertion`) for the persisted evidence. A segment with a `nil`
/// `splitKind` is the pre-existing dropset/cluster/rest-pause internal effort
/// and is untouched by this addition.
nonisolated enum WorkoutSplitKind: String, Codable, CaseIterable, Hashable, Sendable {
    case work
    case run
    case station
    case transition
    case recovery

    var title: String {
        switch self {
        case .work: String(localized: "Work", comment: "Workout split kind: undifferentiated work effort")
        case .run: String(localized: "Run", comment: "Workout split kind: a running leg")
        case .station: String(localized: "Station", comment: "Workout split kind: a fixed station in a simulation event")
        case .transition: String(localized: "Transition", comment: "Workout split kind: movement between stations")
        case .recovery: String(localized: "Recovery", comment: "Workout split kind: a rest or recovery interval")
        }
    }
}

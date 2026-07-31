import Foundation

/// The single authority for deciding whether a completed `ExerciseEntry` is
/// history *for* a catalogue `Exercise`.
///
/// `ExerciseEntry` has documented since it gained `exerciseIDSnapshot` that the
/// snapshot is the stable identity "for completed-history grouping, analytics,
/// and records", and that the live `exercise` relationship is a convenience
/// link. Every history, analytics, records, and insights consumer nevertheless
/// matched on that live relationship. The contract was therefore unenforced:
/// anything that made snapshot and relationship disagree would have silently
/// reassigned or hidden completed work, and no test would have failed.
///
/// The two agree today, which is why this is hardening rather than a bug fix.
/// `updateExerciseSnapshot(from:)` rewrites the relationship and both snapshots
/// together, and only for an entry that has not been started, so a substitution
/// cannot split them. This type exists so that stays true by construction
/// instead of by coincidence, and so the legacy rule is stated once.
///
/// **Legacy fallback.** Rows persisted before `exerciseIDSnapshot` existed carry
/// `nil`, and `historicalExerciseID` falls back to the live relationship's id
/// for exactly those rows. `RootView.normalizePersistedWorkoutData` backfills
/// them once per install, so the fallback only covers a store that has not yet
/// been through that migration — including one restored from an old backup.
///
/// **Why `id` and not `persistentModelID`.** The snapshot stores the catalogue
/// row's own `UUID`, so matching happens on `Exercise.id`. That makes `id`
/// uniqueness load-bearing for historical correctness. `Exercise.id` is a
/// plain `UUID()` default and is *not* declared `@Attribute(.unique)`, so two
/// catalogue rows sharing an id would over-match. No code path produces that
/// today; a uniqueness constraint would make the guarantee structural.
enum HistoricalExerciseIdentityPolicy {
    /// The identity a completed entry is grouped, compared, and reported under.
    nonisolated static func identity(of entry: ExerciseEntry) -> UUID {
        entry.historicalExerciseID
    }

    /// Whether a completed entry is history for this catalogue exercise.
    static func matches(_ entry: ExerciseEntry, _ exercise: Exercise) -> Bool {
        identity(of: entry) == exercise.id
    }

    /// The entry in a workout that is history for `exercise`, if any.
    ///
    /// A workout holds at most one entry per exercise in practice; the first
    /// match is returned so behaviour is identical to the `first(where:)`
    /// lookups this replaced.
    static func entry(for exercise: Exercise, in workout: Workout) -> ExerciseEntry? {
        workout.orderedExercises.first { matches($0, exercise) }
    }

    /// A stable string key for grouping or comparing entries across sessions.
    nonisolated static func comparisonKey(for entry: ExerciseEntry) -> String {
        identity(of: entry).uuidString
    }
}

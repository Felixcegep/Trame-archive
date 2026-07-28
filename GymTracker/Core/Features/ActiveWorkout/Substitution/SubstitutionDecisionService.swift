import Foundation
import SwiftData

/// Applies a confirmed substitution to an in-progress entry as one transaction.
///
/// The boundary this service protects is the prescription/history one: an
/// unstarted entry may be re-pointed at another exercise, but a completed one
/// never may. Once any set is done, that entry is performed truth and
/// reinterpreting it as a different exercise would rewrite history rather than
/// record a decision about it.
enum SubstitutionDecisionService {
    enum Failure: Error, Equatable {
        case entryNotFound
        case sameExercise
        case alreadyStarted
        case saveFailed
    }

    /// - Returns: the number of sets rebuilt for the replacement.
    @discardableResult
    static func apply(
        decision: SubstitutionDecision,
        replacement: Exercise,
        to entryID: PersistentIdentifier,
        in workout: Workout,
        modelContext: ModelContext
    ) throws -> Int {
        guard let entry = workout.exercises.first(where: { $0.persistentModelID == entryID }) else {
            throw Failure.entryNotFound
        }
        guard entry.exercise.id != replacement.id else {
            throw Failure.sameExercise
        }
        guard !entry.sets.contains(where: \.done) else {
            throw Failure.alreadyStarted
        }

        let setCount = max(entry.sets.count, 1)

        // Capture the original identity exactly once. A second swap must not
        // overwrite the first original — the entry's provenance is the
        // exercise it was prescribed as, not the one it happened to hold a
        // moment ago.
        if entry.originalExerciseIDSnapshot == nil {
            entry.originalExerciseIDSnapshot = entry.exercise.id
            entry.originalExerciseNameSnapshot = entry.nameSnapshot
        }
        entry.selectedSubstituteExerciseIDSnapshot = replacement.id

        // The single write path for the decision. It is what keeps the
        // persisted `substitutionSharesProgressionState` Boolean — the value
        // both progression services read — in lockstep with the policy that
        // explains it.
        entry.applySubstitutionDecision(decision)

        for set in entry.sets {
            modelContext.delete(set)
        }
        entry.sets.removeAll()
        entry.updateExerciseSnapshot(from: replacement)
        entry.addDefaultSets(count: setCount)

        guard modelContext.saveOrRollback() else {
            throw Failure.saveFailed
        }
        return setCount
    }
}

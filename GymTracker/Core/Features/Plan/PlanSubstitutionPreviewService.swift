import Foundation
import SwiftData

/// Future-plan scope for a substitution: replacing the exercise in the plan
/// itself, from here on.
///
/// This is deliberately a **separate, previewed action** rather than a flag on
/// the today-only swap. Editing a plan and logging today's session are
/// different kinds of change with different blast radii, and a lifter who
/// wanted one should never get the other as a side effect.
///
/// It edits the prescription only. Completed workouts, their entries, and their
/// snapshots are never touched — a plan edit describes intended future work and
/// has no authority over performed history.
enum PlanSubstitutionPreviewService {
    enum Failure: Error, Equatable {
        case planExerciseNotFound
        case runNotEditable
        case saveFailed
    }

    /// What the lifter is shown before anything changes.
    struct Preview: Equatable {
        let planName: String
        let originalExerciseName: String
        let replacementExerciseName: String
        /// Remaining future exposures this would affect. Sessions already
        /// completed are excluded — they are history.
        let affectedExposureCount: Int
        /// True when the plan's own progression key is reused, meaning the
        /// prescription's progression continues under the new exercise.
        let retainsProgressionKey: Bool
    }

    /// A run whose progress is finished or archived is a closed record; its
    /// prescription must stay as it was actually followed.
    static func isEditable(_ run: PlanRun?) -> Bool {
        guard let run else { return false }
        switch run.status {
        case .active, .paused, .testDayAvailable:
            return true
        case .completed, .archived:
            return false
        }
    }

    static func preview(
        plannedExerciseID: UUID,
        replacement: Exercise,
        run: PlanRun?,
        modelContext: ModelContext
    ) throws -> Preview {
        guard isEditable(run) else { throw Failure.runNotEditable }
        guard let planned = try plannedExercise(id: plannedExerciseID, modelContext: modelContext) else {
            throw Failure.planExerciseNotFound
        }

        let siblings = try allPlannedExercises(
            progressionKey: planned.progressionKey,
            modelContext: modelContext
        )

        return Preview(
            planName: run?.plan?.name ?? "",
            originalExerciseName: planned.exercise.name,
            replacementExerciseName: replacement.name,
            affectedExposureCount: siblings.count,
            retainsProgressionKey: true
        )
    }

    /// Applies the previewed change. Every exposure sharing the progression key
    /// moves together: leaving half a plan on the old exercise would split one
    /// progression across two movements, which is exactly the silent state this
    /// feature exists to prevent.
    @discardableResult
    static func apply(
        plannedExerciseID: UUID,
        replacement: Exercise,
        run: PlanRun?,
        modelContext: ModelContext
    ) throws -> Int {
        guard isEditable(run) else { throw Failure.runNotEditable }
        guard let planned = try plannedExercise(id: plannedExerciseID, modelContext: modelContext) else {
            throw Failure.planExerciseNotFound
        }

        let siblings = try allPlannedExercises(
            progressionKey: planned.progressionKey,
            modelContext: modelContext
        )
        for exposure in siblings {
            // The progression key is intentionally left alone: the prescription
            // slot keeps its identity, only the exercise filling it changes.
            exposure.exercise = replacement
        }

        guard modelContext.saveOrRollback() else {
            throw Failure.saveFailed
        }
        return siblings.count
    }

    private static func plannedExercise(
        id: UUID,
        modelContext: ModelContext
    ) throws -> PlannedExercise? {
        try modelContext.fetch(FetchDescriptor<PlannedExercise>()).first { $0.id == id }
    }

    private static func allPlannedExercises(
        progressionKey: String,
        modelContext: ModelContext
    ) throws -> [PlannedExercise] {
        try modelContext.fetch(FetchDescriptor<PlannedExercise>())
            .filter { $0.progressionKey == progressionKey }
    }
}

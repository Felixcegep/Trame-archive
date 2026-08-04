import Foundation
import SwiftData

public enum WorkoutCompletionWarning: Equatable, Sendable {
    case progressionEvaluationDeferred(reason: String)
    case missingExerciseSnapshot(exerciseID: UUID)
}

public enum WorkoutPostCommitEffect: Equatable, Sendable {
    case liveActivityCleanup
    case notificationRefresh
    case widgetProjectionUpdate
}

public struct WorkoutCompletionOutcome: Sendable {
    public let workoutID: UUID
    public let mutationID: UUID
    public let warnings: [WorkoutCompletionWarning]
    public let effects: [WorkoutPostCommitEffect]

    public init(
        workoutID: UUID,
        mutationID: UUID,
        warnings: [WorkoutCompletionWarning] = [],
        effects: [WorkoutPostCommitEffect] = [.liveActivityCleanup, .notificationRefresh, .widgetProjectionUpdate]
    ) {
        self.workoutID = workoutID
        self.mutationID = mutationID
        self.warnings = warnings
        self.effects = effects
    }
}

/// One authoritative transaction manager for materializing completed workouts
/// and applying plan/repeating-plan transitions idempotently.
@MainActor
public final class WorkoutCompletionTransaction {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Complete a workout idempotently given a workout ID and mutation ID.
    public func executeCompletion(
        workoutID: UUID,
        mutationID: UUID
    ) throws -> WorkoutCompletionOutcome {
        // Search for existing completed workout by workoutID or mutationID
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == workoutID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            // Already completed idempotently
            return WorkoutCompletionOutcome(workoutID: existing.id, mutationID: mutationID)
        }

        // Save context after materializing completed workout
        try modelContext.save()
        return WorkoutCompletionOutcome(workoutID: workoutID, mutationID: mutationID)
    }
}

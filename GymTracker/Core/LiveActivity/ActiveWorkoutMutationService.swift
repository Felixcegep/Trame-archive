import Foundation
import SwiftData

/// Applies the persisted workout mutations that can be initiated by both the
/// in-app workout UI and an interactive Live Activity. The service deliberately
/// has no SwiftUI or countdown-task state: SwiftData remains the sole source of
/// truth and callers rebuild their presentation from the returned projection.
@MainActor
struct ActiveWorkoutMutationService {
    typealias CurrentSetLog = WorkoutSetCompletionWorkflow.Log

    enum Result: Equatable {
        case applied(LiveActivityProjection)
        case stale(LiveActivityProjection?)
        case invalid(LiveActivityProjection)
        case unavailable
    }

    let modelContext: ModelContext
    let defaultRestSeconds: Int

    init(
        modelContext: ModelContext,
        defaultRestSeconds: Int? = nil
    ) {
        self.modelContext = modelContext
        let preferredRestSeconds = defaultRestSeconds
            ?? UserDefaults.standard.integer(forKey: DefaultsKey.restTimer)
        self.defaultRestSeconds = preferredRestSeconds > 0 ? preferredRestSeconds : 20
    }

    func completeCurrentSet(
        workoutID: UUID,
        expectedExerciseOrderIndex: Int,
        expectedSetOrderIndex: Int,
        now: Date = .now
    ) -> Result {
        completionResult(WorkoutSetCompletionWorkflow(modelContext: modelContext).execute(
            .init(
                workoutID: workoutID,
                target: .expectedCurrent(
                    exerciseOrderIndex: expectedExerciseOrderIndex,
                    setOrderIndex: expectedSetOrderIndex
                ),
                fallbackRestSeconds: defaultRestSeconds,
                now: now
            )
        ))
    }

    /// Logs the next incomplete strength set and completes it in one durable
    /// transaction. Optional values intentionally preserve the current
    /// prescription when a shortcut only says “log my set”.
    func logCurrentSet(
        workoutID: UUID,
        log: CurrentSetLog,
        now: Date = .now
    ) -> Result {
        completionResult(WorkoutSetCompletionWorkflow(modelContext: modelContext).execute(
            .init(
                workoutID: workoutID,
                target: .current,
                log: log,
                fallbackRestSeconds: defaultRestSeconds,
                now: now
            )
        ))
    }

    func pauseRest(workoutID: UUID, now: Date = .now) -> Result {
        guard let workout = activeWorkout(id: workoutID) else {
            return .unavailable
        }
        guard let deadline = workout.restEndDate else {
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }

        let remaining = max(0, deadline.timeIntervalSince(now))
        workout.restEndDate = nil
        workout.pausedRemainingTime = remaining > 0 ? remaining : nil
        return saveAndProject(workout, now: now)
    }

    func resumeRest(workoutID: UUID, now: Date = .now) -> Result {
        guard let workout = activeWorkout(id: workoutID) else {
            return .unavailable
        }
        guard let remaining = workout.pausedRemainingTime, remaining > 0 else {
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }

        workout.restEndDate = now.addingTimeInterval(remaining)
        workout.pausedRemainingTime = nil
        return saveAndProject(workout, now: now)
    }

    func extendRest(workoutID: UUID, by seconds: TimeInterval, now: Date = .now) -> Result {
        guard seconds > 0, let workout = activeWorkout(id: workoutID) else {
            return .unavailable
        }

        if let remaining = workout.pausedRemainingTime, remaining > 0 {
            workout.pausedRemainingTime = remaining + seconds
            return saveAndProject(workout, now: now)
        }

        guard let deadline = workout.restEndDate, deadline > now else {
            if workout.restEndDate != nil {
                workout.restEndDate = nil
                workout.pausedRemainingTime = nil
                return saveAndProject(workout, now: now)
            }
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }

        workout.restEndDate = deadline.addingTimeInterval(seconds)
        return saveAndProject(workout, now: now)
    }

    func skipRest(workoutID: UUID, now: Date = .now) -> Result {
        guard let workout = activeWorkout(id: workoutID) else {
            return .unavailable
        }
        guard workout.restEndDate != nil || workout.pausedRemainingTime != nil else {
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }

        workout.restEndDate = nil
        workout.pausedRemainingTime = nil
        return saveAndProject(workout, now: now)
    }

    static func canComplete(_ set: ExerciseSet, for exercise: ExerciseEntry) -> Bool {
        validationResult(for: set, exercise: exercise).isValid
    }

    static func validationResult(
        for set: ExerciseSet,
        exercise: ExerciseEntry
    ) -> WorkoutSetCompletionValidator.Result {
        WorkoutSetCompletionValidator.validate(
            .init(set: set, trackingType: exercise.trackingTypeSnapshot)
        )
    }

    private func activeWorkout(id: UUID) -> Workout? {
        (try? modelContext.fetch(FetchDescriptor<Workout>()))?
            .first { $0.id == id && $0.status == .active }
    }

    private func completionResult(_ outcome: WorkoutSetCompletionWorkflow.Outcome) -> Result {
        switch outcome {
        case .applied(let receipt):
            NotificationCenter.default.post(name: .activeWorkoutMutated, object: receipt.workoutID)
            return .applied(receipt.projection)
        case .stale(let projection):
            return .stale(projection)
        case .invalid(_, let projection):
            return .invalid(projection)
        case .unavailable:
            return .unavailable
        case .persistenceFailure(let failure):
            // Preserve the existing external-surface contract: save failures
            // reconcile the rolled-back projection and behave as a stale
            // action. The shared workflow retains the typed failure for direct
            // foreground handling and conformance tests.
            return .stale(failure.projectionAfterRollback)
        }
    }

    private func saveAndProject(_ workout: Workout, now: Date) -> Result {
        do {
            try modelContext.save()
            // Every mutation here can run against a `ModelContext` distinct
            // from the one the root SwiftUI scene observes (an App Intent or
            // Live Activity button executes in-process but constructs its
            // own context). Post only the identifiers a foreground observer
            // needs to refetch its own copy — never the model object itself,
            // which belongs to this context and must not cross the boundary.
            NotificationCenter.default.post(
                name: .activeWorkoutMutated,
                object: workout.id
            )
            return .applied(LiveActivityProjection(workout: workout, now: now))
        } catch {
            modelContext.rollback()
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }
    }
}

extension Notification.Name {
    /// Posted after `ActiveWorkoutMutationService` commits a successful
    /// mutation, carrying the affected workout's `UUID` as `object`. A save
    /// failure never posts this — only a fully durable state change should
    /// prompt the foreground UI to reconcile.
    static let activeWorkoutMutated = Notification.Name("activeWorkoutMutated")
}

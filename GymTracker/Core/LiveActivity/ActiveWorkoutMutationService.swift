import Foundation
import SwiftData

/// Applies the persisted workout mutations that can be initiated by both the
/// in-app workout UI and an interactive Live Activity. The service deliberately
/// has no SwiftUI or countdown-task state: SwiftData remains the sole source of
/// truth and callers rebuild their presentation from the returned projection.
@MainActor
struct ActiveWorkoutMutationService {
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
        guard let workout = activeWorkout(id: workoutID) else {
            return .unavailable
        }

        guard let current = currentSet(in: workout) else {
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }

        guard
            current.exercise.orderIndex == expectedExerciseOrderIndex,
            current.set.orderIndex == expectedSetOrderIndex
        else {
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }

        guard Self.canComplete(current.set, for: current.exercise) else {
            return .invalid(LiveActivityProjection(workout: workout, now: now))
        }

        current.set.done = true
        let restSeconds = max(0, current.exercise.prescribedRestSeconds ?? defaultRestSeconds)
        workout.restEndDate = restSeconds > 0
            ? now.addingTimeInterval(TimeInterval(restSeconds))
            : nil
        workout.pausedRemainingTime = nil

        return saveAndProject(workout, now: now)
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
        let trackingType = exercise.trackingTypeSnapshot

        if trackingType.usesReps, set.repetitions <= 0 {
            return false
        }
        if trackingType.usesDuration, (set.duration ?? 0) <= 0 {
            return false
        }
        if trackingType.usesDistance, (set.distance ?? 0) <= 0 {
            return false
        }
        return true
    }

    private func activeWorkout(id: UUID) -> Workout? {
        (try? modelContext.fetch(FetchDescriptor<Workout>()))?
            .first { $0.id == id && $0.status == .active }
    }

    private func currentSet(in workout: Workout) -> (exercise: ExerciseEntry, set: ExerciseSet)? {
        for exercise in workout.orderedExercises {
            if let set = exercise.orderedSets.first(where: { !$0.done }) {
                return (exercise, set)
            }
        }
        return nil
    }

    private func saveAndProject(_ workout: Workout, now: Date) -> Result {
        do {
            try modelContext.save()
            return .applied(LiveActivityProjection(workout: workout, now: now))
        } catch {
            modelContext.rollback()
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }
    }
}

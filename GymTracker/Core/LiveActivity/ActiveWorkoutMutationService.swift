import Foundation
import SwiftData

/// Applies the persisted workout mutations that can be initiated by both the
/// in-app workout UI and an interactive Live Activity. The service deliberately
/// has no SwiftUI or countdown-task state: SwiftData remains the sole source of
/// truth and callers rebuild their presentation from the returned projection.
@MainActor
struct ActiveWorkoutMutationService {
    struct CurrentSetLog {
        var repetitions: Int?
        var weight: Double?
        var rpe: Int?
        var rir: Int?

        init(
            repetitions: Int? = nil,
            weight: Double? = nil,
            rpe: Int? = nil,
            rir: Int? = nil
        ) {
            self.repetitions = repetitions
            self.weight = weight
            self.rpe = rpe
            self.rir = rir
        }
    }

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
        #if !GYMTRACKER_EXTENSION
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        #endif
        let restSeconds = WorkoutSetSelector.restSeconds(
            afterCompleting: current.exercise,
            in: workout,
            defaultSeconds: defaultRestSeconds
        )
        workout.restEndDate = restSeconds.map {
            now.addingTimeInterval(TimeInterval($0))
        }
        workout.pausedRemainingTime = nil

        return saveAndProject(workout, now: now)
    }

    /// Logs the next incomplete strength set and completes it in one durable
    /// transaction. Optional values intentionally preserve the current
    /// prescription when a shortcut only says “log my set”.
    func logCurrentSet(
        workoutID: UUID,
        log: CurrentSetLog,
        now: Date = .now
    ) -> Result {
        guard let workout = activeWorkout(id: workoutID) else {
            return .unavailable
        }
        guard let current = currentSet(in: workout) else {
            return .stale(LiveActivityProjection(workout: workout, now: now))
        }
        guard log.rpe == nil || log.rir == nil else {
            return .invalid(LiveActivityProjection(workout: workout, now: now))
        }
        guard log.repetitions.map({ $0 > 0 }) ?? true,
              log.weight.map({ $0 >= 0 }) ?? true,
              log.rpe.map({ (1...10).contains($0) }) ?? true,
              log.rir.map({ (0...6).contains($0) }) ?? true
        else {
            return .invalid(LiveActivityProjection(workout: workout, now: now))
        }

        if let repetitions = log.repetitions {
            current.set.repetitions = Float(repetitions)
        }
        if let weight = log.weight {
            current.set.weight = Float(weight)
        }
        if let rpe = log.rpe {
            current.set.recordRPE(rpe)
        }
        if let rir = log.rir {
            current.set.recordRIR(rir)
        }
        guard Self.canComplete(current.set, for: current.exercise) else {
            return .invalid(LiveActivityProjection(workout: workout, now: now))
        }

        current.set.done = true
        current.set.synchronizeSegmentCompletion()
        #if !GYMTRACKER_EXTENSION
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        #endif
        let restSeconds = WorkoutSetSelector.restSeconds(
            afterCompleting: current.exercise,
            in: workout,
            defaultSeconds: defaultRestSeconds
        )
        workout.restEndDate = restSeconds.map { now.addingTimeInterval(TimeInterval($0)) }
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
        if trackingType.usesCalories, (set.calories ?? 0) <= 0 {
            return false
        }
        return true
    }

    private func activeWorkout(id: UUID) -> Workout? {
        (try? modelContext.fetch(FetchDescriptor<Workout>()))?
            .first { $0.id == id && $0.status == .active }
    }

    private func currentSet(in workout: Workout) -> (exercise: ExerciseEntry, set: ExerciseSet)? {
        WorkoutSetSelector.nextIncompleteSet(in: workout).map {
            (exercise: $0.entry, set: $0.set)
        }
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

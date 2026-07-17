import Foundation
import SwiftUI
import SwiftData

@Observable
class ActiveWorkoutViewModel {
    var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
    }
    
    var workoutVM: WorkoutViewModel
    let modelContext: ModelContext
    
    private let restTimer = RestTimerController()
    private var timerTask: Task<Void, Never>?
    private(set) var previousPerformances: [PersistentIdentifier: PreviousExercisePerformance] = [:]

    var isTimerVisible: Bool { restTimer.isVisible }
    var timerPause: Date? { restTimer.endDate }
    
    init(workoutVM: WorkoutViewModel, modelContext: ModelContext) {
        self.workoutVM = workoutVM
        self.modelContext = modelContext
    }

    var activeWorkout: Workout? {
        workoutVM.activeWorkout
    }

    private var restDuration: TimeInterval {
        let defaults = UserDefaults.standard
        let savedDuration = defaults.integer(forKey: DefaultsKey.restTimer)

        guard defaults.object(forKey: DefaultsKey.restTimer) != nil, savedDuration > 0 else {
            return 20
        }

        return TimeInterval(savedDuration)
    }

    func getNextExerciseToDo() -> (exercise: ExerciseEntry, set: ExerciseSet)? {
        guard let workout = workoutVM.workout else {
            return nil
        }

        for exercise in workout.orderedExercises {
            for set in exercise.orderedSets {
                if !set.done {
                    return (exercise, set)
                }
            }
        }

        return nil
    }
    
    func addExercise(_ template: Exercise) {
        guard let activeWorkout = workoutVM.activeWorkout else { return }

        let newExercise = ExerciseEntry(
            from: template,
            orderIndex: (activeWorkout.orderedExercises.last?.orderIndex ?? -1) + 1,
            usedMetric: unitSystem
        )
        activeWorkout.exercises.append(newExercise)
        persistChanges()
        loadPreviousPerformance(for: newExercise)
        workoutVM.reconcileLiveActivity()
    }

    func removeSet(_ exerciseEntry: ExerciseEntry, _ set: ExerciseSet) {
        if let workout = workoutVM.activeWorkout {
            guard let storedExercise = workout.exercises.first(where: { $0.id == exerciseEntry.id }) else { return }
            storedExercise.sets.removeAll(where: { $0.id == set.id })
            modelContext.delete(set)
            exerciseEntry.normalizeSetOrder()
            persistChanges()
        }
    }
    
    /// Adds a set pre-filled with the last set's values (reps, weight,
    /// duration, distance) so lifters rarely retype; RPE and set type reset
    /// because they describe one specific effort.
    func addSet(_ exerciseEntry: ExerciseEntry) {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(where: { $0.id == exerciseEntry.id })
        else { return }

        if let lastSet = exercise.orderedSets.last {
            let newSet = lastSet.copy()
            newSet.rpe = nil
            newSet.setType = .normal
            newSet.orderIndex = lastSet.orderIndex + 1
            exercise.sets.append(newSet)
        } else {
            exercise.addEmptySet()
        }
        persistChanges()
    }

    func copyPreviousSetValue(exerciseEntry: ExerciseEntry, currentSetIndex: Int) {
        let orderedSets = exerciseEntry.orderedSets
        guard currentSetIndex > 0, currentSetIndex < orderedSets.count else { return }

        let previousSet = orderedSets[currentSetIndex - 1]
        let currentSet = orderedSets[currentSetIndex]
        currentSet.repetitions = previousSet.repetitions
        currentSet.weight = previousSet.weight
        currentSet.duration = previousSet.duration
        currentSet.distance = previousSet.distance
        currentSet.rpe = previousSet.rpe
        persistChanges()
    }

    func loadPreviousPerformances() {
        guard let workout = activeWorkout else { return }
        for exercise in workout.orderedExercises {
            loadPreviousPerformance(for: exercise)
        }
    }

    func previousPerformance(for exercise: ExerciseEntry) -> PreviousExercisePerformance? {
        previousPerformances[exercise.persistentModelID]
    }

    /// Applies the matching prior set only when the active set has not been
    /// completed. Historical units are converted into this set's stored unit.
    func applyPreviousPerformance(to set: ExerciseSet, in exercise: ExerciseEntry, index: Int) {
        guard !set.done,
              let previousSet = previousPerformance(for: exercise)?.set(at: index)
        else {
            return
        }

        if exercise.trackingTypeSnapshot.usesReps {
            set.repetitions = previousSet.repetitions
        }
        if exercise.trackingTypeSnapshot.usesWeight {
            set.weight = UnitConversion.weight(
                previousSet.weight,
                from: previousSet.weightType,
                to: set.weightType
            )
        }
        if exercise.trackingTypeSnapshot.usesDuration {
            set.duration = previousSet.duration
        }
        if exercise.trackingTypeSnapshot.usesDistance, let distance = previousSet.distance {
            set.distance = UnitConversion.distance(
                distance,
                from: previousSet.distanceType,
                to: set.distanceType
            )
        }
        persistChanges()
    }

    /// Applies only the suggested load. Reps remain explicit user input (or can
    /// still be filled from previous-performance hints), and completed sets are
    /// never rewritten.
    func applyRecommendation(to exercise: ExerciseEntry) {
        guard
            exercise.trackingTypeSnapshot.usesWeight,
            exercise.recommendedDecision != nil,
            let load = exercise.recommendedLoad,
            let unit = exercise.recommendedUnit
        else {
            return
        }

        for set in exercise.orderedSets where !set.done {
            set.weight = UnitConversion.weight(load, from: unit, to: set.weightType)
        }
        persistChanges()
    }

    /// Applies the last completed session's load to every incomplete set. This
    /// is intentionally separate from previous-set prefill because the
    /// recommendation card changes load only and leaves reps explicit.
    func applyPriorRecommendationLoad(to exercise: ExerciseEntry) {
        guard
            exercise.trackingTypeSnapshot.usesWeight,
            let load = exercise.recommendationPriorLoad,
            let unit = exercise.recommendedUnit
        else {
            return
        }

        for set in exercise.orderedSets where !set.done {
            set.weight = UnitConversion.weight(load, from: unit, to: set.weightType)
        }
        persistChanges()
    }
    
    @discardableResult
    func switchStateDoneSet(
        _ selectedExercise: ExerciseEntry,
        _ selectedSet: ExerciseSet
    ) -> Bool {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(
                where: { $0.id == selectedExercise.id }
            ),
            let set = exercise.sets.first(
                where: { $0.id == selectedSet.id }
            )
        else {
            return false
        }

        guard set.done || canComplete(set, for: exercise) else {
            return false
        }

        set.done.toggle()
        persistChanges()
        return true
    }

    func canComplete(_ set: ExerciseSet, for exercise: ExerciseEntry) -> Bool {
        ActiveWorkoutMutationService.canComplete(set, for: exercise)
    }

    func trackActiveExercise(with identifier: PersistentIdentifier?) {
        guard let workout = activeWorkout else { return }
        let now = Date.now

        for exercise in workout.orderedExercises {
            let shouldRun = exercise.persistentModelID == identifier
                && exercise.orderedSets.contains(where: { !$0.done })
            if shouldRun {
                exercise.startActiveDuration(at: now)
            } else {
                exercise.stopActiveDuration(at: now)
            }
        }
        persistChanges()
    }
    func getNextSet(in selectedExercise: ExerciseEntry) -> ExerciseSet?{
        guard let nextSet = selectedExercise.orderedSets.first(where: { !$0.done }) else {
            return nil
        }
        return nextSet
    }
    
    func markNextSetDone(in selectedExercise: ExerciseEntry) {
        guard let nextSet = selectedExercise.orderedSets.first(where: { !$0.done }) else {
            return
        }

        nextSet.done = true
        persistChanges()
    }
    

   
    
    func startTime(after exercise: ExerciseEntry? = nil) {
        let duration = TimeInterval(exercise?.prescribedRestSeconds ?? Int(restDuration))
        let timerEndDate = Date.now.addingTimeInterval(duration)

        workoutVM.activeWorkout?.restEndDate = timerEndDate
        workoutVM.activeWorkout?.pausedRemainingTime = nil
        persistChanges()
        runRestCountdown(until: timerEndDate)
    }

    var isTimerPaused: Bool {
        restTimer.pausedRemaining != nil
    }

    var isRestReady: Bool {
        restTimer.isReady
    }

    var pausedTimeRemaining: TimeInterval {
        restTimer.pausedRemaining ?? 0
    }

    func restorePersistedRestTimer() {
        if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            guard timerEndDate > .now else {
                workoutVM.activeWorkout?.restEndDate = nil
                persistChanges()
                restTimer.ready()
                workoutVM.reconcileLiveActivity()
                return
            }
            runRestCountdown(until: timerEndDate)
        } else if let pausedRemaining = workoutVM.activeWorkout?.pausedRemainingTime {
            timerTask?.cancel()
            timerTask = nil
            restTimer.restore(endDate: nil, pausedRemaining: pausedRemaining)
            workoutVM.reconcileLiveActivity()
        }
    }

    func pauseTimer() {
        guard let timerEndDate = workoutVM.activeWorkout?.restEndDate else { return }

        timerTask?.cancel()
        timerTask = nil

        let remaining = max(0, timerEndDate.timeIntervalSinceNow)
        workoutVM.activeWorkout?.pausedRemainingTime = remaining
        workoutVM.activeWorkout?.restEndDate = nil
        restTimer.pause(remaining: remaining)
        persistChanges()

        workoutVM.reconcileLiveActivity()
    }

    func resumeTimer() {
        guard let pausedRemaining = workoutVM.activeWorkout?.pausedRemainingTime else { return }

        let timerEndDate = Date.now.addingTimeInterval(pausedRemaining)
        workoutVM.activeWorkout?.restEndDate = timerEndDate
        workoutVM.activeWorkout?.pausedRemainingTime = nil
        persistChanges()
        runRestCountdown(until: timerEndDate)
    }

    func addRestTime(_ seconds: TimeInterval) {
        if isTimerPaused {
            if let currentPaused = workoutVM.activeWorkout?.pausedRemainingTime {
                workoutVM.activeWorkout?.pausedRemainingTime = currentPaused + seconds
                restTimer.extendPaused(by: seconds)
                persistChanges()
            }
        } else if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            let newEndDate = timerEndDate.addingTimeInterval(seconds)
            workoutVM.activeWorkout?.restEndDate = newEndDate
            persistChanges()
            runRestCountdown(until: newEndDate)
        }
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        restTimer.cancel()
        if workoutVM.activeWorkout?.restEndDate != nil || workoutVM.activeWorkout?.pausedRemainingTime != nil {
            workoutVM.activeWorkout?.restEndDate = nil
            workoutVM.activeWorkout?.pausedRemainingTime = nil
            persistChanges()
        }
        workoutVM.reconcileLiveActivity()
    }

    /// The single countdown path used by a newly started, restored, resumed, or
    /// extended rest period. Persisted state remains the recovery source of truth.
    private func runRestCountdown(until timerEndDate: Date) {
        timerTask?.cancel()
        restTimer.start(until: timerEndDate)

        timerTask = Task {
            await MainActor.run {
                workoutVM.reconcileLiveActivity()
            }

            do {
                try await Task.sleep(for: .seconds(max(0, timerEndDate.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    restTimer.ready()
                    workoutVM.activeWorkout?.restEndDate = nil
                    persistChanges()
                }

                await MainActor.run {
                    workoutVM.reconcileLiveActivity()
                }
            } catch {
                return
            }
        }
    }


    
    func removeExercise(_ exerciseEntry: ExerciseEntry) {
        if let workout = workoutVM.activeWorkout {
            workout.exercises.removeAll { $0 === exerciseEntry }
            modelContext.delete(exerciseEntry)
            workout.normalizeExerciseOrder()
            persistChanges()
        }
    }

    /// A replacement is intentionally allowed only before the entry has any
    /// completed sets. Completed entries are part of the workout's historical
    /// record and must not be reinterpreted as another exercise.
    @discardableResult
    func swapExercise(_ exerciseEntry: ExerciseEntry, with replacement: Exercise) -> Bool {
        guard
            let workout = workoutVM.activeWorkout,
            let storedExercise = workout.exercises.first(where: { $0.id == exerciseEntry.id }),
            storedExercise.exercise.id != replacement.id,
            !storedExercise.sets.contains(where: \.done)
        else {
            return false
        }

        let setCount = max(storedExercise.sets.count, 1)
        for set in storedExercise.sets {
            modelContext.delete(set)
        }
        storedExercise.sets.removeAll()
        storedExercise.updateExerciseSnapshot(from: replacement)
        storedExercise.addDefaultSets(count: setCount)
        previousPerformances.removeValue(forKey: storedExercise.persistentModelID)
        persistChanges()
        loadPreviousPerformance(for: storedExercise)
        return true
    }

    func persistChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to persist active workout changes: \(error)")
        }
    }

    private func loadPreviousPerformance(for exercise: ExerciseEntry) {
        guard let workout = activeWorkout else { return }

        do {
            if let performance = try ExerciseHistoryService(modelContext: modelContext)
                .mostRecentPerformance(for: exercise.exercise, before: workout.startTime) {
                previousPerformances[exercise.persistentModelID] = performance
            } else {
                previousPerformances.removeValue(forKey: exercise.persistentModelID)
            }
        } catch {
            print("Failed to load previous exercise performance: \(error)")
        }
    }

    func copyValuesForFocusedSet(_ focus: SetInputFocus?) {
        guard
            let focus,
            let exercise = workoutVM.activeWorkout?.orderedExercises.first(where: { $0.persistentModelID == focus.exerciseID }),
            let setIndex = exercise.orderedSets.firstIndex(where: { $0.persistentModelID == focus.setID })
        else {
            return
        }

        copyPreviousSetValue(exerciseEntry: exercise, currentSetIndex: setIndex)
    }

    func canCopyValuesForFocusedSet(_ focus: SetInputFocus?) -> Bool {
        guard
            let focus,
            let exercise = workoutVM.activeWorkout?.orderedExercises.first(where: { $0.persistentModelID == focus.exerciseID }),
            let setIndex = exercise.orderedSets.firstIndex(where: { $0.persistentModelID == focus.setID })
        else {
            return false
        }

        return setIndex > 0
    }

}

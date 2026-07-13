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

    func getNextExerciseToDo() -> (exercise: ExerciceEntry, set: ExerciseSet)? {
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
    
    func addExercise(_ template: ExerciceTemplate) {
        guard let activeWorkout = workoutVM.activeWorkout else { return }

        let newExercise = ExerciceEntry(
            from: template,
            orderIndex: (activeWorkout.orderedExercises.last?.orderIndex ?? -1) + 1,
            usedMetric: unitSystem
        )
        activeWorkout.exercises.append(newExercise)
        persistChanges()
        loadPreviousPerformance(for: newExercise)

        if let nextExercise = getNextExerciseToDo(),
           let nextSetIndex = nextExercise.exercise.orderedSets.firstIndex(where: { !$0.done }) {
            Task {
                await LiveActivityManager.shared.updateExercise(
                    name: nextExercise.exercise.exercice.name,
                    currentSet: nextSetIndex + 1,
                    totalSets: nextExercise.exercise.sets.count
                )
            }
        }
    }

    func removeSet(_ exerciseEntry: ExerciceEntry, _ set: ExerciseSet) {
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
    func addSet(_ exerciseEntry: ExerciceEntry) {
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

    func copyPreviousSetValue(exerciseEntry: ExerciceEntry, currentSetIndex: Int) {
        let orderedSets = exerciseEntry.orderedSets
        guard currentSetIndex > 0, currentSetIndex < orderedSets.count else { return }

        let previousSet = orderedSets[currentSetIndex - 1]
        let currentSet = orderedSets[currentSetIndex]
        currentSet.repetition = previousSet.repetition
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

    func previousPerformance(for exercise: ExerciceEntry) -> PreviousExercisePerformance? {
        previousPerformances[exercise.persistentModelID]
    }

    /// Applies the matching prior set only when the active set has not been
    /// completed. Historical units are converted into this set's stored unit.
    func applyPreviousPerformance(to set: ExerciseSet, in exercise: ExerciceEntry, index: Int) {
        guard !set.done,
              let previousSet = previousPerformance(for: exercise)?.set(at: index)
        else {
            return
        }

        if exercise.exercice.trackingType.usesReps {
            set.repetition = previousSet.repetitions
        }
        if exercise.exercice.trackingType.usesWeight {
            set.weight = UnitConversion.weight(
                previousSet.weight,
                from: previousSet.weightType,
                to: set.weightType
            )
        }
        if exercise.exercice.trackingType.usesDuration {
            set.duration = previousSet.duration
        }
        if exercise.exercice.trackingType.usesDistance, let distance = previousSet.distance {
            set.distance = UnitConversion.distance(
                distance,
                from: previousSet.distanceType,
                to: set.distanceType
            )
        }
        persistChanges()
    }
    
    @discardableResult
    func switchStateDoneSet(
        _ selectedExercise: ExerciceEntry,
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

    func canComplete(_ set: ExerciseSet, for exercise: ExerciceEntry) -> Bool {
        let trackingType = exercise.exercice.trackingType

        if trackingType.usesReps, set.repetition <= 0 {
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
    func getNextSet(in selectedExercise: ExerciceEntry) -> ExerciseSet?{
        guard let nextSet = selectedExercise.orderedSets.first(where: { !$0.done }) else {
            return nil
        }
        return nextSet
    }
    
    func markNextSetDone(in selectedExercise: ExerciceEntry) {
        guard let nextSet = selectedExercise.orderedSets.first(where: { !$0.done }) else {
            return
        }

        nextSet.done = true
        persistChanges()
    }
    

   
    
    func startTime(after exercise: ExerciceEntry? = nil) {
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

    var pausedTimeRemaining: TimeInterval {
        restTimer.pausedRemaining ?? 0
    }

    func restorePersistedRestTimer() {
        if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            guard timerEndDate > .now else {
                workoutVM.activeWorkout?.restEndDate = nil
                persistChanges()
                restTimer.cancel()
                return
            }
            runRestCountdown(until: timerEndDate)
        } else if let pausedRemaining = workoutVM.activeWorkout?.pausedRemainingTime {
            timerTask?.cancel()
            timerTask = nil
            restTimer.restore(endDate: nil, pausedRemaining: pausedRemaining)
            Task {
                await LiveActivityManager.shared.pausePause()
            }
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

        Task {
            await LiveActivityManager.shared.pausePause()
        }
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
    }

    /// The single countdown path used by a newly started, restored, resumed, or
    /// extended rest period. Persisted state remains the recovery source of truth.
    private func runRestCountdown(until timerEndDate: Date) {
        timerTask?.cancel()
        restTimer.start(until: timerEndDate)

        timerTask = Task {
            if let nextExercise = getNextExerciseToDo(),
               let nextSetIndex = nextExercise.exercise.orderedSets.firstIndex(where: { !$0.done }) {
                await LiveActivityManager.shared.updateExercise(
                    name: nextExercise.exercise.exercice.name,
                    currentSet: nextSetIndex + 1,
                    totalSets: nextExercise.exercise.sets.count
                )
            }
            await LiveActivityManager.shared.startPause(timerEndDate: timerEndDate)

            do {
                try await Task.sleep(for: .seconds(max(0, timerEndDate.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    restTimer.cancel()
                    workoutVM.activeWorkout?.restEndDate = nil
                    persistChanges()
                }

                if let nextExercise = getNextExerciseToDo(),
                   let nextSetIndex = nextExercise.exercise.orderedSets.firstIndex(where: { !$0.done }) {
                    await LiveActivityManager.shared.updateExercise(
                        name: nextExercise.exercise.exercice.name,
                        currentSet: nextSetIndex + 1,
                        totalSets: nextExercise.exercise.sets.count
                    )
                }
            } catch {
                return
            }
        }
    }


    
    func removeExercise(_ exerciseEntry: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout {
            workout.exercises.removeAll { $0 === exerciseEntry }
            modelContext.delete(exerciseEntry)
            workout.normalizeExerciseOrder()
            persistChanges()
        }
    }

    func persistChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to persist active workout changes: \(error)")
        }
    }

    private func loadPreviousPerformance(for exercise: ExerciceEntry) {
        guard let workout = activeWorkout else { return }

        do {
            if let performance = try ExerciseHistoryService(modelContext: modelContext)
                .mostRecentPerformance(for: exercise.exercice, before: workout.startTime) {
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

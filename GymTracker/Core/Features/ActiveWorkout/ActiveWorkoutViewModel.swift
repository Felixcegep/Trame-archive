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
    
    var isTimerVisible : Bool = false
    var timerTask: Task<Void, Never>?
    
    // timer
    var timerPause : Date?
    
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
            workout.exercises.first(where: { $0.id == exerciseEntry.id })?.sets.removeAll(where: { $0.id == set.id })
            exerciseEntry.normalizeSetOrder()
            persistChanges()
        }
    }
    
    func addSet(_ exerciseEntry: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout {
            workout.exercises.first(where: { $0.id == exerciseEntry.id })?.addEmptySet()
            persistChanges()
        }
        
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
    
    func addSetCopyLastSet(exerciseEntry: ExerciceEntry) {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(where: { $0.id == exerciseEntry.id }),
            let lastSet = exercise.orderedSets.last
        else {
            return
        }

        let newSet = lastSet.copy()
        newSet.orderIndex = (exercise.orderedSets.last?.orderIndex ?? -1) + 1
        exercise.sets.append(newSet)
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
        timerTask?.cancel()

        let duration = TimeInterval(exercise?.prescribedRestSeconds ?? Int(restDuration))
        let timerEndDate = Date.now.addingTimeInterval(duration)

        workoutVM.activeWorkout?.restEndDate = timerEndDate
        persistChanges()

        isTimerVisible = true
        timerPause = timerEndDate
        
        

        
        
        timerTask = Task {
            do {
                print("lancement de la pause")

                if let nextExercise = getNextExerciseToDo(),
                   let nextSetIndex = nextExercise.exercise.orderedSets.firstIndex(where: { !$0.done }) {
                    await LiveActivityManager.shared.updateExercise(
                        name: nextExercise.exercise.exercice.name,
                        currentSet: nextSetIndex + 1,
                        totalSets: nextExercise.exercise.sets.count
                    )
                }

                await LiveActivityManager.shared.startPause(timerEndDate: timerEndDate)
        
                try await Task.sleep(for: .seconds(duration))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    isTimerVisible = false
                    timerPause = nil
                    workoutVM.activeWorkout?.restEndDate = nil
                    persistChanges()
                }
                if let nextExercice = getNextExerciseToDo(),
                   let nextSetIndex = nextExercice.exercise.orderedSets.firstIndex(where: { !$0.done }) {
                    print("Live ACtive Exercice Changement")
                    await LiveActivityManager.shared.updateExercise(
                        name: nextExercice.exercise.exercice.name,
                        currentSet: nextSetIndex + 1,
                        totalSets: nextExercice.exercise.sets.count
                    )
                }
                
                
                
                    return
            } catch {
                return
            }
        }
    }

    var isTimerPaused: Bool {
        activeWorkout?.pausedRemainingTime != nil
    }

    var pausedTimeRemaining: TimeInterval {
        activeWorkout?.pausedRemainingTime ?? 0
    }

    func restorePersistedRestTimer() {
        if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            guard timerEndDate > .now else {
                workoutVM.activeWorkout?.restEndDate = nil
                persistChanges()
                return
            }

            timerTask?.cancel()
            isTimerVisible = true
            timerPause = timerEndDate

            timerTask = Task {
                await LiveActivityManager.shared.startPause(timerEndDate: timerEndDate)

                do {
                    try await Task.sleep(for: .seconds(timerEndDate.timeIntervalSinceNow))
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        isTimerVisible = false
                        timerPause = nil
                        workoutVM.activeWorkout?.restEndDate = nil
                        persistChanges()
                    }
                } catch {
                    return
                }
            }
        } else if let pausedRemaining = workoutVM.activeWorkout?.pausedRemainingTime {
            timerTask?.cancel()
            timerTask = nil
            isTimerVisible = true
            timerPause = nil
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
        timerPause = nil
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

        timerPause = timerEndDate
        isTimerVisible = true

        timerTask?.cancel()
        timerTask = Task {
            await LiveActivityManager.shared.startPause(timerEndDate: timerEndDate)

            do {
                try await Task.sleep(for: .seconds(pausedRemaining))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    isTimerVisible = false
                    timerPause = nil
                    workoutVM.activeWorkout?.restEndDate = nil
                    persistChanges()
                }
            } catch {
                return
            }
        }
    }

    func addRestTime(_ seconds: TimeInterval) {
        if isTimerPaused {
            if let currentPaused = workoutVM.activeWorkout?.pausedRemainingTime {
                workoutVM.activeWorkout?.pausedRemainingTime = currentPaused + seconds
                persistChanges()
            }
        } else if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            let newEndDate = timerEndDate.addingTimeInterval(seconds)
            workoutVM.activeWorkout?.restEndDate = newEndDate
            persistChanges()

            timerPause = newEndDate

            let remaining = newEndDate.timeIntervalSinceNow

            timerTask?.cancel()
            timerTask = Task {
                await LiveActivityManager.shared.startPause(timerEndDate: newEndDate)

                do {
                    try await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        isTimerVisible = false
                        timerPause = nil
                        workoutVM.activeWorkout?.restEndDate = nil
                        persistChanges()
                    }
                } catch {
                    return
                }
            }
        }
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTimerVisible = false
        timerPause = nil
        if workoutVM.activeWorkout?.restEndDate != nil || workoutVM.activeWorkout?.pausedRemainingTime != nil {
            workoutVM.activeWorkout?.restEndDate = nil
            workoutVM.activeWorkout?.pausedRemainingTime = nil
            persistChanges()
        }
    }


    
    func removeExercise(_ exerciseEntry: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout {
            workout.exercises.removeAll { $0 === exerciseEntry }
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

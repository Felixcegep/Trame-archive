import Foundation
import SwiftUI

@Observable
class ActiveWorkoutViewModel {
    let rawValue = UserDefaults.standard.string(forKey: "useMetric")
    var unitSystem: UnitSystem {
        UnitSystem(rawValue: rawValue ?? UnitSystem.metric.rawValue) ?? .metric
    }
    
    var workoutVM: WorkoutViewModel
    
    var isTimerVisible : Bool = false
    var timerTask: Task<Void, Never>?
    
    // timer
    var timerPause : Date?
    
    init(workoutVM: WorkoutViewModel) {
        self.workoutVM = workoutVM
    }

    var activeWorkout: Workout? {
        workoutVM.activeWorkout
    }

    private var restDuration: TimeInterval {
        let defaults = UserDefaults.standard
        let savedDuration = defaults.integer(forKey: "restTimer")

        guard defaults.object(forKey: "restTimer") != nil, savedDuration > 0 else {
            return 20
        }

        return TimeInterval(savedDuration)
    }

    func getNextExerciseToDo() -> (exercise: ExerciceEntry, set: ExerciseSet)? {
        guard let workout = workoutVM.workout else {
            return nil
        }

        for exercise in workout.exercises {
            for set in exercise.sets {
                if !set.done {
                    return (exercise, set)
                }
            }
        }

        return nil
    }
    
    func addExercise(_ template: ExerciceTemplate) {
        guard let activeWorkout = workoutVM.activeWorkout else { return }

        let newExercise = ExerciceEntry(from : template, usedMetric: unitSystem)
        activeWorkout.exercises.append(newExercise)

        if let nextExercise = getNextExerciseToDo(),
           let nextSetIndex = nextExercise.exercise.sets.firstIndex(where: { !$0.done }) {
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
        if let workout = workoutVM.activeWorkout{
            workout.exercises.first(where: { $0.id == exerciseEntry.id }).map({$0.sets.removeAll(where: { $0.id == set.id }) })
            
        }
    }
    
    func addSet(_ exerciseEntry: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.first(where: { $0.id == exerciseEntry.id })?.addEmptySet()
            
            
        }
        
    }
    
    func copyPreviousSetValue(exerciseEntry: ExerciceEntry, currentSetIndex: Int) {
        if (currentSetIndex > 0){
            exerciseEntry.sets[currentSetIndex].repetition = exerciseEntry.sets[currentSetIndex-1].repetition
            exerciseEntry.sets[currentSetIndex].weight = exerciseEntry.sets[currentSetIndex-1].weight

            
        }else{
            // y'a rien avant donc regarder last fois que exercice a été fait
            
        }
    }
    
    func addSetCopyLastSet(exerciseEntry: ExerciceEntry) {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(where: { $0.id == exerciseEntry.id }),
            let lastSet = exercise.sets.last
        else {
            return
        }

        let newSet = lastSet.copy()
        exercise.sets.append(newSet)
    }
    func AnimationOfNextSet(){
        
    }
    func switchStateDoneSet(
        _ selectedExercise: ExerciceEntry,
        _ selectedSet: ExerciseSet
    ) {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(
                where: { $0.id == selectedExercise.id }
            ),
            let set = exercise.sets.first(
                where: { $0.id == selectedSet.id }
            )
        else {
            return
        }

        set.done.toggle()
        
    }
    func getNextSet(in selectedExercise: ExerciceEntry) -> ExerciseSet?{
        guard let nextSet = selectedExercise.sets.first(where: { !$0.done }) else {
            return nil
        }
        return nextSet
    }
    
    func markNextSetDone(in selectedExercise: ExerciceEntry) {
        guard let nextSet = selectedExercise.sets.first(where: { !$0.done }) else {
            return
        }

        nextSet.done = true
    }
    
    func AnimationExerciceDone( selectedExercice : ExerciceEntry) -> Bool {
        for exerciceSet in selectedExercice.sets {
            if !exerciceSet.done {
                return false
            }
        }
        return true
            
        
    }
   
    
    func startTime() {
        timerTask?.cancel()

        let duration = restDuration
        let timerEndDate = Date.now.addingTimeInterval(duration)

        isTimerVisible = true
        timerPause = timerEndDate
        
        

        
        
        timerTask = Task {
            do {
                print("lancement de la pause")

                if let nextExercise = getNextExerciseToDo(),
                   let nextSetIndex = nextExercise.exercise.sets.firstIndex(where: { !$0.done }) {
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
                }
                if let nextExercice = getNextExerciseToDo(),
                   let nextSetIndex = nextExercice.exercise.sets.firstIndex(where: { !$0.done }) {
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

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTimerVisible = false
        timerPause = nil
    }

    
    func getNextSetTodo() -> ExerciseSet? {
        guard let activeWorkout = workoutVM.activeWorkout else {
            return nil
        }

        for exercise in activeWorkout.exercises {
            for set in exercise.sets{
                if !set.done{
                    return set
                }
            }
        }
        return nil
    }
    
    func removeExercise(_ exerciseEntry: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.removeAll { $0 === exerciseEntry }
        }
    }

}

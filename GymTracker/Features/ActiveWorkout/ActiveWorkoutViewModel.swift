import Foundation
import SwiftUI

@Observable
class ActiveWorkoutViewModel {
    let rawValue = UserDefaults.standard.string(forKey: "useMetric")
    var unitSystem: UnitSystem {
        UnitSystem(rawValue: rawValue ?? UnitSystem.metric.rawValue) ?? .metric
    }
    
    var workoutVM: WorkoutViewModel
    
    let duration: TimeInterval = 20
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
    }

    func removeSet(_ exerciseEntry: ExerciceEntry, _ set: ExerciseSet) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.first(where: { $0.id == exerciseEntry.id }).map({$0.sets.removeAll(where: { $0.id == set.id }) })
            
        }
    }
    
    func addSet(_ exerciseEntry: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.first(where: { $0.id == exerciseEntry.id })?.sets.append(ExerciseSet(usedMetric: unitSystem))
            
            
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
   
    
    func startTime() {
        timerTask?.cancel()

        isTimerVisible = true
        timerPause = Date.now.addingTimeInterval(duration)
        
        

        
        
        timerTask = Task {
            do {
                if let timerguard = timerPause {
                    
                        print("lancement de la pause")
                        await LiveActivityManager.shared.startPause(timerEndDate: timerguard)
                }
        
                try await Task.sleep(for: .seconds(duration))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    isTimerVisible = false
                    timerPause = nil
                }
                if let nextExercice = getNextExerciseToDo() {
                    print("Live ACtive Exercice Changement")
                    await LiveActivityManager.shared.updateExerciceAfterSet(
                        exercice: nextExercice.exercise.exercice.name,
                        rep: nextExercice.set.repetition.description,
                        numberSet: nextExercice.exercise.sets.count.description
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

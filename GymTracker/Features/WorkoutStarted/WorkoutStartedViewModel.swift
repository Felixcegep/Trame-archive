import Foundation
import SwiftUI

@Observable
class WorkoutStartedViewModel {
    var workoutVM: WorkoutViewModel
    
    let duration: TimeInterval = 20
    var timerEndDate: Date?
    var isTimerVisible : Bool = false
    var timerTask: Task<Void, Never>?

    
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

        let newExercice = ExerciceEntry(from : template)
        activeWorkout.exercises.append(newExercice)
    }

    func addExercice(exerciceTmp: ExerciceTemplate){
        addExercise(exerciceTmp)
    }
    func removeSet(_ exercice: ExerciceEntry, _ set: ExerciseSet) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.first(where: { $0.id == exercice.id }).map({$0.sets.removeAll(where: { $0.id == set.id }) })
            
        }
    }
    
    func addSet(_ exercice: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.first(where: { $0.id == exercice.id })?.sets.append(ExerciseSet())
            
        }
        
    }
    func addSetCopyLastSet(exercice: ExerciceEntry) {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(where: { $0.id == exercice.id }),
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
        timerEndDate = Date.now.addingTimeInterval(duration)
        
        

        
        
        timerTask = Task {
            do {
                if let timerguard = timerEndDate {
                    
                        print("lancement de la pause")
                        await LiveActivityManager.shared.startPause(timerEndDate: timerguard)
                }
        
                try await Task.sleep(for: .seconds(duration))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    isTimerVisible = false
                    timerEndDate = nil
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

    
    func getNextSetTodo() -> ExerciseSet?{
        
        for exercice in workoutVM.activeWorkout!.exercises{
            for set in exercice.sets{
                if !set.done{
                    return set
                }
            }
        }
        return nil
    }
    
    func removeExercice(_ exercice: ExerciceEntry) {
        if let workout = workoutVM.activeWorkout{
            workout.exercises.removeAll { $0 === exercice }
        }
    }

}

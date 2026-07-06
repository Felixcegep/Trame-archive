import Foundation
import SwiftUI

@Observable
class WorkoutStartedViewModel {
    var workoutVM: WorkoutViewModel

    init(workoutVM: WorkoutViewModel) {
        self.workoutVM = workoutVM
    }

    var activeWorkout: Workout? {
        workoutVM.activeWorkout
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

        let exerciseName = exercise.exercice.name
        let repetitions = set.repetition.description
        let setNumber = exercise.sets.count.description
        Task {
            await LiveActivityManager.shared.updateExerciceAfterSet(
                exercice: exerciseName,
                rep: repetitions,
                numberSet: setNumber
            )
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

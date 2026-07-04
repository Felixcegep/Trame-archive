//
//  WorkoutViewModel.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import CoreData
import Combine
import SwiftUI


@Observable
class WorkoutViewModel {
    
    var workoutList : [Workout] = []
    
    var exercicesTemplate : [ExerciceTemplate] = []
    
    var workout : Workout? = nil
    
    func StartNewWorkout(){
        self.workout = Workout(nom: nil)
    }
    
    func saveWorkout(workoutSaved : Workout){
        if self.workout != nil{
            workoutSaved.endTime = Date.now
            workoutList.append(workoutSaved)
            
            // enleve le workout encours de l'application
            
            self.workout = nil
        }
    }
    
    func addExercice(exerciceTmp: ExerciceTemplate){
        if let workout = self.workout{
            let newExercice = ExerciceEntry(from : exerciceTmp)
            workout.exercises.append(newExercice)
        }
    }
    func removeSet(_ exercice: ExerciceEntry, _ set: ExerciseSet) {
        if let workout = self.workout{
            workout.exercises.first(where: { $0.id == exercice.id }).map({$0.sets.removeAll(where: { $0.id == set.id }) })
            
        }
    }
    
    func addSet(_ exercice: ExerciceEntry) {
        if let workout = self.workout{
            workout.exercises.first(where: { $0.id == exercice.id })?.sets.append(ExerciseSet())
            
        }
        
    }
    
    func SwitchStateDoneSet(_ exercice: ExerciceEntry, _ set: ExerciseSet)
    {
        
        if let workout = self.workout{
            // trouve l'exercice rechercher
            // trouve le set rechercher et modifie la valeur
            workout.exercises.first(where: { $0.id == exercice.id })?.sets.first(where: { $0.id == set.id }).map {
                if ($0.done){
                    $0.done = false
                }else{
                    $0.done = true
                }
            }
        }
    }
    
    func removeExercice(_ exercice: ExerciceEntry) {
        if let workout = self.workout{
            workout.exercises.removeAll { $0 === exercice }
        }
    }
    
    func startWorkout(){
        self.workout = Workout(nom : nil)
    }
    
        func initialData() {
            let exerciceTemplate = ExerciceTemplate(name: "test", PrimaryMuscle: [Muscle.erectorSpinae])
            
            //exercices.append(ExerciceEntry(Comment : "jello", exercice: exerciceTemplate))
            
            exercicesTemplate = [
                ExerciceTemplate(
                    name: "Bench Press",
                    PrimaryMuscle: [.middleChest],
                    SecondaryMuscle: [.frontDeltoid, .tricepLongHead, .tricepLateralHead]
                ),

                ExerciceTemplate(
                    name: "Squat",
                    PrimaryMuscle: [.quadriceps, .gluteMaximus],
                    SecondaryMuscle: [.hamstrings, .adductors, .erectorSpinae]
                ),

                ExerciceTemplate(
                    name: "Deadlift",
                    PrimaryMuscle: [.erectorSpinae, .gluteMaximus, .hamstrings],
                    SecondaryMuscle: [.trapezius, .forearms, .quadriceps]
                ),

                ExerciceTemplate(
                    name: "Pull Up",
                    PrimaryMuscle: [.latissimusDorsi],
                    SecondaryMuscle: [.bicep, .brachialis, .rhomboids]
                ),

                ExerciceTemplate(
                    name: "Overhead Press",
                    PrimaryMuscle: [.frontDeltoid, .lateralDeltoid],
                    SecondaryMuscle: [.tricepLongHead, .trapezius]
                )
            ]
            
        }
    
}



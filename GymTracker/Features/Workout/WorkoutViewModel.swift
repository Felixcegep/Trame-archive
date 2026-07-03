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
    var exercices : [ExerciceEntry] = []
    var exercicesTemplate : [ExerciceTemplate] = []
    
    func addExercice(exerciceTmp: ExerciceTemplate){
        let newExercice = ExerciceEntry(from : exerciceTmp)
        exercices.append(newExercice)
    }
    func removeSet(_ exercice: ExerciceEntry, _ set: ExerciseSet) {
        exercice.sets.removeAll { $0 === set }
    }
    func addSet(_ exercice: ExerciceEntry) {
        exercice.sets.append(ExerciseSet())
    }
    func SwitchStateDoneSet(_ exercice: ExerciceEntry, _ set: ExerciseSet)
    {
        exercice.sets.map {
            if ($0 == set){
                if ($0.done){
                    $0.done = false
                }else{
                    $0.done = true
                }
            }
        }
    }
    
    func removeExercice(_ exercice: ExerciceEntry) {
        exercices.removeAll { $0 === exercice }
    }
    
    init(){
        self.initialData()
    }
    
        func initialData() {
            let exerciceTemplate = ExerciceTemplate(name: "test", PrimaryMuscle: [Muscle.erectorSpinae])
            
            exercices.append(ExerciceEntry(Comment : "jello", exercice: exerciceTemplate))
            
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



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
import SwiftData
@Observable
class WorkoutViewModel {
    
    
    
    var activeWorkout : Workout? = nil

    var hasActiveWorkout: Bool {
        activeWorkout != nil
    }
    
    func StartNewWorkout(){
        startWorkout()
    }
    
    func saveWorkout(using modelContext: ModelContext){
        
        if let activeWorkout = activeWorkout {
            
            activeWorkout.endTime = Date.now
            
            do {
                modelContext.insert(activeWorkout)
                try modelContext.save()
            }catch {
                return
            }
            
            
        }
        activeWorkout = nil
        
        
    }

    func startWorkout(){
        // creation d'un workout
        self.activeWorkout = Workout(nom : nil)
    }
    

    var workout: Workout? {
        get { activeWorkout }
        set { activeWorkout = newValue }
    }

    func initialData() {
        
        
        let exercicesTemplate = [
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

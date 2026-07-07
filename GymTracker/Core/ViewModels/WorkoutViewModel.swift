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
    let rawValue = UserDefaults.standard.string(forKey: "useMetric")
    var unitSystem: UnitSystem {
        UnitSystem(rawValue: rawValue ?? UnitSystem.metric.rawValue) ?? .metric
    }
    
    
    var activeWorkout : Workout? = nil
    var hasActiveWorkout: Bool {
        activeWorkout != nil
    }
    func removeWorkout(using modelContext: ModelContext, workout: Workout){
       do {
            modelContext.delete(workout)
           try modelContext.save()
       }catch{
           return
       }
        
    }

    func saveWorkout(using modelContext: ModelContext){
        if let activeWorkout = activeWorkout {
            activeWorkout.endTime = Date.now
            do {
                modelContext.insert(activeWorkout)
                try modelContext.save()
            } catch {
                print("Failed to save workout: \(error)")
            }
        }
        activeWorkout = nil
        Task {
            await LiveActivityManager.shared.end()
        }
    }

    func startWorkout(){
        // creation d'un workout
        let newWorkout = Workout(nom : nil)
        self.activeWorkout = newWorkout
        LiveActivityManager.shared.startWorkout(startTime: newWorkout.startTime)
    }
    func startWorkoutWithTemplate(Template : WorkoutTemplate)
    {
        let newWorkout = Workout(template: Template,unitSystem: unitSystem )
        self.activeWorkout = newWorkout
        LiveActivityManager.shared.startWorkout(startTime: newWorkout.startTime)
    }
    

    var workout: Workout? {
        get { activeWorkout }
        set { 
            activeWorkout = newValue 
            if newValue == nil {
                Task {
                    await LiveActivityManager.shared.end()
                }
            }
        }
    }
}

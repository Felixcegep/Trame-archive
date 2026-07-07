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
        let newWorkout = Workout(nom : nil)
        self.activeWorkout = newWorkout
        LiveActivityManager.shared.startWorkout(startTime: newWorkout.startTime)
    }
    func startWorkoutWithTemplate(Template : WorkoutTemplate)
    {
        let newWorkout = Workout(template: Template)
        self.activeWorkout = newWorkout
        LiveActivityManager.shared.startWorkout(startTime: newWorkout.startTime)
    }
    

    var workout: Workout? {
        get { activeWorkout }
        set { activeWorkout = newValue }
    }
}

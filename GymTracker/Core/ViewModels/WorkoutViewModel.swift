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

    @discardableResult
    func saveWorkout(using modelContext: ModelContext) -> Bool {
        guard let activeWorkout else {
            return false
        }

        // Do not carry added-but-never-started exercises into workout history.
        activeWorkout.exercises.removeAll { exercise in
            !exercise.sets.contains(where: \.done)
        }

        guard completedSetCount(in: activeWorkout) > 0 else { return false }

        activeWorkout.nom = normalized(activeWorkout.nom)
        activeWorkout.notes = normalized(activeWorkout.notes)

        activeWorkout.endTime = Date.now
        do {
            modelContext.insert(activeWorkout)
            try modelContext.save()
        } catch {
            print("Failed to save workout: \(error)")
            return false
        }

        self.activeWorkout = nil
        Task {
            await LiveActivityManager.shared.end()
        }
        return true
    }

    func discardActiveWorkout() {
        workout = nil
    }

    func startWorkout(){
        // creation d'un workout
        let newWorkout = Workout(nom : nil)
        self.activeWorkout = newWorkout
        LiveActivityManager.shared.startWorkout(startTime: newWorkout.startTime)
    }
    func startWorkout(with template: WorkoutTemplate) {
        let newWorkout = Workout(template: template, unitSystem: unitSystem)
        self.activeWorkout = newWorkout
        LiveActivityManager.shared.startWorkout(startTime: newWorkout.startTime)
    }

    private func completedSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
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

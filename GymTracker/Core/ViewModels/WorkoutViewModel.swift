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
    var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
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

    func saveWorkout(using modelContext: ModelContext) -> Bool {
        guard let activeWorkout else {
            return false
        }

        // Do not carry added-but-never-started exercises into workout history.
        activeWorkout.exercises.removeAll { exercise in
            !exercise.sets.contains(where: \.done)
        }

        guard activeWorkout.completedSetCount > 0 else { return false }

        activeWorkout.nom = normalized(activeWorkout.nom)
        activeWorkout.notes = normalized(activeWorkout.notes)

        activeWorkout.normalizeExerciseOrder()
        activeWorkout.status = .completed
        activeWorkout.endTime = Date.now
        do {
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

    func discardActiveWorkout(using modelContext: ModelContext) {
        guard let activeWorkout else { return }

        modelContext.delete(activeWorkout)
        do {
            try modelContext.save()
            workout = nil
        } catch {
            print("Failed to discard active workout: \(error)")
        }
    }

    @discardableResult
    func startWorkout(using modelContext: ModelContext) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        let newWorkout = Workout(nom : nil)
        return persistAndActivate(newWorkout, using: modelContext)
    }

    @discardableResult
    func startWorkout(with template: WorkoutTemplate, using modelContext: ModelContext) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        let newWorkout = Workout(template: template, unitSystem: unitSystem)
        return persistAndActivate(newWorkout, using: modelContext)
    }

    @discardableResult
    func restoreActiveWorkout(using modelContext: ModelContext) -> Bool {
        do {
            let workouts = try modelContext.fetch(FetchDescriptor<Workout>())
            let activeWorkouts = workouts
                .filter { $0.status == .active }
                .sorted { $0.startTime > $1.startTime }

            guard let activeWorkout = activeWorkouts.first else {
                self.activeWorkout = nil
                return false
            }

            self.activeWorkout = activeWorkout
            LiveActivityManager.shared.startWorkout(startTime: activeWorkout.startTime)
            return true
        } catch {
            print("Failed to restore active workout: \(error)")
            return false
        }
    }

    private func persistAndActivate(_ workout: Workout, using modelContext: ModelContext) -> Bool {
        modelContext.insert(workout)
        do {
            try modelContext.save()
            activeWorkout = workout
            LiveActivityManager.shared.startWorkout(startTime: workout.startTime)
            return true
        } catch {
            print("Failed to start workout: \(error)")
            return false
        }
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

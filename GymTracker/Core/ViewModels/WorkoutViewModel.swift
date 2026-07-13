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

        // Incomplete work is intentionally excluded from historical truth. Removing
        // a SwiftData relationship alone does not delete its model, so explicitly
        // delete each child as well.
        for exercise in activeWorkout.exercises {
            let incompleteSets = exercise.sets.filter { !$0.done }
            exercise.sets.removeAll { !$0.done }
            for set in incompleteSets {
                modelContext.delete(set)
            }
            exercise.normalizeSetOrder()
        }

        // Do not carry added-but-never-started exercises into workout history.
        let emptyExercises = activeWorkout.exercises.filter { $0.sets.isEmpty }
        activeWorkout.exercises.removeAll { exercise in
            emptyExercises.contains { $0.persistentModelID == exercise.persistentModelID }
        }
        for exercise in emptyExercises {
            modelContext.delete(exercise)
        }

        guard activeWorkout.completedSetCount > 0 else { return false }

        activeWorkout.nom = normalized(activeWorkout.nom)
        activeWorkout.notes = normalized(activeWorkout.notes)

        activeWorkout.normalizeExerciseOrder()
        activeWorkout.status = .completed
        activeWorkout.endTime = Date.now
        activeWorkout.restEndDate = nil
        completePlannedWorkoutIfNeeded(activeWorkout, using: modelContext)
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

        restorePlannedWorkoutAvailabilityIfNeeded(activeWorkout, using: modelContext)
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
    func startWorkout(
        from plannedWorkout: PlannedWorkout,
        progress: PlanWorkoutProgress,
        in planRun: PlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }
        guard progress.status == .available || progress.status == .upcoming else { return false }

        let newWorkout = Workout(plannedWorkout: plannedWorkout, planRun: planRun, unitSystem: unitSystem)
        progress.status = .inProgress
        progress.startedAt = .now
        planRun.updatedAt = .now

        guard persistAndActivate(newWorkout, using: modelContext) else {
            PlanCoordinator.restoreAvailability(progress, in: planRun)
            return false
        }
        return true
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

    private func completePlannedWorkoutIfNeeded(_ workout: Workout, using modelContext: ModelContext) {
        guard
            let runID = workout.sourcePlanRunID,
            let plannedWorkoutID = workout.sourcePlannedWorkoutID,
            let run = planRun(id: runID, using: modelContext),
            let progress = run.workoutProgress.first(where: { $0.plannedWorkoutID == plannedWorkoutID })
        else {
            return
        }

        PlanCoordinator.markCompleted(progress, with: workout, in: run)
    }

    private func restorePlannedWorkoutAvailabilityIfNeeded(_ workout: Workout, using modelContext: ModelContext) {
        guard
            let runID = workout.sourcePlanRunID,
            let plannedWorkoutID = workout.sourcePlannedWorkoutID,
            let run = planRun(id: runID, using: modelContext),
            let progress = run.workoutProgress.first(where: { $0.plannedWorkoutID == plannedWorkoutID })
        else {
            return
        }

        PlanCoordinator.restoreAvailability(progress, in: run)
    }

    private func planRun(id: UUID, using modelContext: ModelContext) -> PlanRun? {
        do {
            return try modelContext.fetch(FetchDescriptor<PlanRun>()).first { $0.id == id }
        } catch {
            print("Failed to find plan run: \(error)")
            return nil
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

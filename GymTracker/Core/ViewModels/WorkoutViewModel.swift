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

        // Validate before pruning incomplete sets or empty exercises. An invalid
        // save must leave the active draft untouched so the user can complete it.
        guard activeWorkout.completedSetCount > 0 else {
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
        // An empty component entry in an execution block is different: keeping
        // it preserves the intended circuit/complex membership when the
        // lifter saves a partial block.
        let emptyExercises = activeWorkout.exercises.filter {
            $0.sets.isEmpty && $0.executionBlockID == nil
        }
        activeWorkout.exercises.removeAll { exercise in
            emptyExercises.contains { $0.persistentModelID == exercise.persistentModelID }
        }
        for exercise in emptyExercises {
            modelContext.delete(exercise)
        }

        for block in activeWorkout.orderedExecutionBlocks {
            if WorkoutExecutionBlockService.entries(in: block, workout: activeWorkout).isEmpty {
                activeWorkout.executionBlocks.removeAll { $0 === block }
                modelContext.delete(block)
            } else {
                WorkoutExecutionBlockService.finalizeForWorkoutSave(block)
            }
        }

        activeWorkout.name = normalized(activeWorkout.name)
        activeWorkout.notes = normalized(activeWorkout.notes)

        activeWorkout.normalizeExerciseOrder()
        activeWorkout.status = .completed
        activeWorkout.endTime = Date.now
        activeWorkout.restEndDate = nil
        completePlannedWorkoutIfNeeded(activeWorkout, using: modelContext)
        do {
            try modelContext.save()
        } catch {
            // The active workout remains recoverable after a persistence failure.
            // SwiftData's rollback also undoes planned-run advancement and child
            // pruning performed above.
            modelContext.rollback()
            print("Failed to save workout: \(error)")
            return false
        }

        self.activeWorkout = nil
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
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
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch {
            modelContext.rollback()
            self.activeWorkout = try? modelContext.fetch(FetchDescriptor<Workout>())
                .first { $0.status == .active }
            print("Failed to discard active workout: \(error)")
        }
    }

    @discardableResult
    func startWorkout(using modelContext: ModelContext) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        let newWorkout = Workout(name : nil)
        return persistAndActivate(newWorkout, using: modelContext)
    }

    @discardableResult
    func startWorkout(with template: WorkoutTemplate, using modelContext: ModelContext) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        let newWorkout = Workout(template: template, unitSystem: unitSystem)
        ProgressionSnapshotService(modelContext: modelContext)
            .applyRecommendations(to: newWorkout, from: template)
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
        _ = PlanProgressionTransitionService.applyDuePendingTransitions(in: planRun)
        guard planRun.status == .active else { return false }
        guard progress.status == .available || progress.status == .upcoming else { return false }

        let newWorkout = Workout(plannedWorkout: plannedWorkout, planRun: planRun, unitSystem: unitSystem)
        // Universal program prescriptions (waves, formulas, reference loads,
        // conditioning targets, and role metadata) must be resolved before
        // the workout is persisted. The resulting values are immutable
        // snapshot evidence; later plan edits cannot reinterpret this session.
        for plannedExercise in plannedWorkout.orderedPlannedExercises {
            guard let entry = newWorkout.orderedExercises.first(where: {
                $0.sourcePlannedExerciseID == plannedExercise.id
            }) else { continue }
            ProgramPrescriptionSnapshotService.apply(
                to: entry,
                plannedExercise: plannedExercise,
                run: planRun,
                unitSystem: unitSystem
            )
            // Apply phase-level deload reductions after universal resolution so
            // the deload remains the final future-only prescription snapshot.
            PlanDeloadService.apply(to: entry, for: plannedWorkout.week?.block)
        }
        ProgressionSnapshotService(modelContext: modelContext)
            .applyRecommendations(to: newWorkout)
        progress.status = .inProgress
        progress.startedAt = .now
        planRun.updatedAt = .now

        guard persistAndActivate(newWorkout, using: modelContext) else {
            PlanCoordinator.restoreAvailability(progress, in: planRun)
            return false
        }
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
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
                Task { await LiveActivityManager.shared.endOrphanedActivities() }
                return false
            }

            self.activeWorkout = activeWorkout
            reconcileLiveActivity()
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
            reconcileLiveActivity()
            return true
        } catch {
            modelContext.rollback()
            print("Failed to start workout: \(error)")
            return false
        }
    }

    func reconcileLiveActivity() {
        guard let workout = activeWorkout else {
            Task { await LiveActivityManager.shared.endOrphanedActivities() }
            return
        }
        let projection = LiveActivityProjection(workout: workout)

        Task {
            await LiveActivityManager.shared.reconcile(projection)
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

        var progressionResults: [PlanExerciseProgressionResult] = []
        do {
            progressionResults = try PlanProgressionEvaluationService.evaluateAndApply(workout: workout, run: run, modelContext: modelContext)
        } catch {
            // A malformed optional rule must not prevent the performed workout
            // from being saved. The immutable snapshot remains authoritative;
            // the next plan occurrence can be repaired or manually advanced.
            print("Failed to evaluate program progression: \(error)")
        }
        PlanCoordinator.markCompleted(progress, with: workout, in: run)
        _ = PlanProgressionTransitionService.applyAutomaticTransitions(
            progressionResults,
            sourceProgress: progress,
            in: run
        )
        _ = PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: progress,
            in: run
        )
        // Availability now points at the next occurrence (or completes the
        // run), which is the authoritative cadence boundary for deferred
        // automatic progression.
        _ = PlanProgressionCadenceService.applyDueStates(in: run)
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

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
        modelContext.delete(workout)
        _ = modelContext.saveOrRollback()
    }

    /// What the most recent successful save actually wrote.
    ///
    /// `saveWorkout` still answers `Bool` because that is what every caller and
    /// every existing test asserts on. The counts a save confirmation needs
    /// cannot be recomputed afterwards — the graph has been pruned and
    /// `activeWorkout` cleared — so they are recorded here instead of changing
    /// that signature.
    private(set) var lastSavedSummary: CompletedWorkoutSummary?

    func saveWorkout(using modelContext: ModelContext) -> PersistenceOutcome {
        lastSavedSummary = nil

        guard let activeWorkout else {
            return .failed(NSError(domain: "GymTracker", code: 404, userInfo: [NSLocalizedDescriptionKey: String(localized: "No active workout found.")]))
        }

        // Pruning and finalization live in one described step so what a save
        // removed can be asserted directly. A nil result means the workout had
        // no completed set and the graph was left untouched.
        guard let summary = CompletedWorkoutPreparationService.prepare(
            activeWorkout,
            using: modelContext
        ) else {
            return .failed(NSError(domain: "GymTracker", code: 400, userInfo: [NSLocalizedDescriptionKey: String(localized: "Workout has no completed sets.")]))
        }

        completePlannedWorkoutIfNeeded(activeWorkout, using: modelContext)
        do {
            try completeRepeatingPlanOccurrenceIfNeeded(activeWorkout, using: modelContext)
        } catch {
            modelContext.rollback()
            return .failed(error)
        }
        let outcome = modelContext.saveOrRollbackReportingFailure()
        if outcome.didSave == false {
            // The active workout remains recoverable after a persistence failure.
            // SwiftData's rollback also undoes planned-run advancement and child
            // pruning performed above.
            return outcome
        }

        self.activeWorkout = nil
        // Recorded only once persistence has actually succeeded, so a
        // confirmation can never report a save that did not happen.
        lastSavedSummary = summary
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        Task {
            await LiveActivityManager.shared.end()
        }
        return .saved
    }

    func discardActiveWorkout(using modelContext: ModelContext) {
        guard let activeWorkout else { return }

        restorePlannedWorkoutAvailabilityIfNeeded(activeWorkout, using: modelContext)
        do {
            if let discardedOccurrence = try discardRepeatingPlanOccurrenceIfNeeded(
                activeWorkout,
                using: modelContext
            ) {
                modelContext.delete(discardedOccurrence)
            }
        } catch {
            modelContext.rollback()
            self.activeWorkout = try? modelContext.fetch(FetchDescriptor<Workout>())
                .first { $0.status == .active }
            return
        }
        modelContext.delete(activeWorkout)
        if modelContext.saveOrRollback() {
            workout = nil
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } else {
            self.activeWorkout = try? modelContext.fetch(FetchDescriptor<Workout>())
                .first { $0.status == .active }
        }
    }

    @discardableResult
    func startWorkout(using modelContext: ModelContext) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        let newWorkout = Workout(name : nil)
        return persistAndActivate(newWorkout, using: modelContext).didSave
    }

    @discardableResult
    func startWorkout(with template: WorkoutTemplate, using modelContext: ModelContext) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        let newWorkout = Workout(template: template, unitSystem: unitSystem)
        ProgressionSnapshotService(modelContext: modelContext)
            .applyRecommendations(to: newWorkout, from: template)
        return persistAndActivate(newWorkout, using: modelContext).didSave
    }

    @discardableResult
    func startWorkout(
        from repeatingPlanRun: RepeatingPlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        startWorkout(
            from: repeatingPlanRun,
            command: .expected,
            using: modelContext
        )
    }

    @discardableResult
    func startWorkout(
        from repeatingPlanRun: RepeatingPlanRun,
        command: RepeatingPlanWorkoutStartCommand,
        using modelContext: ModelContext
    ) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }

        do {
            let staged = try RepeatingPlanCoordinator.start(
                command,
                in: repeatingPlanRun
            )
            let newWorkout = Workout(template: staged.template, unitSystem: unitSystem)
            ProgressionSnapshotService(modelContext: modelContext)
                .applyRecommendations(to: newWorkout, from: staged.template)
            newWorkout.sourceRepeatingPlanID = repeatingPlanRun.sourcePlanID
            newWorkout.sourceRepeatingPlanRunID = repeatingPlanRun.id
            newWorkout.sourceRepeatingPlanOccurrenceID = staged.occurrence.id
            newWorkout.sourceRepeatingPlanName = repeatingPlanRun.sourcePlanName

            modelContext.insert(staged.occurrence)
            modelContext.insert(newWorkout)
            guard modelContext.saveOrRollback() else {
                return false
            }
            activeWorkout = newWorkout
            reconcileLiveActivity()
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    @discardableResult
    func undoLastRepeatingPlanAdvancement(
        in run: RepeatingPlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        do {
            let hasActiveWorkout = try modelContext.fetch(FetchDescriptor<Workout>())
                .contains { $0.status == .active }
            guard !hasActiveWorkout else { return false }

            _ = try RepeatingPlanCoordinator.undoLastAdvancement(in: run)
            guard modelContext.saveOrRollback() else { return false }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    @discardableResult
    func startWorkout(
        for plannedWorkout: PlannedWorkout,
        in planRun: PlanRun,
        progress: PlanWorkoutProgress,
        using modelContext: ModelContext
    ) -> Bool {
        guard !restoreActiveWorkout(using: modelContext) else { return false }
        _ = PlanProgressionTransitionService.applyDuePendingTransitions(in: planRun)
        guard planRun.status == .active else { return false }
        guard progress.status == .available || progress.status == .upcoming else { return false }

        let newWorkout = Workout(plannedWorkout: plannedWorkout, planRun: planRun, unitSystem: unitSystem)
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
            PlanDeloadService.apply(to: entry, for: plannedWorkout.week?.block)
        }
        ProgressionSnapshotService(modelContext: modelContext)
            .applyRecommendations(to: newWorkout)
        progress.status = .inProgress
        progress.startedAt = .now
        planRun.updatedAt = .now

        guard persistAndActivate(newWorkout, using: modelContext).didSave else {
            PlanCoordinator.restoreAvailability(progress, in: planRun)
            return false
        }
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        return true
    }

    /// Binds the persisted active workout, if there is one.
    ///
    /// - Returns: `true` only when a restorable active workout was found and is
    ///   now bound to `activeWorkout`. `false` means there was nothing to
    ///   restore, or the read failed.
    ///
    /// This deliberately does **not** return `PersistenceOutcome`. The method
    /// performs a fetch and never calls `save()`, so "did the save succeed" is
    /// not a question it can answer — and answering it anyway inverted every
    /// caller's guard, because a store with no active workout still counted as
    /// a successful persistence operation.
    @discardableResult
    func restoreActiveWorkout(using modelContext: ModelContext) -> Bool {
        do {
            let workouts = try modelContext.fetch(FetchDescriptor<Workout>())
            let activeWorkouts = workouts
                .filter { $0.status == .active }
                .sorted { $0.startTime > $1.startTime }

            guard let activeWorkout = activeWorkouts.first(where: {
                isRestorableActiveWorkout($0, using: modelContext)
            }) else {
                self.activeWorkout = nil
                Task { await LiveActivityManager.shared.endOrphanedActivities() }
                return true
            }

            self.activeWorkout = activeWorkout
            reconcileLiveActivity()
            return true
        } catch {
            print("Failed to restore active workout: \(error)")
            return false
        }
    }

    @discardableResult
    func handleExternalWorkoutChange(workoutID: UUID, using modelContext: ModelContext) -> Bool {
        let freshContext = ModelContext(modelContext.container)
        guard let freshWorkout = (try? freshContext.fetch(FetchDescriptor<Workout>()))?
            .first(where: { $0.id == workoutID && $0.status == .active })
        else {
            if activeWorkout?.id == workoutID {
                activeWorkout = nil
                Task { await LiveActivityManager.shared.endOrphanedActivities() }
            }
            return false
        }

        guard let boundWorkout = activeWorkout, boundWorkout.id == workoutID else {
            return restoreActiveWorkout(using: modelContext)
        }

        boundWorkout.restEndDate = freshWorkout.restEndDate
        boundWorkout.pausedRemainingTime = freshWorkout.pausedRemainingTime

        let freshSetsByID = Dictionary(
            uniqueKeysWithValues: freshWorkout.exercises.flatMap { entry in entry.sets.map { ($0.id, $0) } }
        )
        for entry in boundWorkout.exercises {
            for set in entry.sets {
                guard let freshSet = freshSetsByID[set.id] else { continue }
                set.done = freshSet.done
                set.repetitions = freshSet.repetitions
                set.weight = freshSet.weight
                set.rpe = freshSet.rpe
                set.rir = freshSet.rir
            }
        }

        // Idempotent by design (see `LiveActivityManager`'s doc comment), so
        // reconciling again here even when the command layer already did is
        // a harmless no-op rather than a duplicate mutation.
        reconcileLiveActivity()
        return true
    }

    private func persistAndActivate(_ workout: Workout, using modelContext: ModelContext) -> PersistenceOutcome {
        modelContext.insert(workout)
        let outcome = modelContext.saveOrRollbackReportingFailure()
        if outcome.didSave {
            activeWorkout = workout
            reconcileLiveActivity()
        }
        return outcome
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

    private func completeRepeatingPlanOccurrenceIfNeeded(
        _ workout: Workout,
        using modelContext: ModelContext
    ) throws {
        let hasRepeatingIdentity = workout.sourceRepeatingPlanID != nil
            || workout.sourceRepeatingPlanRunID != nil
            || workout.sourceRepeatingPlanOccurrenceID != nil
            || workout.sourceRepeatingPlanName != nil
        guard hasRepeatingIdentity else { return }
        guard
            let planID = workout.sourceRepeatingPlanID,
            let runID = workout.sourceRepeatingPlanRunID,
            let occurrenceID = workout.sourceRepeatingPlanOccurrenceID,
            let run = repeatingPlanRun(id: runID, using: modelContext),
            run.sourcePlanID == planID,
            let occurrence = run.occurrences.first(where: { $0.id == occurrenceID })
        else {
            throw RepeatingPlanCoordinatorError.occurrenceNotInRun
        }

        _ = try RepeatingPlanCoordinator.complete(
            occurrence,
            with: workout,
            in: run
        )
    }

    private func discardRepeatingPlanOccurrenceIfNeeded(
        _ workout: Workout,
        using modelContext: ModelContext
    ) throws -> RepeatingPlanOccurrence? {
        let hasRepeatingIdentity = workout.sourceRepeatingPlanID != nil
            || workout.sourceRepeatingPlanRunID != nil
            || workout.sourceRepeatingPlanOccurrenceID != nil
            || workout.sourceRepeatingPlanName != nil
        guard hasRepeatingIdentity else { return nil }
        guard
            let planID = workout.sourceRepeatingPlanID,
            let runID = workout.sourceRepeatingPlanRunID,
            let occurrenceID = workout.sourceRepeatingPlanOccurrenceID,
            let run = repeatingPlanRun(id: runID, using: modelContext),
            run.sourcePlanID == planID,
            let occurrence = run.occurrences.first(where: { $0.id == occurrenceID })
        else {
            throw RepeatingPlanCoordinatorError.occurrenceNotInRun
        }
        return try RepeatingPlanCoordinator.discard(occurrence, in: run)
    }

    private func isRestorableActiveWorkout(
        _ workout: Workout,
        using modelContext: ModelContext
    ) -> Bool {
        let hasRepeatingIdentity = workout.sourceRepeatingPlanID != nil
            || workout.sourceRepeatingPlanRunID != nil
            || workout.sourceRepeatingPlanOccurrenceID != nil
            || workout.sourceRepeatingPlanName != nil
        guard hasRepeatingIdentity else { return true }
        guard
            let planID = workout.sourceRepeatingPlanID,
            let runID = workout.sourceRepeatingPlanRunID,
            let occurrenceID = workout.sourceRepeatingPlanOccurrenceID,
            let run = repeatingPlanRun(id: runID, using: modelContext),
            run.sourcePlanID == planID,
            let occurrence = run.occurrences.first(where: { $0.id == occurrenceID })
        else {
            return false
        }
        return occurrence.status == .inProgress
    }

    private func planRun(id: UUID, using modelContext: ModelContext) -> PlanRun? {
        do {
            return try modelContext.fetch(FetchDescriptor<PlanRun>()).first { $0.id == id }
        } catch {
            print("Failed to find plan run: \(error)")
            return nil
        }
    }

    private func repeatingPlanRun(
        id: UUID,
        using modelContext: ModelContext
    ) -> RepeatingPlanRun? {
        do {
            return try modelContext.fetch(FetchDescriptor<RepeatingPlanRun>())
                .first { $0.id == id }
        } catch {
            print("Failed to find repeating plan run: \(error)")
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

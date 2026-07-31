import Foundation
import SwiftData

/// Today can follow one training plan or one rotation, never both. Every action
/// that would create a second guided source raises one of these instead of
/// silently picking a winner.
enum GuidedSourceConflictRequest {
    case chooseFromToday
    case workoutStart(WorkoutPreparationRequest)
    case activate(RepeatingPlan)
    case resume(RepeatingPlanRun)
    case fixedPlan(FixedPlanAction)
}

enum FixedPlanAction {
    case start(WorkoutPlan, Date)
    case resume(PlanRun)
    case startTestDay(PlanRun)

    /// The run this action is about, which must survive when the others are
    /// paused to make room for it.
    var retainedRunID: UUID? {
        switch self {
        case .start:
            nil
        case .resume(let run), .startTestDay(let run):
            run.id
        }
    }
}

enum GuidedSourceResolutionError: Error {
    case missingSource
}

/// What a plan or rotation action did, as a value the caller renders rather
/// than a set of view fields the action reaches into. `succeededSilently`
/// exists because the conflict-resolution paths deliberately commit without a
/// Today confirmation: the user already saw a dialog describing the change.
enum PlanActionOutcome {
    case succeeded(confirmation: String)
    case succeededSilently
    case failed(message: String)
    case needsConflictResolution(GuidedSourceConflictRequest)
}

/// Every write to plan and rotation run state. `RootView` owned all of it and
/// reported failure by assigning to its own error field, which meant none of it
/// could be exercised without a view.
///
/// Each function commits or rolls back before returning, and posts
/// `.planScheduleDidChange` on any commit — so a caller cannot forget to, and
/// two callers cannot disagree about when it fires.
@MainActor
enum PlanLifecycleService {
    // MARK: - Reading the current sources

    /// Sorted most-recently-updated first, with an id tiebreak so the order is
    /// stable across launches rather than whatever the store returns.
    static func activeFixedRuns(using context: ModelContext) -> [PlanRun] {
        ((try? context.fetch(FetchDescriptor<PlanRun>())) ?? [])
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    static func activeRepeatingRuns(using context: ModelContext) -> [RepeatingPlanRun] {
        ((try? context.fetch(FetchDescriptor<RepeatingPlanRun>())) ?? [])
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    // MARK: - Rotation lifecycle

    static func activate(_ plan: RepeatingPlan, using context: ModelContext) -> PlanActionOutcome {
        do {
            let run = try RepeatingPlanCoordinator.activate(
                plan,
                fixedPlanRuns: activeFixedRuns(using: context),
                repeatingPlanRuns: activeRepeatingRuns(using: context)
            )
            context.insert(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be activated. Try again.")
            }
            return committed(String(localized: "Rotation activated."))
        } catch RepeatingPlanCoordinatorError.activationConflict {
            return .needsConflictResolution(.activate(plan))
        } catch {
            return .failed(message: "The rotation is unavailable. Check its workouts and try again.")
        }
    }

    static func pause(_ run: RepeatingPlanRun, using context: ModelContext) -> PlanActionOutcome {
        do {
            try RepeatingPlanCoordinator.pause(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be paused. Try again.")
            }
            return committed(String(localized: "Rotation paused."))
        } catch {
            return .failed(message: "Only an active rotation can be paused.")
        }
    }

    static func resume(_ run: RepeatingPlanRun, using context: ModelContext) -> PlanActionOutcome {
        let conflicts = RepeatingPlanCoordinator.guidedSourceConflicts(
            fixedPlanRuns: activeFixedRuns(using: context),
            repeatingPlanRuns: activeRepeatingRuns(using: context).filter { $0.id != run.id }
        )
        guard conflicts.isEmpty else {
            return .needsConflictResolution(.resume(run))
        }
        do {
            try RepeatingPlanCoordinator.resume(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be resumed. Try again.")
            }
            return committed(String(localized: "Rotation resumed."))
        } catch {
            context.rollback()
            return .failed(message: "Only a paused rotation can be resumed.")
        }
    }

    static func skipNextWorkout(in run: RepeatingPlanRun, using context: ModelContext) -> PlanActionOutcome {
        do {
            let occurrence = try RepeatingPlanCoordinator.skip(in: run)
            context.insert(occurrence)
            guard context.saveOrRollback() else {
                return .failed(message: "The workout could not be skipped. Try again.")
            }
            return committed(String(localized: "Rotation workout skipped."))
        } catch RepeatingPlanCoordinatorError.runHasActiveOccurrence {
            context.rollback()
            return .failed(message: "Finish or discard the active rotation workout before skipping the next one.")
        } catch {
            context.rollback()
            return .failed(message: "The workout could not be skipped. Check the rotation and try again.")
        }
    }

    static func restart(_ run: RepeatingPlanRun, using context: ModelContext) -> PlanActionOutcome {
        do {
            try RepeatingPlanCoordinator.restart(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be restarted. Try again.")
            }
            return committed(String(localized: "Rotation restarted."))
        } catch RepeatingPlanCoordinatorError.runHasActiveOccurrence {
            context.rollback()
            return .failed(message: "Finish or discard the active rotation workout before restarting the rotation.")
        } catch {
            context.rollback()
            return .failed(message: "The rotation could not be restarted. Check its workouts and try again.")
        }
    }

    static func end(_ run: RepeatingPlanRun, using context: ModelContext) -> PlanActionOutcome {
        do {
            try RepeatingPlanCoordinator.end(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be ended. Try again.")
            }
            return committed(String(localized: "Rotation ended."))
        } catch RepeatingPlanCoordinatorError.runHasActiveOccurrence {
            context.rollback()
            return .failed(message: "Finish or discard the active rotation workout before ending the rotation.")
        } catch {
            context.rollback()
            return .failed(message: "The rotation could not be ended. Try again.")
        }
    }

    // MARK: - Fixed plan lifecycle

    /// A test day is the one fixed-plan action that does not finish on its own:
    /// it activates a planned workout the caller must then start, which is why
    /// this reports the workout rather than starting it here. Starting a
    /// workout is presentation — it can raise a conflict dialog and a warm-up
    /// prompt — and does not belong behind a data call.
    struct FixedPlanOutcome {
        var confirmation: String?
        var plannedWorkoutToStart: PendingPlannedWorkout?
        var errorMessage: String?

        var didCommit: Bool { errorMessage == nil }
    }

    static func perform(_ action: FixedPlanAction, using context: ModelContext) -> FixedPlanOutcome {
        var outcome = FixedPlanOutcome()
        switch action {
        case .start(let plan, let startDate):
            let started: PlanRun?
            if let completedRun = plan.runs
                .filter({ $0.status == .completed || $0.status == .archived })
                .sorted(by: { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) })
                .first,
               case .offerRestart(let carryState) = plan.programCompletionPolicy {
                started = ProgramRunLifecycleService.restartRun(
                    for: plan,
                    from: completedRun,
                    startDate: startDate,
                    carryState: carryState,
                    using: context
                )
            } else {
                started = PlanCoordinator.startRun(for: plan, startDate: startDate, using: context)
            }
            guard started != nil else {
                outcome.errorMessage = "The plan could not be started. Check its workouts and try again."
                return outcome
            }
        case .resume(let run):
            guard PlanCoordinator.resume(run, using: context) else {
                outcome.errorMessage = "The plan could not be resumed. Try again."
                return outcome
            }
            outcome.confirmation = String(localized: "Plan resumed.")
        case .startTestDay(let run):
            guard let progress = ProgramRunLifecycleService.activateTestDay(for: run, using: context) else {
                outcome.errorMessage = "The test day could not be started. Try again."
                return outcome
            }
            guard let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: run) else {
                outcome.errorMessage = "The test day could not be started. Try again."
                return outcome
            }
            outcome.plannedWorkoutToStart = PendingPlannedWorkout(
                planRun: run,
                progress: progress,
                plannedWorkout: plannedWorkout
            )
        }
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        return outcome
    }

    // MARK: - Resolving a guided-source conflict

    /// Pauses whatever else is running, then activates. Unlike `activate`,
    /// this commits without a confirmation: the user answered a dialog that
    /// already described the change.
    static func resolveConflictAndActivate(_ plan: RepeatingPlan, using context: ModelContext) -> PlanActionOutcome {
        do {
            stagePauseFixedRuns(using: context)
            try stagePauseRepeatingRuns(using: context)
            let run = try RepeatingPlanCoordinator.activate(plan)
            context.insert(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be activated. Try again.")
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return .succeededSilently
        } catch {
            context.rollback()
            return .failed(message: "The rotation could not be activated. Check its workouts and try again.")
        }
    }

    static func resolveConflictAndResume(_ run: RepeatingPlanRun, using context: ModelContext) -> PlanActionOutcome {
        do {
            stagePauseFixedRuns(using: context)
            try stagePauseRepeatingRuns(except: run.id, using: context)
            try RepeatingPlanCoordinator.resume(run)
            guard context.saveOrRollback() else {
                return .failed(message: "The rotation could not be resumed. Try again.")
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return .succeededSilently
        } catch {
            context.rollback()
            return .failed(message: "The rotation could not be resumed. Try again.")
        }
    }

    /// Today's own "which source?" answer. Requires exactly one candidate of
    /// the chosen kind: with none or several there is nothing unambiguous to
    /// keep, and guessing would pause the wrong plan.
    static func resolveTodaySource(preferRepeating: Bool, using context: ModelContext) -> PlanActionOutcome {
        do {
            if preferRepeating {
                let repeatingRuns = activeRepeatingRuns(using: context)
                guard repeatingRuns.count == 1, let retained = repeatingRuns.first else {
                    throw GuidedSourceResolutionError.missingSource
                }
                stagePauseFixedRuns(using: context)
                try stagePauseRepeatingRuns(except: retained.id, using: context)
            } else {
                let fixedRuns = activeFixedRuns(using: context)
                guard fixedRuns.count == 1, let retained = fixedRuns.first else {
                    throw GuidedSourceResolutionError.missingSource
                }
                stagePauseFixedRuns(except: retained.id, using: context)
                try stagePauseRepeatingRuns(using: context)
            }
            guard context.saveOrRollback() else {
                return .failed(message: "The training source could not be changed. Try again.")
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return .succeededSilently
        } catch {
            context.rollback()
            return .failed(message: "The training source could not be changed. Try again.")
        }
    }

    // MARK: - Staging

    /// Stages pauses without saving. The caller commits, so a conflict
    /// resolution that fails partway leaves nothing paused rather than pausing
    /// the old source and failing to start the new one.
    static func stagePauseFixedRuns(except retainedRunID: UUID? = nil, using context: ModelContext) {
        for run in activeFixedRuns(using: context) where run.id != retainedRunID {
            PlanCoordinator.pause(run)
        }
    }

    static func stagePauseRepeatingRuns(except retainedRunID: UUID? = nil, using context: ModelContext) throws {
        for run in activeRepeatingRuns(using: context) where run.id != retainedRunID {
            try RepeatingPlanCoordinator.pause(run)
        }
    }

    private static func committed(_ confirmation: String) -> PlanActionOutcome {
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        return .succeeded(confirmation: confirmation)
    }
}

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ActiveSessionRouter {
    var activeWorkoutPath: [ActiveWorkoutRoute] = []
    var isShowingActiveWorkout = false
    var shouldDiscardActiveWorkout = false
    var isShowingActiveWorkoutConflictAlert = false
    var pendingWorkoutStart: PendingWorkoutStart?
    var workoutPreparationRequest: WorkoutPreparationRequest?
    var activeMobilitySession: MobilitySession?
    var activeAssessmentSession: MobilityAssessmentSession?

    func requestDiscardActiveWorkout() {
        shouldDiscardActiveWorkout = true
        isShowingActiveWorkout = false
    }

    func showActiveWorkout() {
        activeWorkoutPath.removeAll()
        isShowingActiveWorkout = true
    }

    func clearActiveWorkoutPath() {
        activeWorkoutPath.removeAll()
    }

    func startMobility(
        _ routine: MobilityRoutine,
        _ context: MobilitySessionContext,
        _ workoutID: UUID?,
        using modelContext: ModelContext
    ) {
        guard let session = MobilitySessionService.start(
            routine: routine,
            context: context,
            workoutID: workoutID,
            using: modelContext
        ) else { return }
        activeMobilitySession = session
    }

    func resumeMobility(_ session: MobilitySession, using modelContext: ModelContext) {
        let restored: MobilitySession?
        switch MobilitySessionService.restoreActiveSession(using: modelContext) {
        case .restored(let restoredSession), .repaired(let restoredSession):
            restored = restoredSession
        case .none, .invalid, .persistenceFailure:
            restored = nil
        }
        guard let restored, restored.id == session.id else { return }
        activeMobilitySession = restored
    }

    /// Mirrors `startMobility`: a mobility program session is compiled and
    /// started by `MobilityProgramRunCoordinator` before this is called, so
    /// this only takes ownership of presenting it — the one centralized
    /// `activeMobilitySession` fullScreenCover every mobility session (
    /// standalone or program) presents through.
    func startMobilityProgramSession(_ session: MobilitySession) {
        activeMobilitySession = session
    }

    func startFreeWorkout(workoutVM: WorkoutViewModel, using modelContext: ModelContext) {
        if !workoutVM.hasActiveWorkout {
            workoutVM.startWorkout(using: modelContext)
        }
        isShowingActiveWorkout = workoutVM.hasActiveWorkout
    }

    @discardableResult
    func startWorkout(from template: WorkoutTemplate, using modelContext: ModelContext, workoutVM: WorkoutViewModel) -> PendingWorkoutStart {
        let start = PendingWorkoutStart.template(template)
        requestWorkoutStart(start, using: modelContext, workoutVM: workoutVM)
        return start
    }

    @discardableResult
    func startPlannedWorkout(
        _ planRun: PlanRun,
        _ progress: PlanWorkoutProgress,
        using modelContext: ModelContext,
        workoutVM: WorkoutViewModel
    ) -> PendingWorkoutStart? {
        guard let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: planRun) else { return nil }
        let start = PendingWorkoutStart.planned(PendingPlannedWorkout(
            planRun: planRun,
            progress: progress,
            plannedWorkout: plannedWorkout
        ))
        requestWorkoutStart(start, using: modelContext, workoutVM: workoutVM)
        return start
    }

    @discardableResult
    func startRepeatingWorkout(_ run: RepeatingPlanRun, using modelContext: ModelContext, workoutVM: WorkoutViewModel) -> PendingWorkoutStart {
        let start = PendingWorkoutStart.repeating(run, .expected)
        requestWorkoutStart(start, using: modelContext, workoutVM: workoutVM)
        return start
    }

    @discardableResult
    func startAlternateRepeatingWorkout(
        _ run: RepeatingPlanRun,
        _ slotIndex: Int,
        _ continuationMode: RepeatingPlanContinuationMode,
        using modelContext: ModelContext,
        workoutVM: WorkoutViewModel
    ) -> PendingWorkoutStart {
        let start = PendingWorkoutStart.repeating(
            run,
            .alternate(slotIndex: slotIndex, continuationMode: continuationMode)
        )
        requestWorkoutStart(start, using: modelContext, workoutVM: workoutVM)
        return start
    }

    @discardableResult
    func repeatRepeatingWorkout(_ run: RepeatingPlanRun, using modelContext: ModelContext, workoutVM: WorkoutViewModel) -> PendingWorkoutStart {
        let start = PendingWorkoutStart.repeating(run, .repeatLast)
        requestWorkoutStart(start, using: modelContext, workoutVM: workoutVM)
        return start
    }

    func requestWorkoutStart(_ start: PendingWorkoutStart, using modelContext: ModelContext, workoutVM: WorkoutViewModel) {
        guard workoutVM.hasActiveWorkout == false else {
            pendingWorkoutStart = start
            isShowingActiveWorkoutConflictAlert = true
            return
        }
        requestWorkoutPreparation(for: start, using: modelContext)
    }

    func requestWorkoutPreparation(for start: PendingWorkoutStart, using modelContext: ModelContext) {
        let warmupRoutine = WorkoutMobilityLinkResolver.linkedRoutine(
            for: start,
            phase: .warmup,
            using: modelContext
        )
        let activeSession = MobilitySessionService.activeSession(using: modelContext)
        if warmupRoutine != nil || activeSession != nil {
            workoutPreparationRequest = WorkoutPreparationRequest(
                start: start,
                warmupRoutine: warmupRoutine
            )
        } else {
            workoutPreparationRequest = nil
        }
    }

    func reset() {
        isShowingActiveWorkout = false
        shouldDiscardActiveWorkout = false
        isShowingActiveWorkoutConflictAlert = false
        activeWorkoutPath.removeAll()
        pendingWorkoutStart = nil
        workoutPreparationRequest = nil
        activeMobilitySession = nil
        activeAssessmentSession = nil
    }
}

import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class GuidedSourceConflictCoordinator {
    var guidedSourceConflictRequest: GuidedSourceConflictRequest?
    var pendingGuidedSourceUndo: GuidedSourceSwitchSnapshot?
    var guidedSourceActionError: String?

    private var guidedSourceUndoTask: Task<Void, Never>?

    var guidedSourceSwitchTitle: String {
        guard let request = guidedSourceConflictRequest else { return String(localized: "Change active plan?") }
        switch request {
        case .chooseFromToday:
            return String(localized: "Choose your active plan")
        case .activate(_), .resume(_):
            return String(localized: "Switch to this rotation?")
        case .workoutStart(let request):
            if case .planned = request.start {
                return String(localized: "Switch to this training plan?")
            }
            return String(localized: "Switch to this rotation?")
        case .fixedPlan(_):
            return String(localized: "Switch to this training plan?")
        }
    }

    var guidedSourceSwitchMessage: String {
        guard case .chooseFromToday? = guidedSourceConflictRequest else {
            return String(localized: "Your current plan will be paused, not deleted. Its progress and completed workouts stay available, and you can resume it later.")
        }
        return String(localized: "Choose which plan appears in Today. The other plan will be paused, while its progress and completed workouts remain available.")
    }

    deinit {
        guidedSourceUndoTask?.cancel()
    }

    func scheduleUndo(for snapshot: GuidedSourceSwitchSnapshot, outcome: PlanLifecycleOutcome) {
        guard snapshot.fixedRuns.count + snapshot.repeatingRuns.count == 1 else { return }
        switch outcome {
        case .succeeded, .succeededSilently:
            break
        case .failed, .needsConflictResolution:
            return
        }
        guidedSourceUndoTask?.cancel()
        pendingGuidedSourceUndo = snapshot
        GymAnnouncement.post(String(localized: "Active plan changed. Undo is available."))
        guidedSourceUndoTask = Task {
            try? await Task.sleep(for: .seconds(UIAccessibility.isVoiceOverRunning ? 16 : 8))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.pendingGuidedSourceUndo = nil
                self?.guidedSourceUndoTask = nil
            }
        }
    }

    func dismissUndo() {
        guidedSourceUndoTask?.cancel()
        guidedSourceUndoTask = nil
        pendingGuidedSourceUndo = nil
    }

    func undoRepeatingPlanAdvancement(_ run: RepeatingPlanRun, workoutVM: WorkoutViewModel, using modelContext: ModelContext) {
        guard !workoutVM.hasActiveWorkout, !workoutVM.restoreActiveWorkout(using: modelContext).didSave else {
            guidedSourceActionError = "Finish or discard the active workout before undoing a rotation change."
            return
        }
        guard workoutVM.undoLastRepeatingPlanAdvancement(in: run, using: modelContext) else {
            guidedSourceActionError = "Undo is available only for the most recent completed or skipped rotation change."
            return
        }
    }

    func registerGuidedSourceUndo(
        _ snapshot: GuidedSourceSwitchSnapshot,
        after outcome: PlanActionOutcome = .succeededSilently,
        workoutVM: WorkoutViewModel
    ) {
        guard !workoutVM.hasActiveWorkout else { return }
        scheduleUndo(for: snapshot, outcome: outcome)
    }

    func reset() {
        guidedSourceConflictRequest = nil
        guidedSourceUndoTask?.cancel()
        guidedSourceUndoTask = nil
        pendingGuidedSourceUndo = nil
        guidedSourceActionError = nil
    }
}

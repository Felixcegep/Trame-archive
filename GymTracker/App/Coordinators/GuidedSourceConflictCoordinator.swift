import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class GuidedSourceConflictCoordinator {
    var guidedSourceConflictRequest: GuidedSourceConflictRequest?
    var pendingGuidedSourceUndo: GuidedSourceSwitchSnapshot?
    var guidedSourceActionError: String?

    private var guidedSourceUndoTask: Task<Void, Never>?

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

    func reset() {
        guidedSourceConflictRequest = nil
        guidedSourceUndoTask?.cancel()
        guidedSourceUndoTask = nil
        pendingGuidedSourceUndo = nil
        guidedSourceActionError = nil
    }
}

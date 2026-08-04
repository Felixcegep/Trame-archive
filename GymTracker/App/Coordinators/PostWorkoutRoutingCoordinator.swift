import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class PostWorkoutRoutingCoordinator {
    var warmupWorkoutID: UUID?
    var pendingCooldownAfterWorkoutDismissal: MobilityRoutineLaunchRequest?
    var cooldownRequest: MobilityRoutineLaunchRequest?
    var pendingProgressionReceiptWorkoutID: UUID?
    var progressionReceiptRequest: ProgressionReceiptRequest?

    func clearPendingAfterDiscard() {
        pendingCooldownAfterWorkoutDismissal = nil
        pendingProgressionReceiptWorkoutID = nil
    }

    /// Explicitly processes post-workout dismissal routing state machine.
    /// Order: Cooldown first (if requested), then Progression Receipt (if owed).
    func processPostWorkoutDismissal(
        using modelContext: ModelContext,
        presentAfterDismissal: @escaping (@escaping () -> Void) -> Void
    ) {
        if let pendingCooldown = pendingCooldownAfterWorkoutDismissal {
            pendingCooldownAfterWorkoutDismissal = nil
            presentAfterDismissal { [weak self] in
                self?.cooldownRequest = pendingCooldown
            }
        }
        if let pendingWorkoutID = pendingProgressionReceiptWorkoutID,
           let receipt = ProgressionReceiptPolicy.receipt(
            forWorkoutID: pendingWorkoutID,
            using: modelContext
           ) {
            pendingProgressionReceiptWorkoutID = nil
            presentAfterDismissal { [weak self] in
                self?.progressionReceiptRequest = receipt
            }
        }
    }

    func prepareCooldown(for workoutID: UUID, using modelContext: ModelContext) {
        guard let workout = ProgressionReceiptPolicy.workout(id: workoutID, using: modelContext),
              let routine = WorkoutMobilityLinkResolver.linkedRoutine(
                for: workout,
                phase: .cooldown,
                using: modelContext
              )
        else { return }
        pendingCooldownAfterWorkoutDismissal = MobilityRoutineLaunchRequest(
            routine: routine,
            context: .cooldown,
            workoutID: workoutID
        )
    }

    func preparePendingProgressionReceipts(for workoutID: UUID, using modelContext: ModelContext) {
        guard ProgressionReceiptPolicy.owesReceipt(forWorkoutID: workoutID, using: modelContext) else {
            return
        }
        pendingProgressionReceiptWorkoutID = workoutID
    }

    func clearCooldownRequest() {
        cooldownRequest = nil
    }

    func clearWarmupWorkoutID() {
        warmupWorkoutID = nil
    }

    func reset() {
        warmupWorkoutID = nil
        pendingCooldownAfterWorkoutDismissal = nil
        cooldownRequest = nil
        pendingProgressionReceiptWorkoutID = nil
        progressionReceiptRequest = nil
    }
}

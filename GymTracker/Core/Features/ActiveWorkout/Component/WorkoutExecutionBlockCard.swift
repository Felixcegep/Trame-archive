import SwiftUI

/// Root-owned wrapper for the focused execution surface. Sheet and destructive
/// presentation state stays here while the eyes-up view owns only block
/// interaction and delegates mutations to `WorkoutExecutionBlockService`.
struct WorkoutExecutionBlockCard: View {
    @Bindable var block: WorkoutExecutionBlock
    let workout: Workout
    let onPersist: () -> Void
    let onRoundCompleted: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    @State private var isShowingScoreSheet = false
    @State private var isShowingRemovalConfirmation = false

    var body: some View {
        WorkoutExecutionBlockEyesUpView(
            block: block,
            workout: workout,
            onPersist: onPersist,
            onRoundCompleted: onRoundCompleted,
            onRecordScore: { isShowingScoreSheet = true },
            onEdit: onEdit,
            onRemove: { isShowingRemovalConfirmation = true }
        )
        .sheet(isPresented: $isShowingScoreSheet) {
            BlockScoreEntrySheet(block: block, onPersist: onPersist)
        }
        .confirmationDialog(
            "Remove execution block?",
            isPresented: $isShowingRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove block", role: .destructive, action: onRemove)
        } message: {
            Text("Exercises stay in the workout, but their shared block configuration and score will be removed.")
        }
    }
}

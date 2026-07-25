import SwiftUI
import SwiftData

struct SetRowActionsView: View {
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let isEditingCompletedSet: Bool
    let finishCompletedSetEditing: () -> Void
    let beginCompletedSetEditing: () -> Void
    @Binding var isShowingIncompleteConfirmation: Bool
    let discardCompletedSetEditing: () -> Void

    var body: some View {
        if isEditingCompletedSet {
            Button("Finish") {
                finishCompletedSetEditing()
            }
            .buttonStyle(.borderedProminent)
            .font(AppFont.footnoteMedium)
            .frame(minHeight: 44)
            .accessibilityLabel("Finish editing")
            .accessibilityHint("Saves the edited values.")
            .accessibilityIdentifier("finish-editing-set-\(exerciseEntry.exercise.name)-\(index)")

            Menu {
                Button("Mark set incomplete", role: .destructive) {
                    isShowingIncompleteConfirmation = true
                }
                Button("Discard changes", role: .destructive) {
                    discardCompletedSetEditing()
                }
            } label: {
                Image(systemName: AppIcon.ellipsis)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Completed set actions")
            .accessibilityIdentifier("completed-set-menu-\(exerciseEntry.exercise.name)-\(index)")
        } else if exerciseSet.done {
            Button {
                beginCompletedSetEditing()
            } label: {
                Image(systemName: AppIcon.edit)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(Color.gymPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.gymPrimary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.borderless)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Edit completed set")
            .accessibilityHint("Values become editable; the set stays completed.")
            .accessibilityIdentifier("edit-completed-set-\(exerciseEntry.exercise.name)-\(index)")
        } else {
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }
}

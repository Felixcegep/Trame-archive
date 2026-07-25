import SwiftUI
import SwiftData

struct SetRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let viewModel: ActiveWorkoutViewModel
    let coordinator: SetInputCoordinator
    @Binding var editingCompletedSetID: PersistentIdentifier?
    let onButtonPress: () -> Void
    let onSetCompleted: () -> Void
    let previousSet: PreviousSetPerformance?
    let onRemove: () -> Void

    @State private var isShowingSetDetails = false
    @State private var completionValidationMessage: String?
    @State private var isShowingIncompleteConfirmation = false
    @State private var isTimerRunning = false
    @State private var completedEditSnapshot: CompletedSetEditSnapshot?

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            rowInputs

            SetRowSecondaryContent(
                index: index,
                exerciseSet: exerciseSet,
                exerciseEntry: exerciseEntry,
                viewModel: viewModel,
                coordinator: coordinator,
                previousSet: previousSet,
                isCurrentSet: isCurrentSet,
                completionValidationMessage: $completionValidationMessage,
                isTimerRunning: $isTimerRunning,
                isShowingSetDetails: $isShowingSetDetails
            )
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.s)
        .contentShape(Rectangle())
        .onTapGesture {
            beginEditingIfNeeded()
        }
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(isEditingCompletedSet ? Color.gymPrimary : .clear, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if isCurrentSet, !exerciseSet.done, !isEditingCompletedSet {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.gymPrimary)
                    .frame(width: 3)
                    .padding(.vertical, Spacing.m)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.compact, value: exerciseSet.done)
        .sensoryFeedback(.success, trigger: exerciseSet.done) { _, newValue in
            newValue
        }
        .confirmationDialog(
            "Mark this set incomplete?",
            isPresented: $isShowingIncompleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Mark set incomplete", role: .destructive, action: markIncomplete)
        } message: {
            Text("Its logged values will stay in place and become editable.")
        }
        .onAppear {
            synchronizeIncompleteSetUnits()
            prefillPrescribedDurationIfNeeded()
        }
        .sheet(isPresented: $isShowingSetDetails, onDismiss: {
            viewModel.persistChanges()
        }) {
            SetDetailSheet(
                index: index,
                exerciseSet: exerciseSet,
                exerciseName: exerciseEntry.exercise.name,
                onPersist: { viewModel.persistChanges() },
                onDelete: onRemove
            )
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(480), .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var rowInputs: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedRowInputs
        } else {
            ViewThatFits(in: .horizontal) {
                horizontalRowInputs
                stackedRowInputs
            }
        }
    }

    private var horizontalRowInputs: some View {
        HStack(spacing: Spacing.s) {
            statusBadge

            fieldStack(isStacked: false)

            rowActions
        }
    }

    private var stackedRowInputs: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                statusBadge
                Text("Set \(index + 1) · \(exerciseSet.setType.title)")
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                rowActions
            }

            fieldStack(isStacked: true)
        }
    }

    private func fieldStack(isStacked: Bool) -> some View {
        SetRowFieldStack(
            index: index,
            exerciseSet: exerciseSet,
            exerciseEntry: exerciseEntry,
            coordinator: coordinator,
            previousSet: previousSet,
            isCompletedAndLocked: isCompletedAndLocked,
            isTimerRunning: isTimerRunning,
            isStacked: isStacked,
            onFieldSelected: { completionValidationMessage = nil }
        )
    }

    private var statusBadge: some View {
        SetRowStatusControl(
            index: index,
            exerciseSet: exerciseSet,
            exerciseEntry: exerciseEntry,
            isCurrentSet: isCurrentSet,
            isEditingCompletedSet: isEditingCompletedSet,
            handleCompletionButton: handleCompletionButton
        )
    }

    private var isCurrentSet: Bool {
        exerciseEntry.orderedSets.first(where: { !$0.done })?.persistentModelID == exerciseSet.persistentModelID
    }

    private var rowSurface: Color {
        if isEditingCompletedSet {
            return Color.gymPrimarySurface
        }
        if exerciseSet.done {
            return Color.gymSecondarySurface
        }

        return isCurrentSet ? Color.gymCurrentSetSurface : Color.gymRowSurface
    }

    private var rowActions: some View {
        SetRowActionsView(
            index: index,
            exerciseSet: exerciseSet,
            exerciseEntry: exerciseEntry,
            isEditingCompletedSet: isEditingCompletedSet,
            finishCompletedSetEditing: finishCompletedSetEditing,
            beginCompletedSetEditing: beginCompletedSetEditing,
            isShowingIncompleteConfirmation: $isShowingIncompleteConfirmation,
            discardCompletedSetEditing: discardCompletedSetEditing
        )
    }

    private var isCompletedAndLocked: Bool {
        exerciseSet.done && editingCompletedSetID != exerciseSet.persistentModelID
    }

    private var isEditingCompletedSet: Bool {
        exerciseSet.done && editingCompletedSetID == exerciseSet.persistentModelID
    }

    private func beginEditingIfNeeded() {
        guard !isCompletedAndLocked else { return }

        if coordinator.focus?.setID != exerciseSet.persistentModelID {
            coordinator.focus = SetInputFocus(
                exerciseID: exerciseEntry.persistentModelID,
                setID: exerciseSet.persistentModelID,
                field: SetInputCoordinator.firstMissingField(in: exerciseSet, for: trackingType)
            )
        }
    }

    private func beginCompletedSetEditing() {
        guard isCompletedAndLocked else { return }
        completedEditSnapshot = CompletedSetEditSnapshot(exerciseSet)
        editingCompletedSetID = exerciseSet.persistentModelID
        completionValidationMessage = nil
        UIAccessibility.post(notification: .announcement, argument: "Editing set \(index + 1)")
        coordinator.focus = SetInputFocus(
            exerciseID: exerciseEntry.persistentModelID,
            setID: exerciseSet.persistentModelID,
            field: firstInputField
        )
    }

    private func finishCompletedSetEditing() {
        guard viewModel.canComplete(exerciseSet, for: exerciseEntry) else {
            completionValidationMessage = SetRowCompletionValidation.message(
                for: exerciseSet,
                trackingType: trackingType
            )
            return
        }
        completionValidationMessage = nil
        completedEditSnapshot = nil
        editingCompletedSetID = nil
        coordinator.focus = nil
        viewModel.persistChanges()
    }

    private func discardCompletedSetEditing() {
        completedEditSnapshot?.restore(on: exerciseSet)
        completedEditSnapshot = nil
        editingCompletedSetID = nil
        completionValidationMessage = nil
        coordinator.focus = nil
        viewModel.persistChanges()
    }

    private var firstInputField: SetInputFocus.Field {
        if trackingType.usesReps { return .repetitions }
        if trackingType.usesWeight { return .weight }
        if trackingType.usesDuration { return .duration }
        if trackingType.usesDistance { return .distance }
        return .calories
    }

    private func handleCompletionButton() {
        if exerciseSet.done {
            isShowingIncompleteConfirmation = true
        } else {
            toggleDone()
        }
    }

    private func markIncomplete() {
        guard exerciseSet.done, viewModel.switchStateDoneSet(exerciseEntry, exerciseSet) else { return }
        completedEditSnapshot = nil
        editingCompletedSetID = nil
        completionValidationMessage = nil
    }

    private func prefillPrescribedDurationIfNeeded() {
        if SetRowPreparation.prefillPrescribedDuration(for: exerciseSet, in: exerciseEntry) {
            viewModel.persistChanges()
        }
    }

    private func synchronizeIncompleteSetUnits() {
        if SetRowPreparation.synchronizeUnits(
            for: exerciseSet,
            preferredSystem: UserDefaults.standard.unitSystem
        ) {
            viewModel.persistChanges()
        }
    }

    private func toggleDone() {
        switch viewModel.completeSet(exerciseSet, in: exerciseEntry) {
        case .blocked(let message, let focus):
            completionValidationMessage = message
            coordinator.focus = focus
        case .completed(let nextFocus):
            completionValidationMessage = nil
            onButtonPress()
            onSetCompleted()
            coordinator.focus = nextFocus
        case .reopened:
            completionValidationMessage = nil
        case .failed:
            break
        }
    }
}

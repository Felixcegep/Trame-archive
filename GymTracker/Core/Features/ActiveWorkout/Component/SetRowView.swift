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
        // A shape, not a hue. The current row was previously marked by a tinted
        // fill, a tinted index, and this bar — three cues that are all the same
        // cue, and all of which vanish in grayscale, under Increase Contrast, or
        // for a red/green-blind lifter. The pointer reads as "you are here" from
        // its silhouette. It stays inside the row's own leading padding, so the
        // value columns lose no width to it.
        .overlay(alignment: .leading) {
            if isCurrentSet, !exerciseSet.done, !isEditingCompletedSet {
                Image(systemName: AppIcon.currentPointer)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.compact, value: exerciseSet.done)
        .gymFeedback(.setCompleted, trigger: exerciseSet.done) { _, newValue in
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

    /// Only a state gets a fill. A plain incomplete row draws none and inherits
    /// the card's surface.
    ///
    /// `gymRowSurface` was a third tone that bought no separation: in dark mode it
    /// is `#26262B` against a current exercise card's `#222838`, near-identical in
    /// luminance and merely different in hue, and a completed row's
    /// `gymSecondarySurface` is already *exactly* the completed card's own fill —
    /// so fills were demonstrably not what distinguished one row from the next.
    /// Removing the ambient one leaves current, done, and editing as the only
    /// filled rows in the list, which is what makes those fills read as meaning
    /// rather than as texture. Rows stay separated by the list's spacing and by
    /// the field outlines they contain.
    /// The current row loses its fill too, for the reason the comment above
    /// already establishes and then stops one step short of.
    ///
    /// A current set inside a current exercise was three tinted surfaces
    /// stacked: `gymPrimarySurface` on the card, `gymCurrentSetSurface` on the
    /// row, and outlined cells inside that. The two tints differ by a few points
    /// of luminance, so the inner one separated nothing — it just made the card
    /// look quilted. "You are here" is already carried by the leading pointer
    /// (a silhouette, which survives grayscale and Increase Contrast), by the
    /// tinted index chip, and by the card's own heading.
    ///
    /// A completed row keeps its wash. That one is genuinely state, it is the
    /// fastest way to scan which sets are behind you, and it is what the
    /// closest domain reference does as well.
    private var rowSurface: Color {
        if isEditingCompletedSet {
            return Color.gymPrimarySurface
        }
        if exerciseSet.done {
            return Color.gymSecondarySurface
        }

        return .clear
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
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "Editing set \(index + 1)")
        )
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
            in: exerciseEntry,
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
            onSetCompleted()
            coordinator.focus = nextFocus
        case .reopened:
            completionValidationMessage = nil
        case .failed:
            break
        }
    }
}

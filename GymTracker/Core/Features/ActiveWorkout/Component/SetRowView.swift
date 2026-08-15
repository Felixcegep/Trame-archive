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
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .contentShape(Rectangle())
        .onTapGesture {
            beginEditingIfNeeded()
        }
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(rowBorder, lineWidth: rowBorderWidth)
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
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameAction)
                    // Clear of the current row's structural outline.
                    .padding(.leading, Spacing.xs)
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
            // Order is the precedence. A prescribed duration is written first,
            // which leaves the set filled and so takes the automatic
            // previous-performance fill below out of play — the plan's opinion
            // outranks last session's.
            prefillPrescribedDurationIfNeeded()
            autofillFromPreviousPerformanceIfNeeded()
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

            previousValueColumn

            fieldStack(isStacked: false)

            rowActions
        }
    }

    /// What this same set index produced last time, read at a glance beside
    /// the fields it is a target for.
    ///
    /// Horizontal layout only. At accessibility sizes the row already falls
    /// back to a stacked layout for the same reason this column does not
    /// follow it there — five columns is already three more than the space
    /// affords. The exercise-header summary above every card and the set
    /// panel's own "Last time" line still carry the same information at
    /// those sizes; this is a convenience for the common case, not the only
    /// place it exists.
    private var previousValueColumn: some View {
        Text(previousValueText)
            .font(AppFont.caption)
            .foregroundStyle(Color.trameSubdued)
            .lineLimit(1)
            .frame(width: 52, alignment: .leading)
            .accessibilityLabel(String(localized: "Previous: \(previousValueText)"))
            .accessibilityIdentifier("previous-set-\(exerciseEntry.exercise.name)-\(index)")
    }

    private var previousValueText: String {
        guard let previousSet else { return "\u{2014}" }
        if trackingType.usesWeight {
            let weight = UnitConversion.weight(
                previousSet.weight,
                from: previousSet.weightType,
                to: exerciseSet.weightType
            )
            return "\(Formatters.formatFloat(previousSet.repetitions)) × \(Formatters.formatFloat(weight))"
        }
        if trackingType.usesDuration, let duration = previousSet.duration {
            return "\(Int(duration)) sec"
        }
        if trackingType.usesReps {
            return "\(Formatters.formatFloat(previousSet.repetitions)) reps"
        }
        if trackingType.usesCalories, let calories = previousSet.calories {
            return "\(Formatters.formatFloat(Float(calories))) cal"
        }
        return "\u{2014}"
    }

    private var stackedRowInputs: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                statusBadge
                Text("Set \(index + 1) · \(exerciseSet.setType.title)")
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameSubdued)
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
            isCurrentSet: isCurrentSet,
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

    /// Untouched sets belong to the open table. Opaque fields are reserved for
    /// meaningful state: current, completed, or explicit completed-set editing.
    private var rowSurface: Color {
        if isEditingCompletedSet {
            return Color.trameCurrent
        }
        if exerciseSet.done {
            return Color.trameRow
        }
        if isActiveSet {
            return Color.trameCurrent
        }
        return Color.clear
    }

    /// Current/editing state gets a structural edge in addition to its fill and
    /// pointer. Completed state already carries a checkmark and opaque row field.
    private var rowBorder: Color {
        if isEditingCompletedSet { return Color.trameStrength }
        if isActiveSet { return Color.trameActionOutline }
        return Color.clear
    }

    private var rowBorderWidth: CGFloat {
        isEditingCompletedSet || isActiveSet ? 1.5 : 1
    }

    /// The one row the lifter is on: next up, and not yet logged.
    private var isActiveSet: Bool {
        isCurrentSet && !exerciseSet.done
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

    /// Commits the previous-performance value this row is already showing in
    /// grey, so "Log set" accepts the set the screen is describing.
    ///
    /// Uses the row's own `previousSet` — the same value the PREV column and
    /// the empty cells render — rather than looking one up, so what is written
    /// can never differ from what was displayed. The view model owns the
    /// refusals (completed, prescribed, already filled, already autofilled).
    private func autofillFromPreviousPerformanceIfNeeded() {
        guard let previousSet else { return }
        viewModel.autofillPreviousPerformanceIfUnfilled(
            previousSet,
            to: exerciseSet,
            in: exerciseEntry
        )
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

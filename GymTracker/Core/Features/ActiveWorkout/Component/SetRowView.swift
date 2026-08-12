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
        // Density, deliberately chosen rather than inherited.
        //
        // `Spacing.m` (12) put the rows on a ~78pt pitch, which fits three sets
        // on screen. The reference this was calibrated against runs 7pt and
        // fits six — but it is dark-on-dark with hairline dividers, while these
        // rows are bordered cards on cream and go muddy much below 48pt total.
        // `Spacing.s` (8) lands between the two at ~56pt, which is the point
        // where the common 3× and 5× prescriptions both stop needing a scroll.
        .padding(.vertical, Spacing.s)
        .contentShape(Rectangle())
        .onTapGesture {
            beginEditingIfNeeded()
        }
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .stroke(rowBorder, lineWidth: rowBorderWidth)
        }
        // Cream on cream: `gymCard` sits only a few points of luminance above
        // `gymBackground`, so in light mode the fill alone would not lift the
        // row off the page. The outline does most of the work and this does the
        // rest — at the design system's stated card weight, not more.
        .shadow(color: Color.gymText.opacity(0.03), radius: 4, y: 1)
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
                    // Clear of the row's own outline, which it would otherwise
                    // sit directly on top of now that every row draws one.
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
            .foregroundStyle(Color.gymSubduedText)
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

    /// Every row is a card.
    ///
    /// This previously returned `.clear` for a plain incomplete row, on the
    /// reasoning that only a *state* should get a fill and that rows would stay
    /// separated by list spacing and by the outlines of the value cells inside
    /// them. Against the old dense card list that held. Against the paged stage
    /// it does not, for a reason the old layout never exposed: a row is not one
    /// line. It is a value line **plus** `SetRowSecondaryContent` — Olympic
    /// complex components, a tempo note, an RPE badge, a duration countdown, a
    /// "use last time" button. With no fill behind either part, that secondary
    /// block floats in the gap between two rows and belongs, visually, to
    /// whichever one the eye reaches first. A lifter looking at three snatch
    /// singles cannot tell which set the "COMPLEX · Snatch ×1 · Not logged"
    /// block is attached to, and that is the one thing the row has to make
    /// unambiguous.
    ///
    /// A fill is what makes a row *one object*. So the surface now answers
    /// "which set is this" first and "what state is it in" second — the border
    /// carries state alongside it (see `rowBorder`), which is a second channel
    /// rather than a competing one.
    private var rowSurface: Color {
        if isEditingCompletedSet {
            return Color.gymPrimarySurface
        }
        if exerciseSet.done {
            // A completed row keeps its wash. It is genuinely state, and it is
            // the fastest way to scan which sets are behind you.
            return Color.gymSecondarySurface
        }
        return Color.gymCard
    }

    /// State, carried on the outline so it does not have to compete with the
    /// fill that separates one row from the next.
    ///
    /// The current row is outlined in the same blue that marks a focused value
    /// cell, which is the app's existing "this is what you can act on now"
    /// signal — and it matches what the closest domain references do for an
    /// active set.
    private var rowBorder: Color {
        if isEditingCompletedSet || isActiveSet {
            return Color.gymPrimary
        }
        if exerciseSet.done {
            return Color.gymSecondary.opacity(0.35)
        }
        return Color.gymBorder
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

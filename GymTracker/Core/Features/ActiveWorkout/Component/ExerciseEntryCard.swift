import SwiftUI
import SwiftData

struct ExerciseEntryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var exerciseEntry: ExerciseEntry
    let executionBlock: WorkoutExecutionBlock?

    let viewModel: ActiveWorkoutViewModel
    let unitSystem: UnitSystem
    let coordinator: SetInputCoordinator
    @Binding var expandedExerciseID: PersistentIdentifier?
    @Binding var editingCompletedSetID: PersistentIdentifier?
    let previousPerformance: PreviousExercisePerformance?
    let onExerciseCompleted: () -> Void
    let onSwapRequested: () -> Void
    let supersetCandidates: [ExerciseEntry]
    /// Non-nil only for the one exercise the workout's recommendation belongs
    /// to. The root owns that selection so no second card can appear.
    let recommendationState: RecommendationPresentationState?
    let onRecommendationAction: (RecommendationAction) -> Void
    /// Moves this exercise one position. `nil` at the ends of the list.
    ///
    /// Reordering was drag-only, via `onDrag`/`onDrop`, which VoiceOver and
    /// Switch Control cannot reach at all — and which nothing on the card
    /// advertised, so most sighted users never found it either. Every other
    /// reorderable list in the app uses `List.onMove`, which gets an accessible
    /// path for free; Active Workout was the one that did not, and it is the
    /// one used mid-session when a rack is occupied.
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    @State private var horizontalOffset: CGFloat = 0
    @State private var hasCrossedSwipeThreshold = false
    @State private var isShowingRemoveConfirmation = false

    private let swipeTriggerDistance: CGFloat = 70

    var body: some View {
        ZStack(alignment: .trailing) {
            exerciseDoneBackground

            activeExerciseCard
                .offset(x: horizontalOffset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        // Swiping is unreachable under VoiceOver and Switch Control, so the
        // same capability is exposed as a named action. It resolves the set
        // through the identical selector the gesture uses, so the two paths
        // can never disagree about which set is next.
        .accessibilityAction(named: Text("Complete current set")) {
            completeCurrentSet()
        }
        .accessibilityActions {
            if let onMoveUp {
                Button("Move \(exerciseEntry.exercise.name) up", action: onMoveUp)
            }
            if let onMoveDown {
                Button("Move \(exerciseEntry.exercise.name) down", action: onMoveDown)
            }
        }
        // Crossing the trigger distance is a snap point: the lifter learns
        // where the gesture commits before releasing, which is the difference
        // between a deliberate swipe and an accidental one.
        .gymFeedback(.swipeArmed, trigger: hasCrossedSwipeThreshold) { _, crossed in
            crossed
        }
        .confirmationDialog(
            "Remove \(exerciseEntry.exercise.name)?",
            isPresented: $isShowingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            // Names the consequence rather than repeating the menu item's
            // "Remove exercise", which would put two identically-labelled
            // controls in one transition.
            Button("Remove and delete sets", role: .destructive) {
                viewModel.removeExercise(exerciseEntry)
            }
            .accessibilityIdentifier("confirm-remove-exercise-\(exerciseEntry.exercise.name)")
        } message: {
            Text("\(CountPhrase.completedSets(completedSetCount)) will be deleted and will not appear in History.")
        }
    }

    private var activeExerciseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let executionBlock, executionBlock.kind != .straight {
                Label(executionBlock.kind.title, systemImage: AppIcon.relationship)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityIdentifier("execution-block-label-\(exerciseEntry.exercise.name)")
                    .padding(.bottom, Spacing.xs)
            } else if exerciseEntry.supersetGroupID != nil {
                Label("Superset", systemImage: "link")
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityIdentifier("superset-label-\(exerciseEntry.exercise.name)")
                    .padding(.bottom, Spacing.xs)
            }
            DisclosureGroup(isExpanded: disclosureBinding) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    recommendationCard
                    setHeader
                    setRows
                    setActions
                }
                .padding(.top, Spacing.m)
            } label: {
                exerciseHeader
            }

            // A recommendation for a collapsed exercise still has to be
            // readable, so it follows the header instead of disappearing with
            // the sets. Only one of the two placements ever renders.
            if !isCurrentExercise {
                recommendationCard
                    .padding(.top, Spacing.m)
            }
        }
        .padding(isCurrentExercise ? Spacing.l : Spacing.m)
        // Only a state gets a fill: done, or not. "Current" used to be a third
        // one — `gymPrimarySurface` on top of a `gymBorder` stroke and a blue
        // "CURRENT EXERCISE" label — three cues for one fact. The label,
        // sized larger as `titleSmall` rather than `headlineSemibold`, and the
        // set list's own current-row pointer already carry it; the card's own
        // colour was tinting a fact the page had already stated twice.
        .background(exerciseIsDone && !isCurrentExercise ? Color.gymSecondarySurface : Color.gymCard)
        // One neutral hairline for every card, current or not. A border's job
        // here is to define an edge, not to carry state.
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var disclosureBinding: Binding<Bool> {
        Binding(
            get: { expandedExerciseID == exerciseEntry.persistentModelID },
            set: { isExpanded in
                expandedExerciseID = isExpanded ? exerciseEntry.persistentModelID : nil
            }
        )
    }

    private var exerciseHeader: some View {
        HStack(spacing: Spacing.m) {
            if exerciseIsDone {
                Image(systemName: AppIcon.checkmarkCircle)
                    .foregroundStyle(Color.gymSecondary)
                    .font(AppFont.titleSmall)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if isCurrentExercise && !exerciseIsDone {
                    // Subdued, not blue. Blue is reserved for what can be acted
                    // on right now — a control, a focused field, a selection —
                    // and a status label is none of those. The card's larger
                    // title size already carries "this is the one you are on";
                    // the label states it in words for anyone landing on a
                    // collapsed list without that size difference registering.
                    Label("CURRENT EXERCISE", systemImage: AppIcon.circleFill)
                        .font(AppFont.caption2Bold)
                        .tracking(0.55)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Text(exerciseEntry.occurrenceDisplayName)
                    .font(isCurrentExercise ? AppFont.titleSmall : AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .accessibilityIdentifier("active-exercise-\(exerciseEntry.exercise.name)")

                if let original = exerciseEntry.originalExerciseNameSnapshot,
                   exerciseEntry.selectedSubstituteExerciseIDSnapshot != nil {
                    Label("Substituted for \(original)", systemImage: AppIcon.relationship)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityLabel("Substituted for \(original)")
                }

                if let loggingSemanticsCaption {
                    Text(loggingSemanticsCaption)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(1)
                }

                if let prescription = prescriptionSummary {
                    Text(prescription)
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier("prescription-summary-\(exerciseEntry.exercise.name)")
                }

                if let previousPerformance {
                    Text(previousPerformanceSummary(previousPerformance))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(1)
                        .accessibilityIdentifier("previous-performance-\(exerciseEntry.exercise.name)")
                }

                HStack(spacing: Spacing.s) {
                    Text("\(completedSetCount)/\(exerciseEntry.sets.count) sets")
                    Text("•")
                    // Only the exercise being worked ticks. Every card — expanded
                    // or collapsed — used to host its own 1Hz TimelineView, so an
                    // eight-exercise session invalidated eight subtrees a second
                    // while the lifter typed, and rewrote eight accessibility
                    // labels with it. A finished or waiting exercise's duration
                    // is not changing, so it is rendered once.
                    if isCurrentExercise {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(exerciseDurationText(at: context.date))
                                .monospacedDigit()
                        }
                        .accessibilityLabel("Exercise time")
                    } else {
                        Text(exerciseDurationText(at: .now))
                            .monospacedDigit()
                            .accessibilityLabel("Exercise time")
                    }
                }
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Menu {
                // The same capability as the left swipe, given a name. The
                // gesture is undiscoverable on its own and unreachable with
                // assistive technology.
                if canCompleteCurrentSet {
                    Button {
                        completeCurrentSet()
                    } label: {
                        Label("Complete current set", systemImage: AppIcon.checkmark)
                    }
                    .accessibilityIdentifier("complete-current-set-\(exerciseEntry.exercise.name)")
                }

                // Named alternatives to the drag gesture, so reordering is both
                // discoverable and reachable without one.
                if onMoveUp != nil || onMoveDown != nil {
                    Section {
                        if let onMoveUp {
                            Button {
                                onMoveUp()
                            } label: {
                                Label("Move up", systemImage: AppIcon.chevronUp)
                            }
                            .accessibilityIdentifier("move-exercise-up-\(exerciseEntry.exercise.name)")
                        }
                        if let onMoveDown {
                            Button {
                                onMoveDown()
                            } label: {
                                Label("Move down", systemImage: AppIcon.chevronDown)
                            }
                            .accessibilityIdentifier("move-exercise-down-\(exerciseEntry.exercise.name)")
                        }
                    }
                }

                if completedSetCount == 0 {
                    Button {
                        onSwapRequested()
                    } label: {
                        Label("Swap exercise", systemImage: AppIcon.relationship)
                    }
                    .accessibilityIdentifier("swap-exercise-\(exerciseEntry.exercise.name)")
                }

                if executionBlock == nil, exerciseEntry.supersetGroupID == nil, !supersetCandidates.isEmpty {
                    Menu("Superset with…") {
                        ForEach(supersetCandidates, id: \.persistentModelID) { candidate in
                            Button(candidate.nameSnapshot) {
                                viewModel.superset(exerciseEntry, with: candidate)
                            }
                        }
                    }
                } else if exerciseEntry.supersetGroupID != nil {
                    Button("Remove from superset") {
                        viewModel.removeFromSuperset(exerciseEntry)
                    }
                    .accessibilityIdentifier("remove-from-superset-\(exerciseEntry.exercise.name)")
                }

                // Removing an untouched exercise loses nothing and stays
                // immediate. Removing one that has been performed destroys
                // logged sets, so it has to state what it is destroying —
                // the same standard the discard-workout dialog already meets.
                Button(role: .destructive) {
                    if completedSetCount > 0 {
                        isShowingRemoveConfirmation = true
                    } else {
                        viewModel.removeExercise(exerciseEntry)
                    }
                } label: {
                    Label("Remove exercise", systemImage: AppIcon.trash)
                }
                .accessibilityIdentifier("remove-exercise-\(exerciseEntry.exercise.name)")
            } label: {
                Image(systemName: AppIcon.ellipsis)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 30, height: 30)
                    .background(Color.gymText.opacity(0.06))
                    .clipShape(Circle())
                    // The visual chip stays 30pt; the hit area does not. This
                    // menu holds "Remove exercise", so a near-miss here is the
                    // one that matters most.
                    .frame(
                        width: ComponentSize.minimumTouchTarget,
                        height: ComponentSize.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-menu-\(exerciseEntry.exercise.name)")
        }
        .contentShape(Rectangle())
    }

    private var setHeader: some View {
        HStack(spacing: Spacing.s) {
            Text("SET")
                .frame(width: 45, alignment: .leading)

            // Matches `SetRowView.previousValueColumn`'s width, and is gated
            // on the same condition: that column only renders in the
            // horizontal layout, so the header would otherwise promise a
            // column the rows do not draw at accessibility sizes.
            if !dynamicTypeSize.isAccessibilitySize {
                Text("PREV")
                    .frame(width: 52, alignment: .leading)
            }

            ForEach(inputTitles, id: \.self) { title in
                Text(title.uppercased())
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Matches the fixed trailing slot each set row reserves.
            Spacer().frame(width: 44)
        }
        .font(AppFont.caption2Bold)
        .tracking(0.55)
        .foregroundStyle(Color.gymSubduedText)
        .padding(.horizontal, Spacing.xs)
    }

    private var setRows: some View {
        VStack(spacing: 6) {
            ForEach(Array(exerciseEntry.orderedSets.enumerated()), id: \.element.persistentModelID) { index, exerciseSet in
                SetRowView(
                    index: index,
                    exerciseSet: exerciseSet,
                    exerciseEntry: exerciseEntry,
                    viewModel: viewModel,
                    coordinator: coordinator,
                    editingCompletedSetID: $editingCompletedSetID,
                    onSetCompleted: handleSetCompletion,
                    previousSet: previousPerformance?.set(at: exerciseSet.orderIndex),
                    onRemove: { viewModel.removeSet(exerciseEntry, exerciseSet) }
                )
                .id(exerciseSet.persistentModelID)
            }
        }
    }

    private var setActions: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.gymBorder)

            Button {
                viewModel.addSet(exerciseEntry)
            } label: {
                Label("Add set", systemImage: AppIcon.plus)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("add-set-\(exerciseEntry.exercise.name)")
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymPrimary)
            .buttonStyle(.borderless)
        }
    }

    /// Revealed as the card translates. It names the set, not the exercise:
    /// the gesture completes the next incomplete set, and "Complete" read as
    /// though it finished the whole exercise.
    private var exerciseDoneBackground: some View {
        HStack {
            Spacer()
            Label("Complete set", systemImage: AppIcon.checkmarkCircle)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(.white)
                .padding(.trailing, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gymSecondary)
        .accessibilityHidden(true)
    }

    /// Drag left to complete the next set.
    ///
    /// The card tracks the finger under Reduce Motion exactly as it does
    /// otherwise. Suppressing the translation there previously left the
    /// gesture armed but invisible, so a diagonal scroll could complete a set
    /// — and fire its success haptic — with nothing on screen having indicated
    /// that anything was about to happen. Reduce Motion removes the springy
    /// settle on release, which is the part that is actually vestibular; the
    /// finger-tracked travel is the affordance and has to stay.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard value.translation.width < 0, abs(value.translation.width) > abs(value.translation.height) else { return }
                let travel = abs(value.translation.width)
                let resistedTravel = travel <= swipeTriggerDistance
                    ? travel
                    : swipeTriggerDistance + ((travel - swipeTriggerDistance) * 0.2)
                horizontalOffset = -resistedTravel
                // One tick per crossing, in either direction, rather than one
                // per gesture: dragging back below the threshold disarms, and
                // the lifter should feel that too.
                hasCrossedSwipeThreshold = travel >= swipeTriggerDistance
            }
            .onEnded { value in
                let projectedTravel = min(value.translation.width, value.predictedEndTranslation.width)
                let didTrigger = projectedTravel <= -swipeTriggerDistance
                hasCrossedSwipeThreshold = false

                if didTrigger {
                    completeCurrentSet()
                }

                withAnimation(reduceMotion ? nil : AppMotion.gesture) { horizontalOffset = 0 }
            }
    }

    private var canCompleteCurrentSet: Bool {
        guard let exerciseSet = viewModel.getNextSet(in: exerciseEntry) else { return false }
        return viewModel.canComplete(exerciseSet, for: exerciseEntry)
    }

    /// The single completion path shared by the swipe, the overflow menu item,
    /// and the accessibility action, so all three validate and advance
    /// identically. `getNextSet` returns nil unless this entry owns the
    /// workout's next incomplete set, so the action is a no-op on any other
    /// card.
    private func completeCurrentSet() {
        guard let exerciseSet = viewModel.getNextSet(in: exerciseEntry),
              viewModel.canComplete(exerciseSet, for: exerciseEntry)
        else {
            return
        }

        if case .completed = viewModel.completeSet(exerciseSet, in: exerciseEntry) {
            handleSetCompletion()
        }
    }

    private var completedSetCount: Int {
        exerciseEntry.sets.filter(\.done).count
    }

    private var exerciseIsDone: Bool {
        !exerciseEntry.sets.isEmpty && completedSetCount == exerciseEntry.sets.count
    }

    private var isCurrentExercise: Bool {
        expandedExerciseID == exerciseEntry.persistentModelID
    }


    private func exerciseDurationText(at date: Date) -> String {
        let totalSeconds = max(0, Int(exerciseEntry.activeDuration(at: date)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var prescriptionSummary: String? {
        if trackingType.usesCalories,
           let setCount = exerciseEntry.prescribedSets,
           let calories = exerciseEntry.orderedSets.first?.prescribedCaloriesSnapshot {
            return "\(setCount) × \(Formatters.formatFloat(Float(calories))) cal"
        }

        if trackingType.usesDuration,
           let setCount = exerciseEntry.prescribedSets,
           let seconds = exerciseEntry.orderedSets.first?.prescribedDurationSecondsSnapshot {
            var summary = "\(setCount) × \(Int(seconds)) sec"
            if trackingType.usesDistance,
               let meters = exerciseEntry.orderedSets.first?.prescribedDistanceMetersSnapshot {
                summary += " · \(Formatters.formatFloat(Float(meters))) m"
            }
            return summary
        }

        if trackingType.usesDistance,
           let setCount = exerciseEntry.prescribedSets,
           let meters = exerciseEntry.orderedSets.first?.prescribedDistanceMetersSnapshot {
            return "\(setCount) × \(Formatters.formatFloat(Float(meters))) m"
        }

        guard let setCount = exerciseEntry.prescribedSets,
              let minimum = exerciseEntry.prescribedRepRangeMinimum,
              let maximum = exerciseEntry.prescribedRepRangeMaximum
        else {
            return nil
        }

        var components = ["\(setCount) × \(minimum)-\(maximum)"]
        if let rpe = exerciseEntry.prescribedRPE {
            components.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        }
        if let rir = exerciseEntry.prescribedRIR {
            components.append("RIR \(rir)")
        }
        if let tempo = exerciseEntry.orderedSets.first?.prescribedTempo,
           !tempo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append("Tempo \(tempo)")
        }
        if let load = exerciseEntry.prescribedSuggestedLoad,
           let unit = exerciseEntry.prescribedSuggestedLoadType {
            components.append("\(Formatters.formatFloat(Float(load))) \(unit.rawValue)")
        }
        return components.joined(separator: "  ·  ")
    }

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
    }

    private var loggingSemantics: LoggingSemantics {
        exerciseEntry.loggingSemanticsSnapshot
    }

    private var loggingSemanticsCaption: String? {
        var parts: [String] = []
        if loggingSemantics.laterality == .unilateral && loggingSemantics.repCountingStyle == .perSide {
            parts.append("Logged per side")
        }
        if loggingSemantics.weightEntryStyle == .perLoadUnit {
            parts.append("Weight per unit (×\(loggingSemantics.loadUnitCount))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The workout's single progression recommendation, rendered inside the
    /// exercise it describes. Applying, holding, or overriding it changes
    /// incomplete set loads only; completed sets stay historical truth.
    @ViewBuilder
    private var recommendationCard: some View {
        if let recommendationState, !exerciseIsDone {
            ProgressionRecommendationCard(
                exerciseName: exerciseEntry.exercise.name,
                state: recommendationState,
                onAction: onRecommendationAction
            )
        }
    }

    private var inputTitles: [String] {
        var titles: [String] = []
        if trackingType.usesReps {
            let isPerSide = loggingSemantics.laterality == .unilateral && loggingSemantics.repCountingStyle == .perSide
            titles.append(isPerSide ? "Reps / side" : "Reps")
        }
        if trackingType.usesWeight {
            let unitLabel = unitSystem == .metric ? "kg" : "lbs"
            let isPerUnit = loggingSemantics.weightEntryStyle == .perLoadUnit
            titles.append(isPerUnit ? "Weight (\(unitLabel) each)" : "Weight (\(unitLabel))")
        }
        if trackingType.usesDuration { titles.append("Seconds") }
        if trackingType.usesDistance { titles.append("Distance") }
        if trackingType.usesCalories { titles.append("Calories") }
        return titles
    }

    private func previousPerformanceSummary(_ performance: PreviousExercisePerformance) -> String {
        let date = performance.workoutDate.formatted(.dateTime.month(.abbreviated).day())
        let sets = performance.sets
        guard let first = sets.first else { return "Last time: \(date)" }

        if trackingType.usesWeight {
            let matchingReps = sets.allSatisfy { $0.repetitions == first.repetitions }
            let matchingWeight = sets.allSatisfy { $0.weight == first.weight && $0.weightType == first.weightType }
            if matchingReps && matchingWeight {
                return "Last time: \(sets.count) × \(Formatters.formatFloat(first.repetitions)) @ \(Formatters.formatFloat(first.weight)) \(first.weightType.rawValue) · \(date)"
            }
            return "Last time: \(sets.count) sets · up to \(Formatters.formatFloat(sets.map(\.weight).max() ?? 0)) \(first.weightType.rawValue) · \(date)"
        }

        if trackingType.usesReps {
            let matchingReps = sets.allSatisfy { $0.repetitions == first.repetitions }
            let reps = matchingReps
                ? Formatters.formatFloat(first.repetitions)
                : "\(Formatters.formatFloat(sets.map(\.repetitions).min() ?? 0))–\(Formatters.formatFloat(sets.map(\.repetitions).max() ?? 0))"
            return "Last time: \(sets.count) × \(reps) reps · \(date)"
        }

        if trackingType.usesCalories {
            let calories = Formatters.formatFloat(Float(first.calories ?? 0))
            let matchingCalories = sets.allSatisfy { $0.calories == first.calories }
            if matchingCalories {
                return "Last time: \(sets.count) × \(calories) cal · \(date)"
            }
            return "Last time: \(sets.count) sets · up to \(Formatters.formatFloat(Float(sets.compactMap(\.calories).max() ?? 0))) cal · \(date)"
        }

        return "Last time: \(sets.count) sets · \(date)"
    }

    private func handleSetCompletion() {
        onExerciseCompleted()
    }
}

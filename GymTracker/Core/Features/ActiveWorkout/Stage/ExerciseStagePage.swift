import SwiftUI
import SwiftData

private struct StageMetric: Identifiable {
    let id: String
    let value: String
    let unit: String
    let isPrimary: Bool
}

/// One page of the Active Workout pager: the exercise (or group of exercises)
/// the lifter is currently inside, and nothing else.
///
/// The card list this replaces had to answer two questions at once — "what am I
/// doing now" and "what does the rest of the session look like" — and answered
/// the second at the cost of the first: the exercise being worked was a
/// disclosure row among seven others, its title set at `title3`, its sets
/// competing with six collapsed headers for vertical space. Paging moves the
/// second question to the progress rail, where it belongs, and gives the first
/// one the screen.
struct ExerciseStagePage: View {
    let page: WorkoutStagePage
    let workout: Workout
    let viewModel: ActiveWorkoutViewModel
    let unitSystem: UnitSystem
    let coordinator: SetInputCoordinator
    @Binding var editingCompletedSetID: PersistentIdentifier?
    /// Non-nil only on the page owning the workout's single progression
    /// recommendation, so the evidence appears exactly once.
    let recommendation: (exercise: ExerciseEntry, state: RecommendationPresentationState)?
    let onRecommendationAction: (RecommendationAction, ExerciseEntry) -> Void
    let onSwapRequested: (ExerciseEntry) -> Void
    let onSetCompleted: (ExerciseEntry) -> Void
    let onAddExercise: () -> Void
    let onEditBlock: (WorkoutExecutionBlock) -> Void
    let onRemoveBlock: (WorkoutExecutionBlock) -> Void
    let canMove: (ExerciseEntry, Int) -> Bool
    let onMove: (ExerciseEntry, Int) -> Void

    /// Whether the lifter has overridden the warm-up band's automatic collapse,
    /// per exercise. Absent means "follow the rule".
    @State private var warmUpCollapseOverrides: [PersistentIdentifier: Bool] = [:]
    @State private var removalCandidate: ExerciseEntry?
    /// Exercises whose note field the lifter has opened this session. An empty
    /// note on an exercise nobody has asked about stays out of the way.
    @State private var expandedNoteIDs: Set<PersistentIdentifier> = []
    @FocusState private var focusedNoteID: PersistentIdentifier?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var entries: [ExerciseEntry] {
        WorkoutStagePlan.entries(for: page, in: workout)
    }

    private var executionBlock: WorkoutExecutionBlock? {
        guard case .block(let blockID) = page else { return nil }
        return workout.orderedExecutionBlocks.first { $0.id == blockID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    groupBanner

                    ForEach(entries, id: \.persistentModelID) { entry in
                        exerciseSection(for: entry)
                    }
                }
                .padding(.horizontal, Spacing.screenInset)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollIndicators(.hidden)
            // With the panel raised the page must not drift: the row being
            // edited is anchored once when focus lands, and a free scroll after
            // that slides it behind the keypad with no way to tell where it
            // went. Locking the scroll also frees the upward drag to mean
            // something — see the gesture below.
            .scrollDisabled(coordinator.focus != nil)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard coordinator.focus != nil else { return }
                        // Upward drag is the dismiss gesture. It reads as
                        // "push the keypad away" and restores scrolling in the
                        // same motion, which is what a lifter reaches for when
                        // they want to look further up the set list.
                        if value.translation.height < -40 {
                            coordinator.focus = nil
                        }
                    }
            )
            // The entry panel plus its keypad claims roughly half the screen,
            // so the row being edited is anchored at the top rather than
            // centred — centring would put it behind the panel.
            .onChange(of: coordinator.focus) { _, focus in
                guard let focus,
                      entries.contains(where: { $0.persistentModelID == focus.exerciseID })
                else { return }
                withAnimation(reduceMotion ? nil : AppMotion.layout) {
                    proxy.scrollTo(focus.setID, anchor: .top)
                }
            }
        }
        .confirmationDialog(
            removalCandidate.map { "Remove \($0.exercise.name)?" } ?? "",
            isPresented: Binding(
                get: { removalCandidate != nil },
                set: { if !$0 { removalCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove and delete sets", role: .destructive) {
                if let removalCandidate {
                    viewModel.removeExercise(removalCandidate)
                }
                removalCandidate = nil
            }
            .accessibilityIdentifier(
                "confirm-remove-exercise-\(removalCandidate?.exercise.name ?? "")"
            )
        } message: {
            if let removalCandidate {
                Text("\(CountPhrase.completedSets(removalCandidate.orderedSets.filter(\.done).count)) will be deleted and will not appear in History.")
            }
        }
        // The notes field raises the system keyboard, which would sit on top of
        // — and fight with — the set-entry keypad. Only one text-entry surface
        // can own the bottom of the screen, so taking notes yields the keypad.
        .onChange(of: focusedNoteID) { _, identifier in
            guard identifier != nil else {
                viewModel.persistChanges()
                return
            }
            coordinator.focus = nil
        }
    }

    // MARK: - Group banner

    /// Names the structure the page's exercises share, when they share one. A
    /// single straight-set exercise gets no banner: there is no structure to
    /// explain.
    @ViewBuilder
    private var groupBanner: some View {
        if let executionBlock {
            VStack(alignment: .leading, spacing: Spacing.m) {
                // The block names the page, at the same weight an exercise
                // names its own. This was a caption above a card inside a page
                // that contained only that card — three nested containers for
                // one thing, a shape inherited from the old list where a block
                // had to survive among seven collapsed exercises. On a pager it
                // *is* the page, so it gets the page's title slot and the
                // lifter's eye lands in the same place whatever kind of page
                // they swiped to.
                Text(executionBlock.kind.title)
                    .font(AppFont.stageTitle)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(executionBlock.kind.summary)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)

                WorkoutExecutionBlockCard(
                    block: executionBlock,
                    workout: workout,
                    onPersist: viewModel.persistChanges,
                    onRoundCompleted: { viewModel.startRest(after: executionBlock) },
                    onEdit: { onEditBlock(executionBlock) },
                    onRemove: { onRemoveBlock(executionBlock) }
                )
            }
            .accessibilityIdentifier("execution-block-page-\(executionBlock.id.uuidString)")
        } else if case .superset = page {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("SUPERSET", systemImage: AppIcon.relationship)
                    .font(AppFont.eyebrow)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameStrength)

                // The alternation rule, stated. `WorkoutFlowResolver` picks the
                // member with the fewest completed sets and suppresses rest
                // until the round is finished — behaviour the lifter will
                // otherwise experience as the app choosing an exercise for them
                // without saying why.
                Text("Alternate between these. Rest starts once every exercise has finished the round.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Exercise

    private func exerciseSection(for entry: ExerciseEntry) -> some View {
        let groups = StageSetGrouping.groups(for: entry.orderedSets)

        return VStack(alignment: .leading, spacing: Spacing.l) {
            hero(for: entry)
            currentSetSummary(for: entry)
            actionRail(for: entry)

            if let recommendation, recommendation.exercise.persistentModelID == entry.persistentModelID {
                ProgressionRecommendationCard(
                    exerciseName: entry.exercise.name,
                    state: recommendation.state,
                    onAction: { onRecommendationAction($0, entry) }
                )
            }

            ForEach(groups) { group in
                StageSetSection(
                    group: group,
                    exerciseEntry: entry,
                    viewModel: viewModel,
                    coordinator: coordinator,
                    unitSystem: unitSystem,
                    editingCompletedSetID: $editingCompletedSetID,
                    previousPerformance: viewModel.previousPerformance(for: entry),
                    onSetCompleted: { onSetCompleted(entry) },
                    isCollapsed: warmUpCollapseBinding(for: entry, groups: groups)
                )
            }

            if groups.isEmpty {
                emptySetState(for: entry)
            }
        }
        // A superset page stacks several of these; the divider is what keeps
        // one exercise's sets from reading as a continuation of the last.
        .padding(.bottom, entries.count > 1 ? Spacing.s : 0)
        .overlay(alignment: .bottom) {
            if entries.count > 1, entry.persistentModelID != entries.last?.persistentModelID {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
            }
        }
    }

    private func hero(for entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let roleEyebrow = roleEyebrow(for: entry) {
                Text(roleEyebrow)
                    .font(AppFont.micro)
                    .tracking(0.55)
                    .foregroundStyle(Color.trameStrength)
            }

            HStack(alignment: .top, spacing: Spacing.s) {
                Text(entry.occurrenceDisplayName)
                    .font(AppFont.stageTitle)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("active-exercise-\(entry.exercise.name)")

                Spacer(minLength: 0)

                if isComplete(entry) {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.trameCompleted)
                        .accessibilityLabel("Exercise complete")
                }
            }

            // Repeated per exercise even though the page banner already names
            // the structure: a superset page stacks both members, and "which
            // of these two am I looking at" is answered per heading, not once
            // at the top.
            if entry.supersetGroupID != nil {
                Label("Superset", systemImage: AppIcon.relationship)
                    .font(AppFont.eyebrow)
                    .foregroundStyle(Color.trameStrength)
                    .accessibilityIdentifier("superset-label-\(entry.exercise.name)")
            }

            if let original = entry.originalExerciseNameSnapshot,
               entry.selectedSubstituteExerciseIDSnapshot != nil {
                Label("Substituted for \(original)", systemImage: AppIcon.relationship)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
            }

            if let caption = loggingSemanticsCaption(for: entry) {
                Text(caption)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
            }

            prescriptionLine(for: entry)

            previousPerformanceLine(for: entry)

            // The note field used to sit here, expanded, on every page whether
            // or not a note existed — a permanent text field between the
            // prescription and the first set, on a screen whose whole job is
            // getting to the first set. It now appears only when it has
            // something to show or the lifter asked for it (the Note chip on
            // the action rail).
            if isNoteVisible(for: entry) {
                noteField(for: entry)
            }
        }
    }

    private func isNoteVisible(for entry: ExerciseEntry) -> Bool {
        expandedNoteIDs.contains(entry.persistentModelID)
            || !(entry.comment ?? "").isEmpty
    }

    /// The current prescription becomes the stage's dominant object instead of
    /// asking the lifter to find the active row in a table. The ledger remains
    /// below as performed history and correction context; this answer-sized
    /// strip is the glance layer used between sets.
    @ViewBuilder
    private func currentSetSummary(for entry: ExerciseEntry) -> some View {
        if let set = entry.orderedSets.first(where: { !$0.done }) {
            let metrics = stageMetrics(for: entry, set: set)
            VStack(alignment: .leading, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("SET \(set.orderIndex + 1) / \(entry.orderedSets.count)")
                        .font(AppFont.micro)
                        .tracking(0.8)
                        .foregroundStyle(Color.trameSubdued)

                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: Spacing.m) {
                                stageMetricBlocks(metrics)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxl) {
                                stageMetricBlocks(metrics)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Set \(set.orderIndex + 1) of \(entry.orderedSets.count). "
                        + metrics.map { "\($0.value) \($0.unit)" }.joined(separator: ", ")
                )
                .accessibilityIdentifier("current-set-summary-\(entry.exercise.name)")

                if set.resolvedSetMethod != .standard {
                    liveSegmentEditor(for: set)
                }
            }
            .padding(.vertical, Spacing.s)
        }
    }

    /// Advanced set methods are performed work, so their internal drops or
    /// clusters stay on the exercise stage instead of being hidden in a generic
    /// details sheet. Less frequent metadata remains in Advanced options.
    private func liveSegmentEditor(for set: ExerciseSet) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(set.resolvedSetMethod.title.uppercased())
                    .font(AppFont.eyebrow)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameText)
                Spacer()
                Text("\(set.orderedSegments.count) segments")
                    .font(AppFont.micro.monospacedDigit())
                    .foregroundStyle(Color.trameSubdued)
            }

            Text(set.resolvedSetMethod.detail)
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)

            ForEach(set.orderedSegments, id: \.persistentModelID) { segment in
                SetSegmentEditorRow(
                    segment: segment,
                    method: set.resolvedSetMethod,
                    canDelete: set.orderedSegments.count > set.resolvedSetMethod.minimumSegmentCount,
                    onPersist: { viewModel.persistChanges() }
                ) {
                    set.segments.removeAll { $0 === segment }
                    set.normalizeSegmentOrder()
                    viewModel.persistChanges()
                }
            }

            Button {
                set.segments.append(ExerciseSetSegment(
                    orderIndex: set.orderedSegments.count,
                    repetitions: set.repetitions,
                    weight: set.weight,
                    weightType: set.weightType
                ))
                viewModel.persistChanges()
            } label: {
                Label(set.resolvedSetMethod == .dropSet ? "Add drop" : "Add effort", systemImage: AppIcon.plus)
                    .font(AppFont.metadata)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.trameText)
            .accessibilityIdentifier("add-set-segment")
        }
        .padding(.top, Spacing.m)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active-set-segment-editor")
    }

    @ViewBuilder
    private func stageMetricBlocks(_ metrics: [StageMetric]) -> some View {
        ForEach(metrics) { metric in
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(metric.value)
                    .font(AppFont.metricHero)
                    .foregroundStyle(Color.trameText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(AppFont.micro)
                        .tracking(0.6)
                        .foregroundStyle(metric.isPrimary ? Color.trameStrength : Color.trameSubdued)
                        .textCase(.uppercase)
                }
            }
        }
    }

    private func stageMetrics(for entry: ExerciseEntry, set: ExerciseSet) -> [StageMetric] {
        let tracking = entry.trackingTypeSnapshot
        var metrics: [StageMetric] = []

        if tracking.usesWeight {
            metrics.append(StageMetric(
                id: "weight",
                value: set.weight > 0 ? Formatters.formatFloat(set.weight) : "—",
                unit: set.weight > 0 ? set.weightType.rawValue : "",
                isPrimary: true
            ))
        }
        if tracking.usesReps {
            metrics.append(StageMetric(
                id: "reps",
                value: set.repetitions > 0 ? Formatters.formatFloat(set.repetitions) : "—",
                unit: set.repetitions > 0 && entry.loggingSemanticsSnapshot.laterality == .unilateral
                    && entry.loggingSemanticsSnapshot.repCountingStyle == .perSide
                    ? String(localized: "reps / side")
                    : set.repetitions > 0 ? String(localized: "reps") : "",
                isPrimary: metrics.isEmpty
            ))
        }
        if tracking.usesDuration {
            metrics.append(StageMetric(
                id: "duration",
                value: (set.duration ?? 0) > 0
                    ? Formatters.formatFloat(Float(set.duration ?? 0))
                    : "—",
                unit: (set.duration ?? 0) > 0 ? String(localized: "sec") : "",
                isPrimary: metrics.isEmpty
            ))
        }
        if tracking.usesDistance {
            metrics.append(StageMetric(
                id: "distance",
                value: (set.distance ?? 0) > 0 ? Formatters.formatFloat(set.distance ?? 0) : "—",
                unit: (set.distance ?? 0) > 0 ? set.distanceType.rawValue : "",
                isPrimary: metrics.isEmpty
            ))
        }
        if tracking.usesCalories {
            metrics.append(StageMetric(
                id: "calories",
                value: (set.calories ?? 0) > 0
                    ? Formatters.formatFloat(Float(set.calories ?? 0))
                    : "—",
                unit: (set.calories ?? 0) > 0 ? String(localized: "cal") : "",
                isPrimary: metrics.isEmpty
            ))
        }
        return metrics
    }

    /// The prescription as one subdued line.
    ///
    /// This was a `ChipFlowLayout` of outlined chips, on the reasoning that a
    /// lifter wants one value at a time and separated chips scan better than a
    /// run-on line. The reasoning was right about scanning and wrong about
    /// cost: three chips claimed a full row plus its spacing, they re-measured
    /// on every body pass while the pager was mid-swipe, and — worst — an
    /// outlined capsule is the app's own vocabulary for *tappable*, which none
    /// of these are. A lifter tapping "RPE 7" to change it gets nothing.
    ///
    /// One tabular line at caption weight scans just as well at half the height
    /// and makes no promise it cannot keep.
    @ViewBuilder
    private func prescriptionLine(for entry: ExerciseEntry) -> some View {
        let values = prescriptionValues(for: entry)
        if !values.isEmpty {
            Text(values.joined(separator: " · "))
                .font(AppFont.caption)
                .monospacedDigit()
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text("Target: \(values.joined(separator: ", "))"))
                .accessibilityIdentifier("prescription-summary-\(entry.exercise.name)")
        }
    }

    private func prescriptionValues(for entry: ExerciseEntry) -> [String] {
        let trackingType = entry.trackingTypeSnapshot
        var chips: [String] = []

        if let setCount = entry.prescribedSets {
            if trackingType.usesCalories,
               let calories = entry.orderedSets.first?.prescribedCaloriesSnapshot {
                chips.append("\(setCount) × \(Formatters.formatFloat(Float(calories))) cal")
            } else if trackingType.usesDuration,
                      let seconds = entry.orderedSets.first?.prescribedDurationSecondsSnapshot {
                chips.append("\(setCount) × \(Int(seconds)) sec")
            } else if trackingType.usesDistance,
                      let meters = entry.orderedSets.first?.prescribedDistanceMetersSnapshot {
                chips.append("\(setCount) × \(Formatters.formatFloat(Float(meters))) m")
            } else if let minimum = entry.prescribedRepRangeMinimum,
                      let maximum = entry.prescribedRepRangeMaximum {
                chips.append("\(setCount) × \(minimum)-\(maximum)")
            } else {
                chips.append("\(setCount) sets")
            }
        }

        if let load = entry.prescribedSuggestedLoad, let unit = entry.prescribedSuggestedLoadType {
            chips.append("\(Formatters.formatFloat(Float(load))) \(unit.rawValue)")
        }
        if let rpe = entry.prescribedRPE {
            chips.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        }
        if let rir = entry.prescribedRIR {
            chips.append("RIR \(rir)")
        }
        if let tempo = entry.orderedSets.first?.prescribedTempo,
           !tempo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chips.append("Tempo \(tempo)")
        }
        if let rest = entry.prescribedRestSeconds, rest > 0 {
            chips.append("Rest \(rest / 60):\(String(format: "%02d", rest % 60))")
        }
        return chips
    }

    @ViewBuilder
    private func previousPerformanceLine(for entry: ExerciseEntry) -> some View {
        if let performance = viewModel.previousPerformance(for: entry) {
            Label(
                previousPerformanceSummary(performance, for: entry),
                systemImage: AppIcon.history
            )
            .font(AppFont.caption)
            .foregroundStyle(Color.trameSubdued)
            .accessibilityIdentifier("previous-performance-\(entry.exercise.name)")
        } else {
            Label("No previous session logged for this exercise", systemImage: AppIcon.history)
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
        }
    }

    private func previousPerformanceSummary(
        _ performance: PreviousExercisePerformance,
        for entry: ExerciseEntry
    ) -> String {
        let trackingType = entry.trackingTypeSnapshot
        let date = performance.workoutDate.formatted(.dateTime.month(.abbreviated).day())
        let sets = performance.sets
        guard let first = sets.first else { return String(localized: "Last time: \(date)") }

        if trackingType.usesWeight {
            let matchingReps = sets.allSatisfy { $0.repetitions == first.repetitions }
            let matchingWeight = sets.allSatisfy { $0.weight == first.weight && $0.weightType == first.weightType }
            if matchingReps && matchingWeight {
                return String(localized: "Last time: \(sets.count) × \(Formatters.formatFloat(first.repetitions)) @ \(Formatters.formatFloat(first.weight)) \(first.weightType.rawValue) · \(date)")
            }
            return String(localized: "Last time: \(sets.count) sets · up to \(Formatters.formatFloat(sets.map(\.weight).max() ?? 0)) \(first.weightType.rawValue) · \(date)")
        }
        if trackingType.usesReps {
            return String(localized: "Last time: \(sets.count) × \(Formatters.formatFloat(first.repetitions)) reps · \(date)")
        }
        return String(localized: "Last time: \(sets.count) sets · \(date)")
    }

    /// Inline, always present, and empty by default — the reference behaviour a
    /// lifter expects from "tap here to add a note". Behind a menu item it
    /// would be a feature nobody finds mid-session, which is the only time a
    /// cue like "belt from set 3" is worth writing down.
    private func noteField(for entry: ExerciseEntry) -> some View {
        TextField(
            "Add a note for this exercise",
            text: noteBinding(for: entry),
            axis: .vertical
        )
        .font(AppFont.footnote)
        .foregroundStyle(Color.trameText)
        .lineLimit(1...4)
        .focused($focusedNoteID, equals: entry.persistentModelID)
        .padding(.vertical, Spacing.s)
        .padding(.horizontal, Spacing.m)
        .background(Color.trameRow, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .stroke(Color.trameSeparator, lineWidth: 1)
        }
        .accessibilityLabel(Text("Note for \(entry.exercise.name)"))
        .accessibilityIdentifier("exercise-note-\(entry.exercise.name)")
    }

    private func noteBinding(for entry: ExerciseEntry) -> Binding<String> {
        Binding(
            get: { entry.comment ?? "" },
            // Writes through the model's own mutation guard rather than the
            // stored property, so a note cannot be edited into a workout that
            // has already been saved.
            set: { _ = entry.updateComment($0.isEmpty ? nil : $0) }
        )
    }

    // MARK: - Action rail

    /// Frequent contextual actions remain directly reachable, but they sit as
    /// open commands rather than a row of pill-shaped objects. Structural and
    /// destructive changes stay progressively disclosed in the menu.
    private func actionRail(for entry: ExerciseEntry) -> some View {
        HStack(spacing: Spacing.s) {
            if entry.orderedSets.filter(\.done).isEmpty {
                railButton("Swap", systemImage: AppIcon.relationship, identifier: "swap-exercise-\(entry.exercise.name)") {
                    onSwapRequested(entry)
                }
            }

            railButton(
                isNoteVisible(for: entry) ? "Hide note" : "Note",
                systemImage: AppIcon.edit,
                identifier: "toggle-note-\(entry.exercise.name)"
            ) {
                let identifier = entry.persistentModelID
                withAnimation(reduceMotion ? nil : AppMotion.layout) {
                    if expandedNoteIDs.contains(identifier) {
                        expandedNoteIDs.remove(identifier)
                    } else {
                        expandedNoteIDs.insert(identifier)
                    }
                }
            }

            // Everything structural or destructive, behind one chip.
            //
            // These were four more capsules in a horizontally scrolling rail
            // that clipped "Remove" mid-word at the default text size, and put
            // a destructive action one mistap from the most-used one. They are
            // all real actions and none of them is an in-set action.
            Menu {
                if canMove(entry, -1) {
                    Button {
                        onMove(entry, -1)
                    } label: {
                        Label("Move up", systemImage: AppIcon.chevronUp)
                    }
                    .accessibilityIdentifier("move-exercise-up-\(entry.exercise.name)")
                }
                if canMove(entry, 1) {
                    Button {
                        onMove(entry, 1)
                    } label: {
                        Label("Move down", systemImage: AppIcon.chevronDown)
                    }
                    .accessibilityIdentifier("move-exercise-down-\(entry.exercise.name)")
                }

                if entry.executionBlockID == nil {
                    if entry.supersetGroupID == nil, !supersetCandidates(for: entry).isEmpty {
                        Menu {
                            ForEach(supersetCandidates(for: entry), id: \.persistentModelID) { candidate in
                                Button(candidate.occurrenceDisplayName) {
                                    viewModel.superset(entry, with: candidate)
                                }
                            }
                        } label: {
                            Label("Superset with…", systemImage: "link")
                        }
                        .accessibilityIdentifier("superset-with-\(entry.exercise.name)")
                    } else if entry.supersetGroupID != nil {
                        Button {
                            viewModel.removeFromSuperset(entry)
                        } label: {
                            Label("Unlink from superset", systemImage: "link.badge.plus")
                        }
                        .accessibilityIdentifier("remove-from-superset-\(entry.exercise.name)")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if entry.orderedSets.contains(where: \.done) {
                            removalCandidate = entry
                        } else {
                            viewModel.removeExercise(entry)
                        }
                    } label: {
                        Label("Remove exercise", systemImage: AppIcon.trash)
                    }
                    .accessibilityIdentifier("remove-exercise-\(entry.exercise.name)")
                }
            } label: {
                railLabel("More", systemImage: AppIcon.ellipsis)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("More actions for \(entry.exercise.name)"))
            .accessibilityIdentifier("exercise-actions-\(entry.exercise.name)")

            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
        }
    }

    private func railButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        identifier: String,
        tint: Color = .trameSubdued,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            railLabel(title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(identifier)
    }

    private func railLabel(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color = .trameSubdued
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.metadata)
            .foregroundStyle(tint)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .padding(.horizontal, Spacing.s)
            .contentShape(Rectangle())
    }

    private func supersetCandidates(for entry: ExerciseEntry) -> [ExerciseEntry] {
        workout.orderedExercises.filter {
            $0.persistentModelID != entry.persistentModelID
                && $0.supersetGroupID == nil
                && $0.executionBlockID == nil
        }
    }

    // MARK: - Supporting views

    private func emptySetState(for entry: ExerciseEntry) -> some View {
        VStack(spacing: Spacing.m) {
            Text("No sets yet.")
                .font(AppFont.footnote)
                .foregroundStyle(Color.trameSubdued)
            Button {
                viewModel.addSet(entry)
            } label: {
                Label("Add the first set", systemImage: AppIcon.plus)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameStrength)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("add-set-\(entry.exercise.name)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // `addExerciseButton` used to close every page as a full-width filled
    // button. It was the loudest control on the stage while being the rarest
    // action on it, and it outranked the command bar's actual primary — the one
    // the lifter presses eight to thirty times a session. The same action
    // already lives in the session's `⋯` menu, so this was a duplicate that
    // cost a row and won the visual hierarchy.
    //
    // `onAddExercise` stays on the call site: the empty-set state below still
    // needs a route to it, and removing the parameter would churn the pager.

    // MARK: - Derived state

    private func isComplete(_ entry: ExerciseEntry) -> Bool {
        !entry.sets.isEmpty && entry.orderedSets.allSatisfy(\.done)
    }

    /// Named only where the role changes what the lifter should do. The
    /// preparation warning is the one that carries a safety instruction, and
    /// "main lift" tells them this is the set worth the full rest; secondary
    /// and accessory work needs no label to be understood.
    private func roleEyebrow(for entry: ExerciseEntry) -> String? {
        guard let role = entry.prescribedRole else { return nil }
        switch role {
        case .preparation: return String(localized: "PREPARATION · STOP IF PAIN APPEARS")
        case .main: return String(localized: "MAIN LIFT")
        case .secondary, .accessory: return nil
        }
    }

    private func loggingSemanticsCaption(for entry: ExerciseEntry) -> String? {
        let semantics = entry.loggingSemanticsSnapshot
        var parts: [String] = []
        if semantics.laterality == .unilateral && semantics.repCountingStyle == .perSide {
            parts.append(String(localized: "Logged per side"))
        }
        if semantics.weightEntryStyle == .perLoadUnit {
            parts.append(String(localized: "Weight per unit (×\(semantics.loadUnitCount))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func warmUpCollapseBinding(
        for entry: ExerciseEntry,
        groups: [StageSetGrouping.Group]
    ) -> Binding<Bool> {
        Binding(
            get: {
                warmUpCollapseOverrides[entry.persistentModelID]
                    ?? StageSetGrouping.shouldCollapseWarmUp(groups)
            },
            set: { warmUpCollapseOverrides[entry.persistentModelID] = $0 }
        )
    }
}

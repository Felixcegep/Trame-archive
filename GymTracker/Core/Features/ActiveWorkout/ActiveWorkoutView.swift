import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ActiveWorkoutView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [ActiveWorkoutRoute]
    let modelContext: ModelContext
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    let onDiscardRequested: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ActiveWorkoutViewModel
    @State private var expandedExerciseID: PersistentIdentifier?
    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingExercisePicker = false
    @State private var coordinator = SetInputCoordinator()
    @State private var draggedExercise: ExerciseEntry? = nil
    @State private var handledRecommendationExerciseIDs: Set<PersistentIdentifier> = []
    @State private var editingCompletedSetID: PersistentIdentifier?
    @State private var exerciseToSwap: ExerciseEntry?
    @State private var isShowingExecutionBlockBuilder = false
    @State private var executionBlockToEdit: WorkoutExecutionBlock?

    private var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
    }

    init(
        workoutVM: WorkoutViewModel,
        navigationPath: Binding<[ActiveWorkoutRoute]>,
        modelContext: ModelContext,
        activeLoggingMetrics: ActiveLoggingMetricsRecorder,
        onDiscardRequested: @escaping () -> Void
    ) {
        self.workoutVM = workoutVM
        _navigationPath = navigationPath
        self.modelContext = modelContext
        self.activeLoggingMetrics = activeLoggingMetrics
        self.onDiscardRequested = onDiscardRequested
        _viewModel = State(initialValue: ActiveWorkoutViewModel(
            workoutVM: workoutVM,
            modelContext: modelContext,
            activeLoggingMetrics: activeLoggingMetrics
        ))
    }

    var body: some View {
        Group {
            if let workout = viewModel.activeWorkout {
                workoutContent(for: workout)
            } else {
                ContentUnavailableView(
                    "No active workout",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Start a workout from Home to log your sets.")
                )
            }
        }
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground.ignoresSafeArea())
        .tint(Color.gymPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.gymBackground, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    activeLoggingMetrics.workoutMinimized()
                    dismiss()
                } label: {
                    Image(systemName: AppIcon.minimize)
                        .fontWeight(.semibold)
                }
                .accessibilityIdentifier("minimize-workout")
            }

            ToolbarItem(placement: .topBarTrailing) {
                // Discard lives behind this menu rather than as a permanent
                // trash button: losing the session is the rarest action here
                // and must not sit one mistaken tap from the set logging.
                Menu {
                    Button(role: .destructive) {
                        isShowingDiscardConfirmation = true
                    } label: {
                        Label("Discard workout", systemImage: AppIcon.trash)
                    }
                    .accessibilityIdentifier("discard-workout")
                } label: {
                    Image(systemName: AppIcon.ellipsis)
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Workout actions")
                .accessibilityIdentifier("active-workout-menu")
            }
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
                .accessibilityIdentifier("confirm-discard-workout")
        } message: {
            Text(discardConfirmationMessage)
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                ExerciseLibraryView(
                    isSelectingExercise: true,
                    availableExercises: exerciseTemplates,
                    addedExerciseIDs: Set(viewModel.activeWorkout?.orderedExercises.map(\.exercise.id) ?? []),
                    onSelect: addExerciseFromPicker
                )
            }
        }
        .sheet(item: $exerciseToSwap) { exerciseEntry in
            NavigationStack {
                ExerciseSwapPicker(
                    exerciseEntry: exerciseEntry,
                    planGoal: viewModel.activePlanGoal()
                ) { replacement, decision in
                    guard viewModel.swapExercise(
                        exerciseEntry,
                        with: replacement,
                        decision: decision
                    ) else { return }
                    // Future-plan scope is applied only after today's swap
                    // succeeds, and only when the lifter explicitly chose it.
                    if decision.scope == .futurePlan {
                        viewModel.applyPlanSubstitution(exerciseEntry, with: replacement)
                    }
                    expandedExerciseID = exerciseEntry.persistentModelID
                    editingCompletedSetID = nil
                }
            }
        }
        .sheet(isPresented: $isShowingExecutionBlockBuilder) {
            if let workout = viewModel.activeWorkout {
                WorkoutExecutionBlockBuilderSheet(workout: workout) {
                    viewModel.persistChanges()
                }
            }
        }
        .sheet(item: $executionBlockToEdit) { block in
            if let workout = viewModel.activeWorkout {
                WorkoutExecutionBlockBuilderSheet(workout: workout, blockToEdit: block) {
                    viewModel.persistChanges()
                }
            }
        }
        .onDisappear {
            viewModel.persistChanges()
        }
        .onAppear {
            viewModel.loadPreviousPerformances()
        }
        .onChange(of: expandedExerciseID) { _, identifier in
            editingCompletedSetID = nil
            viewModel.trackActiveExercise(with: identifier)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.restorePersistedRestTimer()
            }
        }
    }

    private func workoutContent(for workout: Workout) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    sessionHeader(for: workout)

                    if !workout.orderedExecutionBlocks.isEmpty {
                        executionBlocks(for: workout)
                    }

                    exerciseList(for: workout)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(Color.gymBackground)
            .safeAreaInset(edge: .top) {
                // Pinned, not scrolled. Rest matters precisely when the session
                // is long enough to scroll, which is exactly when the old
                // in-content card was off screen.
                if viewModel.isTimerVisible && viewModel.hasIncompleteSet {
                    // A paused timer has no end date; the paused branch renders
                    // the saved remaining duration instead of this placeholder.
                    RestStatusStrip(
                        viewModel: viewModel,
                        activeLoggingMetrics: activeLoggingMetrics,
                        endDate: viewModel.timerPause ?? .now,
                        nextSetDescription: nextSetDescription,
                        isCompact: coordinator.focus != nil,
                        onStartNextSet: startNextSet
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : AppMotion.compact, value: viewModel.isTimerVisible)
            // Attached to the list, not the strip: the strip is removed the
            // instant rest ends, and the completion signal must outlive it.
            // `restCompletionCount` only increments from a countdown reaching
            // its deadline, never from restoring a rest that expired while the
            // app was away.
            .gymFeedback(.restReady, trigger: viewModel.restCompletionCount)
            .onChange(of: viewModel.restCompletionCount) { _, _ in
                GymAnnouncement.post(restCompletionAnnouncement)
            }
            .safeAreaInset(edge: .bottom) {
                if coordinator.focus == nil {
                    finishButton(for: workout)
                } else {
                    // SwiftUI's keyboard avoidance lifts a bottom safe-area inset
                    // above the keypad, so the panel rides on top of it without
                    // any manual height math.
                    SetInputAccessoryPanel(
                        viewModel: viewModel,
                        coordinator: coordinator,
                        unitSystem: unitSystem,
                        onSetCompleted: { exercise in
                            viewModel.startTime(after: exercise)
                            advanceDisclosure(after: exercise, in: workout)
                        }
                    )
                }
            }
            .onChange(of: coordinator.focus) { _, focus in
                guard let focus else { return }
                coordinator.refreshOrder(in: viewModel.activeWorkout)
                if let models = viewModel.models(for: focus) {
                    activeLoggingMetrics.focusChanged(
                        to: models.set.id,
                        field: focus.field,
                        replacesExistingValue: hasEnteredValue(for: focus.field, in: models.set)
                    )
                }
                withAnimation(reduceMotion ? nil : AppMotion.layout) {
                    // Anchor at the top: the panel plus keypad claims roughly half
                    // the screen, so centering would hide the row being edited.
                    proxy.scrollTo(focus.setID, anchor: .top)
                }
            }
            .onChange(of: workout.completedSetCount) { _, _ in
                // Completing the final set (even mid-rest) ends the workout, so
                // end any running rest and let the rest card fall away.
                if viewModel.isTimerVisible && !viewModel.hasIncompleteSet {
                    viewModel.cancelTimer()
                }
            }
        }
        .onAppear {
            selectInitialDisclosure(in: workout)
            viewModel.trackActiveExercise(with: expandedExerciseID)
            viewModel.restorePersistedRestTimer()
        }
    }

    private func inputFields(for exercise: ExerciseEntry) -> [SetInputFocus.Field] {
        SetInputCoordinator.inputFields(for: exercise.trackingTypeSnapshot)
    }

    private func hasEnteredValue(for field: SetInputFocus.Field, in set: ExerciseSet) -> Bool {
        switch field {
        case .repetitions: set.repetitions > 0
        case .weight: set.weight > 0
        case .duration: (set.duration ?? 0) > 0
        case .distance: (set.distance ?? 0) > 0
        case .calories: (set.calories ?? 0) > 0
        }
    }

    /// Session identity and progress in two lines of page chrome rather than a
    /// card. The workout name, elapsed time, and remaining work are supporting
    /// metadata; the current exercise is the screen's subject and should be
    /// reachable without scrolling past a tall summary.
    private func sessionHeader(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(workout.name?.isEmpty == false ? workout.name! : "Today’s workout")
                    .font(AppFont.titleSmall)
                    .lineLimit(2)
                    .accessibilityIdentifier("active-workout-title")

                if workout.sourceTemplate?.isBuiltIn == true {
                    BuiltInBadge()
                }

                Spacer(minLength: Spacing.s)

                Text(workout.startTime, style: .timer)
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityLabel("Elapsed time")
            }

            sessionProgressSummary(for: workout)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)

            if let repeatingPlanName = repeatingPlanName(for: workout) {
                Label("Rotation: \(repeatingPlanName)", systemImage: AppIcon.routine)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSecondary)
                    .accessibilityLabel(
                        "Rotation \(repeatingPlanName). It advances only after this workout is saved successfully."
                    )
            }

            ProgressView(value: Double(workout.completedSetCount), total: Double(max(workout.totalSetCount, 1)))
                .tint(Color.gymSecondary)
                // The summary line above states the same progress in words, so
                // the bar is a visual restatement rather than a second stop.
                .accessibilityHidden(true)
        }
    }

    /// Built as `Text` rather than `String` so the exercise count keeps its
    /// automatic grammatical agreement in every localization.
    ///
    /// One `Text` per branch rather than concatenated fragments: `Text + Text`
    /// is deprecated on iOS 26, and the inflection markup resolves inside a
    /// single interpolated key anyway. Keeping the whole sentence in one key
    /// also gives translators the surrounding context the fragments withheld.
    @ViewBuilder
    private func sessionProgressSummary(for workout: Workout) -> some View {
        if workout.totalSetCount == 0 {
            Text("No exercises yet.")
        } else if workout.exercises.isEmpty {
            Text("\(workout.completedSetCount) / \(workout.totalSetCount) sets")
        } else {
            Text("\(workout.completedSetCount) / \(workout.totalSetCount) sets · ^[\(workout.exercises.count) exercise](inflect: true)")
        }
    }

    private func repeatingPlanName(for workout: Workout) -> String? {
        guard let name = workout.sourceRepeatingPlanName?
            .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else {
            return nil
        }
        return name
    }

    private var discardConfirmationMessage: String {
        guard
            let workout = viewModel.activeWorkout,
            let repeatingPlanName = repeatingPlanName(for: workout)
        else {
            return String(localized: "Your logged sets and notes will not be saved.")
        }
        return String(
            localized: "Your logged sets and notes will not be saved. \(repeatingPlanName) will not advance."
        )
    }

    /// Spoken at the deadline. Names what to do next rather than only that rest
    /// is over, because that is the question the lifter actually has.
    private var restCompletionAnnouncement: String {
        guard let next = nextSetDescription else {
            return String(localized: "Rest complete.")
        }
        return String(localized: "Rest complete. \(next)")
    }

    /// "Next: Lat Pulldown · Set 2" — names the exercise and set the lifter will
    /// resume with, derived from the same next-incomplete-set selector the rest
    /// of Active Workout uses. Returns nil when nothing is left to do.
    private var nextSetDescription: String? {
        guard let next = viewModel.getNextExerciseToDo() else { return nil }
        let setNumber = (next.exercise.orderedSets.firstIndex {
            $0.persistentModelID == next.set.persistentModelID
        } ?? 0) + 1
        return String(localized: "Next: \(next.exercise.exercise.name) · Set \(setNumber)")
    }

    /// Ends the rest period and moves the lifter to the next incomplete set:
    /// expands that exercise and focuses its first editable value. Setting
    /// `focusedInput` also drives the existing scroll-to-focus behavior.
    private func startNextSet() {
        guard let next = viewModel.getNextExerciseToDo() else {
            viewModel.cancelTimer()
            return
        }
        viewModel.cancelTimer()
        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            expandedExerciseID = next.exercise.persistentModelID
        }
        let firstField = inputFields(for: next.exercise).first ?? .repetitions
        coordinator.focus = SetInputFocus(
            exerciseID: next.exercise.persistentModelID,
            setID: next.set.persistentModelID,
            field: firstField
        )
    }

    private func exerciseList(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("SESSION")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)

                Spacer()

                if !workout.exercises.isEmpty {
                    // Both were bare labels, so their hit areas were the text
                    // itself — roughly 20pt tall, in the session header.
                    Button {
                        isShowingExecutionBlockBuilder = true
                    } label: {
                        Label("Block", systemImage: AppIcon.relationship)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymPrimary)
                            .frame(minHeight: ComponentSize.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("add-execution-block")

                    Button {
                        isShowingExercisePicker = true
                    } label: {
                        Label("Add", systemImage: AppIcon.plus)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymPrimary)
                            .frame(minHeight: ComponentSize.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("add-active-exercise")
                }
            }

            if workout.exercises.isEmpty {
                emptyExerciseState
            } else {
                let preparation = workout.orderedExercises.filter { $0.prescribedRole == .preparation }
                let training = workout.orderedExercises.filter { $0.prescribedRole != .preparation }

                // Sub-headers only earn their place when there are two groups
                // to tell apart. A session with no preparation work used to
                // render "SESSION" and then "EXERCISES" directly beneath it —
                // two headings, one meaning, and a level of hierarchy the
                // content never asked for. With one group, "SESSION" leads the
                // cards on its own.
                if preparation.isEmpty {
                    exerciseCards(for: training, in: workout)
                } else {
                    sessionSectionHeader(
                        title: "PREPARATION & MOBILITY",
                        detail: "Complete first · stop if pain appears",
                        icon: AppIcon.info
                    )
                    exerciseCards(for: preparation, in: workout)

                    if !training.isEmpty {
                        sessionSectionHeader(
                            title: "STRENGTH WORK",
                            detail: "After preparation",
                            icon: AppIcon.workout
                        )
                        exerciseCards(for: training, in: workout)
                    }
                }
            }
        }
    }

    private func executionBlocks(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sessionSectionHeader(
                title: "EXECUTION BLOCKS",
                detail: "Track shared rounds, clock, and score",
                icon: AppIcon.relationship
            )
            ForEach(workout.orderedExecutionBlocks, id: \.persistentModelID) { block in
                WorkoutExecutionBlockCard(
                    block: block,
                    workout: workout,
                    onPersist: viewModel.persistChanges,
                    onRoundCompleted: {
                        viewModel.startRest(after: block)
                    },
                    onEdit: {
                        executionBlockToEdit = block
                    },
                    onRemove: {
                        WorkoutExecutionBlockService.remove(block, from: workout)
                        modelContext.delete(block)
                        viewModel.persistChanges()
                    }
                )
            }
        }
    }

    private func sessionSectionHeader(title: String, detail: String?, icon: String) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: icon)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSecondary)

            Text(title)
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            if let detail {
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func exerciseCards(for exercises: [ExerciseEntry], in workout: Workout) -> some View {
        let recommendation = firstRecommendation(in: workout)

        ForEach(exercises, id: \.persistentModelID) { exercise in
            ExerciseEntryCard(
                exerciseEntry: exercise,
                executionBlock: workout.orderedExecutionBlocks.first { $0.id == exercise.executionBlockID },
                viewModel: viewModel,
                onButtonPress: { viewModel.startTime(after: exercise) },
                unitSystem: unitSystem,
                coordinator: coordinator,
                expandedExerciseID: $expandedExerciseID,
                editingCompletedSetID: $editingCompletedSetID,
                previousPerformance: viewModel.previousPerformance(for: exercise),
                onExerciseCompleted: {
                    advanceDisclosure(after: exercise, in: workout)
                },
                onSwapRequested: {
                    exerciseToSwap = exercise
                },
                supersetCandidates: workout.orderedExercises.filter {
                    $0.persistentModelID != exercise.persistentModelID && $0.supersetGroupID == nil
                },
                // At most one exercise carries the recommendation, so the
                // evidence appears exactly once and inside the exercise it
                // describes.
                recommendationState: recommendation?.exercise.persistentModelID == exercise.persistentModelID
                    ? recommendation?.state
                    : nil,
                onRecommendationAction: { action in
                    handleRecommendationAction(action, for: exercise)
                },
                onMoveUp: canMove(exercise, by: -1, in: workout)
                    ? { move(exercise, by: -1, in: workout) }
                    : nil,
                onMoveDown: canMove(exercise, by: 1, in: workout)
                    ? { move(exercise, by: 1, in: workout) }
                    : nil
            )
            .onDrag {
                self.draggedExercise = exercise
                return NSItemProvider(object: String(describing: exercise.persistentModelID) as NSString)
            }
            .onDrop(of: [.text], delegate: ExerciseDragDelegate(
                item: exercise,
                workout: workout,
                viewModel: viewModel,
                draggedItem: $draggedExercise,
                reduceMotion: reduceMotion
            ))
        }
    }

    private func canMove(_ exercise: ExerciseEntry, by offset: Int, in workout: Workout) -> Bool {
        let ordered = workout.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.persistentModelID == exercise.persistentModelID })
        else { return false }
        return ordered.indices.contains(index + offset)
    }

    /// The non-drag reorder path. Writes the same `orderIndex` sequence the
    /// drag delegate does and animates identically, so the two are
    /// indistinguishable in result — and announces the new position, which the
    /// drag never did either.
    private func move(_ exercise: ExerciseEntry, by offset: Int, in workout: Workout) {
        var ordered = workout.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.persistentModelID == exercise.persistentModelID }),
              ordered.indices.contains(index + offset)
        else {
            return
        }

        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            let moved = ordered.remove(at: index)
            ordered.insert(moved, at: index + offset)
            for (position, entry) in ordered.enumerated() {
                entry.orderIndex = position
            }
            viewModel.persistChanges()
        }

        GymAnnouncement.post(
            String(
                localized: "\(exercise.exercise.name) moved to position \(index + offset + 1) of \(ordered.count)."
            )
        )
    }

    private var emptyExerciseState: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.workout)
                .font(AppFont.displayLarge)
                .foregroundStyle(Color.gymSecondary)
            Text("Add your first exercise.")
                .font(AppFont.headline)
                .foregroundStyle(Color.gymText)
            Button {
                isShowingExercisePicker = true
            } label: {
                Text("Browse exercise library")
            }
            .buttonStyle(.gymPrimary)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("add-active-exercise")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl + 2)
        .background(Color.gymMutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private func finishButton(for workout: Workout) -> some View {
        if workout.exercises.isEmpty {
            EmptyView()
        } else {
            VStack {
                Button {
                    viewModel.cancelTimer()
                    navigationPath.append(.saveWorkout)
                } label: {
                    // "Finish workout", not "Review Workout": mid-session this
                    // is the button that *ends* the session, and naming it
                    // after the screen it happens to open described the
                    // navigation rather than the act. The destination is still
                    // titled "Review and save", so nothing is lost — the
                    // review step is announced on arrival instead of standing
                    // in for the intent.
                    Label("Finish workout", systemImage: AppIcon.checkmark)
                }
                .buttonStyle(.gymPrimaryProminent)
                .disabled(workout.completedSetCount == 0)
                .accessibilityHint(workout.completedSetCount == 0 ? "Complete at least one set before finishing." : "Review and save your workout.")

                // A disabled control has to say why. This was previously
                // carried only by an accessibility hint, which a sighted user
                // never receives.
                if workout.completedSetCount == 0 {
                    Text("Complete at least one set to finish.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .background(Color.gymBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.gymBorder)
                    .frame(height: 1)
            }
        }
    }



    private func selectInitialDisclosure(in workout: Workout) {
        guard expandedExerciseID == nil else { return }
        expandedExerciseID = WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry.persistentModelID
    }

    /// Where to open next after a set is completed.
    ///
    /// This used to hand back whatever `WorkoutSetSelector` considered the
    /// workout's next incomplete set, which is the *first* one in document
    /// order. A lifter who skipped ahead because a rack was busy would complete
    /// a set on exercise four and watch the app collapse it and reopen exercise
    /// one — every single set. Working out of order is normal in a shared gym,
    /// and the app already permits it: any card can be opened by tapping.
    ///
    /// So an exercise that still has work keeps the disclosure. Supersets are
    /// excluded, because there the selector's alternation between members is
    /// the point rather than an interruption.
    private func advanceDisclosure(after completedExercise: ExerciseEntry, in workout: Workout) {
        let staysOnCurrent = completedExercise.supersetGroupID == nil
            && completedExercise.orderedSets.contains { !$0.done }

        let nextExercise = staysOnCurrent
            ? completedExercise
            : WorkoutSetSelector.nextEntry(afterCompleting: completedExercise, in: workout)

        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            expandedExerciseID = nextExercise?.persistentModelID
        }
    }

    /// The picker adds only. It used to toggle, so tapping an exercise that
    /// was already in the session deleted it along with every set logged
    /// against it — from a sheet where none of that work was on screen.
    /// Removal now lives solely on the exercise's own card, which confirms and
    /// names what would be lost.
    private func addExerciseFromPicker(_ exercise: Exercise) {
        guard viewModel.activeWorkout?.orderedExercises.contains(where: { $0.exercise.id == exercise.id }) != true else {
            return
        }
        viewModel.addExercise(exercise)
        expandedExerciseID = viewModel.activeWorkout?.orderedExercises.last?.persistentModelID
    }

    private func discardWorkout() {
        viewModel.cancelTimer()
        navigationPath.removeAll()
        onDiscardRequested()
    }

    private func firstRecommendation(
        in workout: Workout
    ) -> (exercise: ExerciseEntry, state: RecommendationPresentationState)? {
        for exercise in workout.orderedExercises {
            guard
                !handledRecommendationExerciseIDs.contains(exercise.persistentModelID),
                !exercise.orderedSets.contains(where: \.done),
                let state = RecommendationPresentationState(entry: exercise)
            else {
                continue
            }
            return (exercise, state)
        }
        return nil
    }

    private func handleRecommendationAction(
        _ action: RecommendationAction,
        for exercise: ExerciseEntry
    ) {
        switch action {
        case .accept:
            viewModel.applyRecommendation(to: exercise)
            // Rewrites the load of every incomplete set, which can include the
            // one the panel is showing typed digits for.
            coordinator.endEntry(ifEditing: .weight)
        case .keepLast:
            viewModel.applyPriorRecommendationLoad(to: exercise)
            coordinator.endEntry(ifEditing: .weight)
        case .edit:
            expandedExerciseID = exercise.persistentModelID
            if let set = exercise.orderedSets.first(where: { !$0.done }) {
                coordinator.focus = SetInputFocus(
                    exerciseID: exercise.persistentModelID,
                    setID: set.persistentModelID,
                    field: exercise.trackingTypeSnapshot.usesWeight ? .weight : .repetitions
                )
            }
        }
        handledRecommendationExerciseIDs.insert(exercise.persistentModelID)
    }
}

struct ExerciseDragDelegate: DropDelegate {
    let item: ExerciseEntry
    let workout: Workout
    let viewModel: ActiveWorkoutViewModel
    @Binding var draggedItem: ExerciseEntry?
    let reduceMotion: Bool

    /// The drop is the commit.
    ///
    /// `dropEntered` fires once per card the finger passes over, and it used to
    /// persist each time — so dragging across four positions wrote four
    /// orderings. The live reorder still happens there, because that is the
    /// feedback that makes the gesture legible; only the write moved here.
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        viewModel.persistChanges()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem, draggedItem.persistentModelID != item.persistentModelID else { return }
        let exercises = workout.orderedExercises
        guard let from = exercises.firstIndex(where: { $0.persistentModelID == draggedItem.persistentModelID }),
              let to = exercises.firstIndex(where: { $0.persistentModelID == item.persistentModelID })
        else {
            return
        }

        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            var ordered = exercises
            ordered.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            for (index, ex) in ordered.enumerated() {
                ex.orderIndex = index
            }
        }
    }
}

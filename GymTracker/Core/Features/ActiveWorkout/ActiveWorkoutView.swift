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
                    selectedExerciseNames: Set(viewModel.activeWorkout?.orderedExercises.map(\.exercise.name) ?? []),
                    onSelect: toggleExerciseFromPicker
                )
            }
        }
        .sheet(item: $exerciseToSwap) { exerciseEntry in
            NavigationStack {
                ExerciseSwapPicker(exerciseEntry: exerciseEntry) { replacement in
                    guard viewModel.swapExercise(exerciseEntry, with: replacement) else { return }
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

                    if viewModel.isTimerVisible && viewModel.hasIncompleteSet {
                        // A paused timer intentionally has no end date. Keep its
                        // controls visible by supplying an unused placeholder; the
                        // paused branch of `restTimer` renders the saved remaining
                        // duration instead of this value.
                        restTimer(endDate: viewModel.timerPause ?? .now)
                    }

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
    @ViewBuilder
    private func sessionProgressSummary(for workout: Workout) -> some View {
        if workout.totalSetCount == 0 {
            Text("No exercises yet.")
        } else if workout.exercises.isEmpty {
            Text("\(workout.completedSetCount) / \(workout.totalSetCount) sets")
        } else {
            Text("\(workout.completedSetCount) / \(workout.totalSetCount) sets")
                + Text(" · ")
                + Text("^[\(workout.exercises.count) exercise](inflect: true)")
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

    private func restTimer(endDate: Date) -> some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Image(systemName: AppIcon.timer)
                    .font(AppFont.headlineSemibold)
                    .frame(width: 42, height: 42)
                    .foregroundStyle(Color.gymAccent)
                    .background(Color.gymAccentSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Rest between sets")
                        .font(AppFont.subheadlineSemibold)
                    Text(restStatusMessage)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: 0)

                if viewModel.isRestReady {
                    Text("Ready")
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymSecondary)
                } else if viewModel.isTimerPaused {
                    Text(formatRemainingTime(viewModel.pausedTimeRemaining))
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.gymAccent)
                } else if let interval = LiveActivityTimeRange.restInterval(now: .now, end: endDate) {
                    Text(timerInterval: interval, countsDown: true)
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.gymAccent)
                } else {
                    // The persisted deadline can expire while SwiftUI is
                    // waiting for the rest-state task to mark it ready.
                    // Never construct an invalid timer range in that gap.
                    Text("Ready")
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymSecondary)
                }
            }

            if viewModel.isRestReady {
                Button("Start next set") {
                    startNextSet()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gymPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("start-next-set")
            } else {
                HStack(spacing: Spacing.s) {
                    Button("+15s") {
                        viewModel.addRestTime(15)
                    }

                    Button("+30s") {
                        viewModel.addRestTime(30)
                    }

                    Spacer(minLength: 0)

                    Button {
                        if viewModel.isTimerPaused {
                            viewModel.resumeTimer()
                        } else {
                            viewModel.pauseTimer()
                        }
                    } label: {
                        Image(systemName: viewModel.isTimerPaused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityLabel(viewModel.isTimerPaused ? "Resume rest" : "Pause rest")

                    Button {
                        activeLoggingMetrics.restSkipped()
                        viewModel.cancelTimer()
                    } label: {
                        Image(systemName: AppIcon.fastForward)
                    }
                    .accessibilityLabel("Skip rest")
                }
                .buttonStyle(.bordered)
                .tint(Color.gymAccent)
            }
        }
        .padding(Spacing.m + 2)
        .background(Color.gymAccentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
        .accessibilityIdentifier(restAccessibilityIdentifier)
    }

    private var restStatusMessage: String {
        if viewModel.isRestReady {
            if let next = nextSetDescription {
                return String(localized: "Rest complete · \(next)")
            }
            return String(localized: "Rest complete")
        }
        if viewModel.isTimerPaused {
            return String(localized: "Rest paused.")
        }
        if let next = nextSetDescription {
            return next
        }
        return String(localized: "Take a breath.")
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

    private var restAccessibilityIdentifier: String {
        if viewModel.isRestReady { return "rest-ready" }
        return viewModel.isTimerPaused ? "rest-paused" : "rest-running"
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
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
                    Button {
                        isShowingExecutionBlockBuilder = true
                    } label: {
                        Label("Block", systemImage: AppIcon.relationship)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("add-execution-block")

                    Button {
                        isShowingExercisePicker = true
                    } label: {
                        Label("Add", systemImage: AppIcon.plus)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymPrimary)
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

                if !preparation.isEmpty {
                    sessionSectionHeader(
                        title: "PREPARATION & MOBILITY",
                        detail: "Complete first · stop if pain appears",
                        icon: AppIcon.info
                    )
                    exerciseCards(for: preparation, in: workout)
                }

                if !training.isEmpty {
                    sessionSectionHeader(
                        title: preparation.isEmpty ? "EXERCISES" : "STRENGTH WORK",
                        detail: preparation.isEmpty ? nil : "After preparation",
                        icon: AppIcon.workout
                    )
                    exerciseCards(for: training, in: workout)
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
            ExerciceEntryCard(
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
                }
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
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.gymPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
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
                    Label("Review Workout", systemImage: AppIcon.checkmark)
                        .font(AppFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(Color.gymPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(workout.completedSetCount == 0)
                .opacity(workout.completedSetCount == 0 ? 0.45 : 1)
                .accessibilityHint(workout.completedSetCount == 0 ? "Complete at least one set before finishing." : "Review and save your workout.")
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

    private func advanceDisclosure(after completedExercise: ExerciseEntry, in workout: Workout) {
        let nextExercise = WorkoutSetSelector.nextEntry(
            afterCompleting: completedExercise,
            in: workout
        )

        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            expandedExerciseID = nextExercise?.persistentModelID
        }
    }

    private func toggleExerciseFromPicker(_ exercise: Exercise) {
        if let existingExercise = viewModel.activeWorkout?.orderedExercises.first(where: { $0.exercise.name == exercise.name }) {
            viewModel.removeExercise(existingExercise)
        } else {
            viewModel.addExercise(exercise)
            expandedExerciseID = viewModel.activeWorkout?.orderedExercises.last?.persistentModelID
        }
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
        case .keepLast:
            viewModel.applyPriorRecommendationLoad(to: exercise)
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

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
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
            viewModel.persistChanges()
        }
    }
}

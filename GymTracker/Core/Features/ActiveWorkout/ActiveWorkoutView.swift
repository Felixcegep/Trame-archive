import SwiftUI
import SwiftData

/// Active Workout, as a stage rather than a list.
///
/// The screen used to be one scroll of collapsed exercise cards. That shape
/// made the lifter's actual subject — the exercise in front of them — one row
/// among seven, and it made rest a 60pt strip that had to compete with content
/// it was not interrupting. Both were consequences of trying to show the whole
/// session at once on a screen that is used one-handed, at arm's length,
/// between efforts.
///
/// So the session is now paged: one exercise (or one superset, or one execution
/// block) per page, the whole session summarized by the position rail in the header,
/// the whole session listed again on the final page where reviewing it is the
/// actual task. Rest takes the page when rest is what is happening. And the
/// most frequent action in the app — logging a set — has one fixed location in
/// the command bar instead of three conditional ones.
struct ActiveWorkoutView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query(filter: #Predicate<MobilityDefinition> { !$0.isArchived }) private var mobilityDefinitions: [MobilityDefinition]
    @Query(filter: #Predicate<MobilityRoutine> { !$0.isArchived }) private var mobilityRoutines: [MobilityRoutine]
    @Query(filter: #Predicate<PlanProgressionRecommendationRecord> { !$0.isResolved })
    private var unresolvedProgramRecommendations: [PlanProgressionRecommendationRecord]

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [ActiveWorkoutRoute]
    let modelContext: ModelContext
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    let onDiscardRequested: () -> Void
    /// Linked warm-up / mid-session / cooldown stays inside this shell.
    /// Standalone mobility still uses its own cover in `RootView`.
    let linkedMobilitySession: MobilitySession?
    let linkedWorkoutName: String?
    let linkedWorkoutStartTime: Date?
    let onFinishLinkedMobility: () -> Void
    /// Starts a mid-session mobility movement. Returns `false` when the
    /// one-active gate refuses so this view can offer Resume vs Cancel.
    let onInsertMobilityMovement: (MobilityDefinition) -> Bool
    /// Starts a mid-session mobility routine (secondary path).
    let onInsertMobilityRoutine: (MobilityRoutine) -> Bool
    /// Rebinds presentation to the persisted active mobility session after a
    /// refused insert (Resume existing).
    let onResumeExistingMobility: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ActiveWorkoutViewModel
    @State private var coordinator = SetInputCoordinator()

    /// The page currently on screen. Resolved in `init` rather than `onAppear`
    /// so the first frame is already the right exercise — `onAppear` fires
    /// after the initial layout, which would show the finish page for a frame
    /// and then jump.
    @State private var selection: WorkoutStagePage
    /// Whether rest currently owns the screen. Set true whenever a rest period
    /// begins; the lifter can drag it away without stopping the clock.
    @State private var isRestExpanded = false

    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingExercisePicker = false
    @State private var isShowingMobilityInsertPicker = false
    @State private var isShowingMobilityInsertConflict = false
    @State private var editingCompletedSetID: PersistentIdentifier?
    @State private var exerciseToSwap: ExerciseEntry?
    @State private var isShowingExecutionBlockBuilder = false
    @State private var executionBlockToEdit: WorkoutExecutionBlock?
    @State private var activeRecommendationErrorMessage: String?
    @State private var handledRecommendationExerciseIDs: Set<PersistentIdentifier> = []
    @State private var externalRestSyncTask: Task<Void, Never>?

    private var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
    }

    init(
        workoutVM: WorkoutViewModel,
        navigationPath: Binding<[ActiveWorkoutRoute]>,
        modelContext: ModelContext,
        activeLoggingMetrics: ActiveLoggingMetricsRecorder,
        onDiscardRequested: @escaping () -> Void,
        linkedMobilitySession: MobilitySession? = nil,
        linkedWorkoutName: String? = nil,
        linkedWorkoutStartTime: Date? = nil,
        onFinishLinkedMobility: @escaping () -> Void = {},
        onInsertMobilityMovement: @escaping (MobilityDefinition) -> Bool = { _ in false },
        onInsertMobilityRoutine: @escaping (MobilityRoutine) -> Bool = { _ in false },
        onResumeExistingMobility: @escaping () -> Void = {}
    ) {
        self.workoutVM = workoutVM
        _navigationPath = navigationPath
        self.modelContext = modelContext
        self.activeLoggingMetrics = activeLoggingMetrics
        self.onDiscardRequested = onDiscardRequested
        self.linkedMobilitySession = linkedMobilitySession
        self.linkedWorkoutName = linkedWorkoutName
        self.linkedWorkoutStartTime = linkedWorkoutStartTime
        self.onFinishLinkedMobility = onFinishLinkedMobility
        self.onInsertMobilityMovement = onInsertMobilityMovement
        self.onInsertMobilityRoutine = onInsertMobilityRoutine
        self.onResumeExistingMobility = onResumeExistingMobility
        _viewModel = State(initialValue: ActiveWorkoutViewModel(
            workoutVM: workoutVM,
            modelContext: modelContext,
            activeLoggingMetrics: activeLoggingMetrics
        ))
        _selection = State(
            initialValue: workoutVM.activeWorkout
                .map { WorkoutStagePlan.currentPage(in: $0) } ?? .finish
        )
    }

    var body: some View {
        Group {
            if let mobility = linkedMobilitySession {
                MobilitySessionView(
                    session: mobility,
                    linkedWorkoutName: linkedWorkoutName,
                    linkedWorkoutStartTime: linkedWorkoutStartTime,
                    onFinished: onFinishLinkedMobility
                )
            } else if let workout = viewModel.activeWorkout {
                stage(for: workout)
            } else {
                ContentUnavailableView(
                    "No active workout",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Start a workout from Home to log your sets.")
                )
            }
        }
        .foregroundStyle(Color.trameText)
        .background(Color.trameCanvas.ignoresSafeArea())
        .tint(Color.trameAction)
        // The header replaces the navigation bar: the session position rail
        // needs the full width, which no bar placement offers.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
                .accessibilityIdentifier("confirm-discard-workout")
            // Stated rather than implied. The dialog is the last stop before
            // the session is destroyed, so the way back out is a control the
            // lifter can see and aim at.
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("cancel-discard-workout")
        } message: {
            Text(discardConfirmationMessage)
        }
        .alert(
            "Couldn’t save your decision",
            isPresented: Binding(
                get: { activeRecommendationErrorMessage != nil },
                set: { if !$0 { activeRecommendationErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { activeRecommendationErrorMessage = nil }
        } message: {
            Text(activeRecommendationErrorMessage ?? "")
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
        .sheet(isPresented: $isShowingMobilityInsertPicker) {
            ActiveWorkoutMobilityInsertPicker(
                definitions: mobilityDefinitions,
                routines: mobilityRoutines,
                onStartMovement: startInsertedMobilityMovement,
                onStartRoutine: startInsertedMobilityRoutine
            )
        }
        .confirmationDialog(
            "A mobility session is already active",
            isPresented: $isShowingMobilityInsertConflict,
            titleVisibility: .visible
        ) {
            Button("Resume existing") {
                isShowingMobilityInsertPicker = false
                onResumeExistingMobility()
            }
            .accessibilityIdentifier("resume-existing-mobility-insert")
            Button("Cancel insert", role: .cancel) {}
                .accessibilityIdentifier("cancel-mobility-insert-conflict")
        } message: {
            Text("Only one mobility session can run at a time. Resume the open session or cancel this insert.")
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
                    selection = WorkoutStagePlan.page(containing: exerciseEntry)
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
            externalRestSyncTask?.cancel()
            externalRestSyncTask = nil
        }
        .onAppear {
            viewModel.loadPreviousPerformances()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.restorePersistedRestTimer()
            case .inactive, .background:
                viewModel.flushPendingTypedInputSave()
            @unknown default:
                viewModel.flushPendingTypedInputSave()
            }
        }
        // App Intents and Live Activity buttons mutate persisted rest state
        // (`Workout.restEndDate` / `pausedRemainingTime`) through a separate
        // `ModelContext`, then post this notification. `RootView` patches the
        // shared model fields via `WorkoutViewModel.handleExternalWorkoutChange`,
        // but nothing else tells this screen's countdown to re-derive itself,
        // so a rest skipped from Siri or the Live Activity would otherwise
        // keep ticking here toward a deadline that no longer exists. Deferred
        // by one run-loop turn so it always reads the model after RootView's
        // own (synchronous) handler has applied the patch, regardless of
        // subscriber registration order.
        .onReceive(NotificationCenter.default.publisher(for: .activeWorkoutMutated)) { notification in
            guard let workoutID = notification.object as? UUID,
                  workoutID == viewModel.activeWorkout?.id
            else { return }
            externalRestSyncTask?.cancel()
            externalRestSyncTask = Task { @MainActor in
                viewModel.restorePersistedRestTimer()
            }
        }
    }

    // MARK: - Stage

    private func stage(for workout: Workout) -> some View {
        let pages = WorkoutStagePlan.pages(for: workout)

        return VStack(spacing: 0) {
            ActiveWorkoutStageHeader(
                workout: workout,
                pages: pages,
                selection: $selection,
                onMinimize: minimizeWorkout,
                onDiscard: { isShowingDiscardConfirmation = true },
                onAddExercise: { isShowingExercisePicker = true },
                onAddBlock: { isShowingExecutionBlockBuilder = true },
                onAddMobility: FeatureFlags.current.isEnabled(.mobility)
                    ? { isShowingMobilityInsertPicker = true }
                    : nil,
                isFinishEnabled: canFinish(workout),
                onFinish: finishWorkout
            )

            saveFailureBanner

            activeDailyMaximumBanner(for: workout)

            pager(for: workout, pages: pages)
        }
        .safeAreaInset(edge: .bottom) {
            if coordinator.focus == nil {
                ActiveWorkoutCommandBar(
                    primaryAction: primaryAction(for: workout),
                    logSetValues: logSetValues(for: workout),
                    restEndDate: viewModel.timerPause,
                    isRestPaused: viewModel.isTimerPaused,
                    pausedRemaining: viewModel.pausedTimeRemaining,
                    canGoBack: canGo(-1, in: pages),
                    canGoForward: canGo(1, in: pages),
                    onBack: { turnPage(-1, in: pages) },
                    onForward: { turnPage(1, in: pages) },
                    onPrimary: { performPrimaryAction(for: workout, pages: pages) }
                )
            } else {
                VStack(spacing: Spacing.s) {
                    if viewModel.isTimerVisible && viewModel.hasIncompleteSet {
                        ActiveWorkoutRestPill(
                            restEndDate: viewModel.timerPause,
                            isRestPaused: viewModel.isTimerPaused,
                            pausedRemaining: viewModel.pausedTimeRemaining
                        ) {
                            coordinator.focus = nil
                            withAnimation(reduceMotion ? nil : AppMotion.layout) {
                                isRestExpanded = true
                            }
                        }
                        .padding(.horizontal, Spacing.screenInset)
                    }

                    // SwiftUI's keyboard avoidance lifts this bottom safe-area
                    // inset above the keypad, so the panel rides on top of it
                    // without manual height math.
                    SetInputAccessoryPanel(
                        viewModel: viewModel,
                        coordinator: coordinator,
                        unitSystem: unitSystem,
                        onSetCompleted: { exercise in
                            advanceStage(after: exercise, in: workout)
                        }
                    )
                }
            }
        }
        .overlay {
            if isShowingRestTakeover {
                RestTakeoverView(
                    viewModel: viewModel,
                    activeLoggingMetrics: activeLoggingMetrics,
                    nextUp: restNextUp(in: workout),
                    onEditJustLogged: editJustLoggedSet,
                    onUndoJustLogged: undoJustLoggedSet,
                    onStartNextSet: startNextSet,
                    onCollapse: {
                        withAnimation(reduceMotion ? nil : AppMotion.layout) {
                            isRestExpanded = false
                        }
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.layout, value: isShowingRestTakeover)
        // Attached here rather than to the takeover: the takeover is removed
        // the instant rest is skipped, and the completion signal must outlive
        // it. `restCompletionCount` only increments from a countdown reaching
        // its deadline, never from restoring a rest that expired while the app
        // was away.
        .gymFeedback(.restReady, trigger: viewModel.restCompletionCount)
        .onChange(of: viewModel.restCompletionCount) { _, _ in
            GymAnnouncement.post(restCompletionAnnouncement(in: workout))
        }
        // A rest that has just begun is the whole job; show it without being
        // asked. A rest restored after a relaunch is not "just begun", but the
        // lifter is still resting, so it opens too.
        .onChange(of: viewModel.isTimerVisible) { _, isVisible in
            isRestExpanded = isVisible
        }
        .onChange(of: selection) { _, page in
            editingCompletedSetID = nil
            viewModel.trackActiveExercise(with: trackedExerciseID(for: page, in: workout))

            // The panel is bound to a *set*, not to a page, so swiping away
            // used to leave it editing the exercise the lifter had just left:
            // the hero read "Plank" while the panel above the keypad still said
            // "Assisted pull-up · Set 1 of 2", and the next digit typed landed
            // on the pull-up. Values going into the wrong exercise is the worst
            // failure this screen has, and nothing on screen revealed it.
            //
            // Turning the page puts the keypad away, unconditionally. Nothing
            // is lost by it — typed values commit on every keystroke — and a
            // superset never needs the exception, because alternating between
            // its members happens *within* one page rather than across two.
            coordinator.focus = nil
        }
        .onChange(of: coordinator.focus) { _, focus in
            guard let focus else { return }
            coordinator.refreshOrder(in: viewModel.activeWorkout)
            if let models = viewModel.models(for: focus) {
                let page = WorkoutStagePlan.page(containing: models.exercise)
                // A page-style pager can still hit-test a neighbour that is
                // not on screen. Following that stray focus would jump two
                // exercises back the moment the lifter tapped a weight.
                // Keep the visible page; drop the ghost selection.
                guard WorkoutStagePlan.acceptsFocus(on: page, whileShowing: selection) else {
                    coordinator.focus = nil
                    return
                }
                activeLoggingMetrics.focusChanged(
                    to: models.set.id,
                    field: focus.field,
                    replacesExistingValue: hasEnteredValue(for: focus.field, in: models.set)
                )
                // Editing a value is not resting. Collapse rather than cancel:
                // the clock keeps running behind the keypad and the pill in the
                // command bar is one tap from the full timer.
                isRestExpanded = false
            }
        }
        .onChange(of: workout.completedSetCount) { _, _ in
            // Completing the final set (even mid-rest) ends the workout, so
            // end any running rest and let the takeover fall away.
            if viewModel.isTimerVisible && !viewModel.hasIncompleteSet {
                viewModel.cancelTimer()
            }
        }
        // Removing an exercise, dissolving a superset, or deleting a block can
        // delete the page the lifter is standing on. Without this the pager
        // would hold a tag that no longer exists and render nothing at all.
        .onChange(of: pages) { _, updatedPages in
            guard !updatedPages.contains(selection) else { return }
            selection = WorkoutStagePlan.currentPage(in: workout)
        }
        .onAppear {
            viewModel.trackActiveExercise(with: trackedExerciseID(for: selection, in: workout))
            viewModel.restorePersistedRestTimer()
        }
    }

    private func editJustLoggedSet(_ entry: ExerciseEntry, _ set: ExerciseSet) {
        selection = WorkoutStagePlan.page(containing: entry)
        isRestExpanded = false
        // Page changes intentionally clear completed-set editing. Re-enter it
        // on the next turn so the destination page owns the correction state.
        DispatchQueue.main.async {
            editingCompletedSetID = set.persistentModelID
            coordinator.focus = SetInputFocus(
                exerciseID: entry.persistentModelID,
                setID: set.persistentModelID,
                field: entry.trackingTypeSnapshot.usesWeight ? .weight : .repetitions
            )
        }
    }

    /// Takes back the completion of the set that just ended, from the screen
    /// the lifter is already on. The values stay written and the rest clock
    /// keeps running — undoing a completion is not a request to stop resting,
    /// and stopping the clock would punish the correction.
    private func undoJustLoggedSet(_ entry: ExerciseEntry, _ set: ExerciseSet) {
        guard viewModel.switchStateDoneSet(entry, set) else { return }
        editingCompletedSetID = nil
        GymAnnouncement.post(
            String(localized: "Set reopened. Its values are kept and rest continues.")
        )
    }

    private func pager(for workout: Workout, pages: [WorkoutStagePage]) -> some View {
        // One page at a time. A `TabView`/paging scroll keeps off-screen
        // exercises in the hit-test tree, so tapping the current weight can
        // select a field two stages back and then follow that focus.
        stagePage(selection, workout: workout)
            .id(selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard coordinator.focus == nil else { return }
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy), abs(dx) > 60 else { return }
                        turnPage(dx < 0 ? 1 : -1, in: pages)
                    }
            )
    }

    @ViewBuilder
    private func stagePage(_ page: WorkoutStagePage, workout: Workout) -> some View {
        if page.isFinish {
            StageFinishPage(
                workout: workout,
                blockers: finishBlockers(for: workout),
                onJumpToPage: { selection = $0 },
                onAdjustDuration: { duration in
                    _ = workout.updateElapsedDuration(duration)
                    viewModel.persistChanges()
                },
                onAddMobility: FeatureFlags.current.isEnabled(.mobility)
                    ? { isShowingMobilityInsertPicker = true }
                    : nil
            )
        } else {
            ExerciseStagePage(
                page: page,
                workout: workout,
                viewModel: viewModel,
                unitSystem: unitSystem,
                coordinator: coordinator,
                editingCompletedSetID: $editingCompletedSetID,
                recommendation: recommendation(for: page, in: workout),
                onRecommendationAction: handleRecommendationAction,
                onSwapRequested: { exerciseToSwap = $0 },
                onSetCompleted: { advanceStage(after: $0, in: workout) },
                onAddExercise: { isShowingExercisePicker = true },
                onEditBlock: { executionBlockToEdit = $0 },
                onRemoveBlock: { removeExecutionBlock($0, from: workout) },
                canMove: { entry, offset in canMove(entry, by: offset, in: workout) },
                onMove: { entry, offset in move(entry, by: offset, in: workout) }
            )
        }
    }

    // MARK: - Banners

    /// Non-blocking, non-modal notice that the last edit failed to save and
    /// was rolled back. Deliberately not an alert: an alert mid-set would
    /// interrupt a lift for a background persistence hiccup that the next
    /// edit will retry on its own. Clears itself the moment a save succeeds.
    @ViewBuilder
    private var saveFailureBanner: some View {
        if viewModel.hasPersistenceFailure {
            HStack(spacing: Spacing.s) {
                Image(systemName: AppIcon.warning)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
                Text("Changes haven’t saved yet. Keep entering — Trame will try again.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.trameRow, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.trameSeparator, lineWidth: 1)
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.bottom, Spacing.s)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("active-workout-save-failure-banner")
        }
    }

    /// The one recommendation that must be resolved before the session can be
    /// saved. It sits above the pager rather than on a page because it blocks
    /// finishing regardless of which exercise is on screen.
    @ViewBuilder
    private func activeDailyMaximumBanner(for workout: Workout) -> some View {
        if let recommendation = activeDailyMaximumRecommendation(for: workout),
           let entry = workout.orderedExercises.first(where: {
               $0.progressionKey == recommendation.progressionKey
           }) {
            ActiveDailyMaximumRecommendationCard(
                recommendation: recommendation,
                exerciseName: entry.nameSnapshot,
                onAccept: { resolveActiveRecommendation(recommendation, accepting: true) },
                onDecline: { resolveActiveRecommendation(recommendation, accepting: false) }
            )
            .padding(.horizontal, Spacing.screenInset)
            .padding(.bottom, Spacing.s)
        }
    }

    // MARK: - Paging

    private var isShowingRestTakeover: Bool {
        viewModel.isTimerVisible
            && viewModel.hasIncompleteSet
            && isRestExpanded
            && coordinator.focus == nil
    }

    private func canGo(_ offset: Int, in pages: [WorkoutStagePage]) -> Bool {
        guard let index = pages.firstIndex(of: selection) else { return false }
        return pages.indices.contains(index + offset)
    }

    private func turnPage(_ offset: Int, in pages: [WorkoutStagePage]) {
        guard let index = pages.firstIndex(of: selection),
              pages.indices.contains(index + offset)
        else { return }
        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            selection = pages[index + offset]
        }
    }

    /// Where to go after a set is logged.
    ///
    /// An exercise that still has work keeps the page. A lifter who skipped
    /// ahead because a rack was busy would otherwise complete a set on exercise
    /// four and watch the app turn back to exercise one — every single set.
    /// Working out of order is normal in a shared gym and the app already
    /// permits it, so the page only turns once this page's work is genuinely
    /// finished.
    private func advanceStage(after entry: ExerciseEntry, in workout: Workout) {
        let pageStillHasWork = WorkoutStagePlan.entries(for: selection, in: workout)
            .contains { $0.orderedSets.contains { !$0.done } }
        guard !pageStillHasWork else { return }

        let destination = WorkoutStagePlan.currentPage(in: workout)
        guard destination != selection else { return }
        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            selection = destination
        }
    }

    /// Which exercise's active-duration clock should be running. A page can
    /// hold several exercises (a superset, a block), so it is the one owning
    /// the next incomplete set — not simply the first.
    private func trackedExerciseID(
        for page: WorkoutStagePage,
        in workout: Workout
    ) -> PersistentIdentifier? {
        let entries = WorkoutStagePlan.entries(for: page, in: workout)
        let working = entries.first { $0.orderedSets.contains { !$0.done } }
        return (working ?? entries.first)?.persistentModelID
    }

    // MARK: - Primary action

    private func primaryAction(for workout: Workout) -> ActiveWorkoutCommandBar.PrimaryAction {
        if workout.exercises.isEmpty { return .addExercise }

        // The terminal page reviews the session; committing it is the header's
        // Finish. Holding the slot empty keeps the arrows in the same place
        // they occupy on every other page.
        if selection.isFinish { return .idle }

        if viewModel.isTimerVisible && viewModel.hasIncompleteSet {
            return viewModel.isRestReady ? .startNextSet : .resting
        }

        if nextSetOnCurrentPage(in: workout) != nil {
            // Always enabled. A set missing its values is not an error to
            // prevent, it is a field to land on — `completeSet` returns the
            // exact field that is blocking, and tapping through to it is
            // faster than a disabled button that explains itself in a hint.
            return .logSet(isEnabled: true)
        }

        return .nextExercise
    }

    private func performPrimaryAction(for workout: Workout, pages: [WorkoutStagePage]) {
        switch primaryAction(for: workout) {
        case .resting:
            withAnimation(reduceMotion ? nil : AppMotion.layout) {
                isRestExpanded = true
            }

        case .startNextSet:
            startNextSet()

        case .logSet:
            logCurrentSet(in: workout)

        case .nextExercise:
            turnPage(1, in: pages)

        case .addExercise:
            isShowingExercisePicker = true

        case .idle:
            isShowingExercisePicker = true
        }
    }

    /// The next incomplete set, but only when this page owns it. Returns nil on
    /// a page the lifter has swiped to out of order, which is why the command
    /// bar offers "Next exercise" there instead of a log action that would
    /// silently apply to a different page's set.
    private func nextSetOnCurrentPage(
        in workout: Workout
    ) -> (entry: ExerciseEntry, set: ExerciseSet)? {
        guard let next = WorkoutSetSelector.nextIncompleteSet(in: workout),
              WorkoutStagePlan.page(containing: next.entry) == selection
        else {
            return nil
        }
        return next
    }

    /// Prefill the command bar already knows it will write, so the tap is
    /// verifiable without looking up at the row. `nil` keeps the generic title
    /// when the current page has no set, or the set has no values yet.
    private func logSetValues(for workout: Workout) -> String? {
        guard case .logSet = primaryAction(for: workout),
              let next = nextSetOnCurrentPage(in: workout),
              next.set.complexComponents.allSatisfy({ $0.outcome != .notStarted })
        else {
            return nil
        }
        let tracking = next.entry.trackingTypeSnapshot
        let set = next.set
        var parts: [String] = []
        if tracking.usesWeight, set.weight > 0 {
            parts.append("\(Formatters.formatFloat(set.weight)) \(set.weightType.rawValue)")
        }
        if tracking.usesReps, set.repetitions > 0 {
            parts.append("× \(Formatters.formatFloat(set.repetitions))")
        }
        if tracking.usesDuration, let duration = set.duration, duration > 0 {
            parts.append("\(Formatters.formatFloat(Float(duration))) sec")
        }
        if tracking.usesDistance, let distance = set.distance, distance > 0 {
            parts.append("\(Formatters.formatFloat(distance)) \(set.distanceType.rawValue)")
        }
        if tracking.usesCalories, let calories = set.calories, calories > 0 {
            parts.append("\(Formatters.formatFloat(Float(calories))) cal")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func logCurrentSet(in workout: Workout) {
        guard let next = nextSetOnCurrentPage(in: workout) else { return }
        switch viewModel.completeSet(next.set, in: next.entry) {
        case .blocked(let message, let focus):
            // Land on the field that is missing rather than refusing the tap —
            // and carry the reason with it. Raising the keypad with no
            // explanation was the same dead end as an explanation nobody sees,
            // reached from the other direction. Focus first: the coordinator's
            // focus setter clears the message.
            coordinator.focus = focus
            coordinator.recordBlockedAttempt(message)
            GymAnnouncement.post(message)
        case .completed:
            advanceStage(after: next.entry, in: workout)
        case .reopened, .failed:
            break
        }
    }

    /// Ends the rest period and moves to the next incomplete set: turns to its
    /// page and focuses its first editable value.
    private func startNextSet() {
        guard let next = viewModel.getNextExerciseToDo() else {
            viewModel.cancelTimer()
            return
        }
        viewModel.cancelTimer()
        withAnimation(reduceMotion ? nil : AppMotion.layout) {
            selection = WorkoutStagePlan.page(containing: next.exercise)
        }
        let firstField = SetInputCoordinator
            .inputFields(for: next.exercise.trackingTypeSnapshot)
            .first ?? .repetitions
        coordinator.focus = SetInputFocus(
            exerciseID: next.exercise.persistentModelID,
            setID: next.set.persistentModelID,
            field: firstField
        )
    }

    // MARK: - Rest

    private func restNextUp(in workout: Workout) -> RestNextUp? {
        guard let next = viewModel.getNextExerciseToDo() else { return nil }
        let sets = next.exercise.orderedSets
        let number = (sets.firstIndex {
            $0.persistentModelID == next.set.persistentModelID
        } ?? 0) + 1

        return RestNextUp(
            exerciseName: next.exercise.occurrenceDisplayName,
            setNumber: number,
            setCount: sets.count,
            target: targetText(for: next.set, in: next.exercise),
            roleTitle: next.set.setType == .normal ? nil : next.set.setType.title,
            changesExercise: WorkoutStagePlan.page(containing: next.exercise) != selection
        )
    }

    /// What the next set is asking for: the prescription when there is one, the
    /// values already carried forward when there is not.
    private func targetText(for set: ExerciseSet, in entry: ExerciseEntry) -> String? {
        let trackingType = entry.trackingTypeSnapshot
        var parts: [String] = []

        if trackingType.usesReps {
            if let minimum = set.prescribedRepRangeMinimum,
               let maximum = set.prescribedRepRangeMaximum {
                parts.append("\(minimum)–\(maximum) reps")
            } else if let reps = set.prescribedRepetitions {
                parts.append("\(reps) reps")
            } else if set.repetitions > 0 {
                parts.append("\(Formatters.formatFloat(set.repetitions)) reps")
            }
        }
        if trackingType.usesWeight {
            if let load = set.prescribedSuggestedLoad, let unit = set.prescribedSuggestedLoadType {
                parts.append("\(Formatters.formatFloat(Float(load))) \(unit.rawValue)")
            } else if set.weight > 0 {
                parts.append("\(Formatters.formatFloat(set.weight)) \(set.weightType.rawValue)")
            }
        }
        if trackingType.usesDuration, let duration = set.duration, duration > 0 {
            parts.append("\(Int(duration)) sec")
        }
        if trackingType.usesCalories, let calories = set.calories, calories > 0 {
            parts.append("\(Formatters.formatFloat(Float(calories))) cal")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " × ")
    }

    /// Spoken at the deadline. Names what to do next rather than only that rest
    /// is over, because that is the question the lifter actually has.
    private func restCompletionAnnouncement(in workout: Workout) -> String {
        guard let next = restNextUp(in: workout) else {
            return String(localized: "Rest complete.")
        }
        return String(
            localized: "Rest complete. Next: \(next.exerciseName), set \(next.setNumber)."
        )
    }

    // MARK: - Finish

    private func canFinish(_ workout: Workout) -> Bool {
        workout.completedSetCount > 0 && activeDailyMaximumRecommendation(for: workout) == nil
    }

    private func finishWorkout() {
        viewModel.flushPendingTypedInputSave()
        viewModel.cancelTimer()
        navigationPath.append(.saveWorkout)
    }

    private func finishBlockers(for workout: Workout) -> [String] {
        var blockers: [String] = []
        if workout.completedSetCount == 0 {
            blockers.append(String(localized: "Complete at least one set before finishing."))
        }
        if activeDailyMaximumRecommendation(for: workout) != nil {
            blockers.append(
                String(localized: "Choose whether to stop or continue maximum attempts before finishing.")
            )
        }
        return blockers
    }

    // MARK: - Exercises

    private func canMove(_ exercise: ExerciseEntry, by offset: Int, in workout: Workout) -> Bool {
        let ordered = workout.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.persistentModelID == exercise.persistentModelID })
        else { return false }
        return ordered.indices.contains(index + offset)
    }

    /// Reordering, with an announcement. This was drag-only before, which
    /// VoiceOver and Switch Control cannot reach at all — and which nothing on
    /// the card advertised, so most sighted users never found it either.
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

    /// The picker adds only. It used to toggle, so tapping an exercise that
    /// was already in the session deleted it along with every set logged
    /// against it — from a sheet where none of that work was on screen.
    private func addExerciseFromPicker(_ exercise: Exercise) {
        guard viewModel.activeWorkout?.orderedExercises.contains(where: { $0.exercise.id == exercise.id }) != true else {
            return
        }
        viewModel.addExercise(exercise)
        if let added = viewModel.activeWorkout?.orderedExercises.last {
            selection = WorkoutStagePlan.page(containing: added)
        }
    }

    @discardableResult
    private func startInsertedMobilityMovement(_ definition: MobilityDefinition) -> Bool {
        let started = onInsertMobilityMovement(definition)
        if started == false,
           MobilitySessionService.activeSession(using: modelContext) != nil {
            isShowingMobilityInsertConflict = true
        }
        return started
    }

    @discardableResult
    private func startInsertedMobilityRoutine(_ routine: MobilityRoutine) -> Bool {
        let started = onInsertMobilityRoutine(routine)
        if started == false,
           MobilitySessionService.activeSession(using: modelContext) != nil {
            isShowingMobilityInsertConflict = true
        }
        return started
    }

    private func removeExecutionBlock(_ block: WorkoutExecutionBlock, from workout: Workout) {
        guard WorkoutExecutionBlockService.remove(block, from: workout).isApplied else { return }
        try? WorkoutExecutionBlockSplitService.deleteEvidence(for: block.id, using: modelContext)
        modelContext.delete(block)
        viewModel.persistChanges()
        selection = WorkoutStagePlan.currentPage(in: workout)
    }

    private func minimizeWorkout() {
        viewModel.flushPendingTypedInputSave()
        activeLoggingMetrics.workoutMinimized()
        dismiss()
    }

    private func discardWorkout() {
        viewModel.cancelTimer()
        navigationPath.removeAll()
        onDiscardRequested()
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

    private func repeatingPlanName(for workout: Workout) -> String? {
        guard let name = workout.sourceRepeatingPlanName?
            .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else {
            return nil
        }
        return name
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

    // MARK: - Recommendations

    private func activeDailyMaximumRecommendation(
        for workout: Workout
    ) -> PlanProgressionRecommendationRecord? {
        unresolvedProgramRecommendations
            .filter { $0.workoutID == workout.id }
            .sorted { $0.createdAt < $1.createdAt }
            .first { recommendation in
                guard let action = try? recommendation.action() else { return false }
                if case .endActiveDailyMaximumAndGenerateBackOffs = action { return true }
                return false
            }
    }

    private func resolveActiveRecommendation(
        _ recommendation: PlanProgressionRecommendationRecord,
        accepting: Bool
    ) {
        do {
            if accepting {
                coordinator.focus = nil
                try viewModel.acceptActiveRecommendation(recommendation)
            } else {
                try viewModel.declineActiveRecommendation(recommendation)
            }
        } catch ActiveWorkoutRecommendationMutationService.MutationError.successfulDailyMaximumNotFound {
            activeRecommendationErrorMessage = String(
                localized: "A successful maximum attempt is required to calculate the back-off load. Continue attempts or record a successful result."
            )
        } catch {
            activeRecommendationErrorMessage = String(localized: "Try again.")
        }
    }

    /// The workout carries at most one progression recommendation, so it is
    /// resolved centrally and handed to whichever page owns its exercise. That
    /// guarantees the evidence appears exactly once.
    private func recommendation(
        for page: WorkoutStagePage,
        in workout: Workout
    ) -> (exercise: ExerciseEntry, state: RecommendationPresentationState)? {
        guard let first = firstRecommendation(in: workout),
              WorkoutStagePlan.page(containing: first.exercise) == page
        else {
            return nil
        }
        return first
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
            selection = WorkoutStagePlan.page(containing: exercise)
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

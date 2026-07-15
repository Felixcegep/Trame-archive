import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ActiveWorkoutView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    let modelContext: ModelContext
    let onDiscardRequested: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActiveWorkoutViewModel
    @State private var expandedExerciseID: PersistentIdentifier?
    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingExercisePicker = false
    @FocusState private var focusedInput: SetInputFocus?
    @State private var draggedExercise: ExerciseEntry? = nil
    @State private var handledRecommendationExerciseIDs: Set<PersistentIdentifier> = []
    @State private var editingCompletedSetID: PersistentIdentifier?

    private var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
    }

    init(
        workoutVM: WorkoutViewModel,
        navigationPath: Binding<[HomeRoute]>,
        modelContext: ModelContext,
        onDiscardRequested: @escaping () -> Void
    ) {
        self.workoutVM = workoutVM
        _navigationPath = navigationPath
        self.modelContext = modelContext
        self.onDiscardRequested = onDiscardRequested
        _viewModel = State(initialValue: ActiveWorkoutViewModel(workoutVM: workoutVM, modelContext: modelContext))
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
        .foregroundStyle(WorkoutPalette.text)
        .background(WorkoutPalette.background.ignoresSafeArea())
        .tint(WorkoutPalette.primary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WorkoutPalette.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: AppIcon.minimize)
                        .fontWeight(.semibold)
                }
                .accessibilityIdentifier("minimize-workout")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isShowingDiscardConfirmation = true
                } label: {
                    Image(systemName: AppIcon.trash)
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Discard workout")
                .accessibilityIdentifier("active-workout-menu")
            }
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
        } message: {
            Text("Your logged sets will not be saved.")
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                ExerciceLibrairyView(
                    isSelectingExercise: true,
                    availableExercises: exerciseTemplates,
                    selectedExerciseNames: Set(viewModel.activeWorkout?.orderedExercises.map(\.exercise.name) ?? []),
                    onSelect: toggleExerciseFromPicker
                )
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    viewModel.copyValuesForFocusedSet(focusedInput)
                } label: {
                    Label("Copy last set values", systemImage: AppIcon.copy)
                }
                .disabled(!viewModel.canCopyValuesForFocusedSet(focusedInput))

                Spacer()

                Button("Done") {
                    focusedInput = nil
                }
            }
        }
    }

    private func workoutContent(for workout: Workout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                sessionHeader(for: workout)

                if let recommendation = firstRecommendation(in: workout) {
                    ProgressionRecommendationCard(
                        exerciseName: recommendation.exercise.exercise.name,
                        state: recommendation.state,
                        onAction: { action in
                            handleRecommendationAction(action, for: recommendation.exercise)
                        }
                    )
                }

                if viewModel.isTimerVisible {
                    // A paused timer intentionally has no end date. Keep its
                    // controls visible by supplying an unused placeholder; the
                    // paused branch of `restTimer` renders the saved remaining
                    // duration instead of this value.
                    restTimer(endDate: viewModel.timerPause ?? .now)
                }

                exerciseList(for: workout)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(WorkoutPalette.background)
        .safeAreaInset(edge: .bottom) {
            if focusedInput == nil {
                finishButton(for: workout)
            }
        }
        .onAppear {
            selectInitialDisclosure(in: workout)
            viewModel.trackActiveExercise(with: expandedExerciseID)
            viewModel.restorePersistedRestTimer()
        }
    }

    private func sessionHeader(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name?.isEmpty == false ? workout.name! : "Today’s workout")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("active-workout-title")

                Spacer()

                Text(workout.startTime, style: .timer)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(WorkoutPalette.text)
            }

            HStack {
                if workout.totalSetCount == 0 {
                    Text("No exercises yet.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(WorkoutPalette.subduedText)
                } else {
                    Text("\(workout.completedSetCount) / \(workout.totalSetCount) sets")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(WorkoutPalette.subduedText)
                }
                Spacer()
                if !workout.exercises.isEmpty {
                    Text("^[\(workout.exercises.count) exercise](inflect: true)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(WorkoutPalette.subduedText)
                }
            }

            ProgressView(value: Double(workout.completedSetCount), total: Double(max(workout.totalSetCount, 1)))
                .tint(WorkoutPalette.secondary)
        }
        .padding(Spacing.m + 2)
        .background(WorkoutPalette.accentSurface)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.section, style: .continuous)
                .stroke(WorkoutPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
    }

    private func restTimer(endDate: Date) -> some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Image(systemName: AppIcon.timer)
                    .font(.headline.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(WorkoutPalette.accent)
                    .background(WorkoutPalette.accentSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest between sets")
                        .font(.subheadline.weight(.semibold))
                    Text(restStatusMessage)
                        .font(.caption)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }

                Spacer(minLength: 0)

                if viewModel.isRestReady {
                    Text("Ready")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WorkoutPalette.secondary)
                } else if viewModel.isTimerPaused {
                    Text(formatRemainingTime(viewModel.pausedTimeRemaining))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(WorkoutPalette.accent)
                } else {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(WorkoutPalette.accent)
                }
            }

            if viewModel.isRestReady {
                Button("Continue workout") {
                    viewModel.cancelTimer()
                }
                .buttonStyle(.borderedProminent)
                .tint(WorkoutPalette.primary)
                .frame(maxWidth: .infinity)
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
                        viewModel.cancelTimer()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .accessibilityLabel("Skip rest")
                }
                .buttonStyle(.bordered)
                .tint(WorkoutPalette.accent)
            }
        }
        .padding(Spacing.m + 2)
        .background(WorkoutPalette.accentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
        .accessibilityIdentifier(restAccessibilityIdentifier)
    }

    private var restStatusMessage: String {
        if viewModel.isRestReady {
            return "Rest complete. Your next set is ready."
        }
        if viewModel.isTimerPaused {
            return "Rest paused."
        }
        return "Take a breath. Your next set is ready when you are."
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
                Text("EXERCISES")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(WorkoutPalette.subduedText)

                Spacer()

                if !workout.exercises.isEmpty {
                    Button {
                        isShowingExercisePicker = true
                    } label: {
                        Label("Add", systemImage: AppIcon.plus)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WorkoutPalette.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("add-active-exercise")
                }
            }

            if workout.exercises.isEmpty {
                emptyExerciseState
            } else {
                ForEach(workout.orderedExercises, id: \.persistentModelID) { exercise in
                    ExerciceEntryCard(
                        exerciseEntry: exercise,
                        viewModel: viewModel,
                        onButtonPress: { viewModel.startTime(after: exercise) },
                        unitSystem: unitSystem,
                        focusedInput: $focusedInput,
                        expandedExerciseID: $expandedExerciseID,
                        editingCompletedSetID: $editingCompletedSetID,
                        previousPerformance: viewModel.previousPerformance(for: exercise),
                        onExerciseCompleted: {
                            advanceDisclosure(after: exercise, in: workout)
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
                        draggedItem: $draggedExercise
                    ))
                }
            }
        }
    }

    private var emptyExerciseState: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.workout)
                .font(.largeTitle)
                .foregroundStyle(WorkoutPalette.secondary)
            Text("Add your first exercise.")
                .font(.headline)
                .foregroundStyle(WorkoutPalette.text)
            Button {
                isShowingExercisePicker = true
            } label: {
                Text("Browse exercise library")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(WorkoutPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-active-exercise")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl + 2)
        .background(WorkoutPalette.mutedSurface)
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
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(WorkoutPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(workout.completedSetCount == 0)
                .opacity(workout.completedSetCount == 0 ? 0.45 : 1)
                .accessibilityHint(workout.completedSetCount == 0 ? "Complete at least one set before finishing." : "Review and save your workout.")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .background(WorkoutPalette.background)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(WorkoutPalette.border)
                    .frame(height: 1)
            }
        }
    }



    private func selectInitialDisclosure(in workout: Workout) {
        guard expandedExerciseID == nil else { return }
        expandedExerciseID = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) })?.persistentModelID
    }

    private func advanceDisclosure(after completedExercise: ExerciseEntry, in workout: Workout) {
        let orderedExercises = workout.orderedExercises
        guard let completedIndex = orderedExercises.firstIndex(where: {
            $0.persistentModelID == completedExercise.persistentModelID
        }) else {
            return
        }

        let nextExercise = orderedExercises.dropFirst(completedIndex + 1).first(where: {
            $0.orderedSets.contains(where: { !$0.done })
        })

        withAnimation(.snappy) {
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
                focusedInput = SetInputFocus(
                    exerciseID: exercise.persistentModelID,
                    setID: set.persistentModelID
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

        withAnimation(.snappy) {
            var ordered = exercises
            ordered.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            for (index, ex) in ordered.enumerated() {
                ex.orderIndex = index
            }
            viewModel.persistChanges()
        }
    }
}

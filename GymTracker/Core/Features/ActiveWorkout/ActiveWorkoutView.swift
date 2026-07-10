import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Query private var exerciceTemplates: [ExerciceTemplate]

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]

    @State private var viewModel: ActiveWorkoutViewModel
    @State private var expandedExerciseID: PersistentIdentifier?
    @State private var isShowingDiscardConfirmation = false

    private var unitSystem: UnitSystem {
        let rawValue = UserDefaults.standard.string(forKey: "useMetric")
        return UnitSystem(rawValue: rawValue ?? UnitSystem.metric.rawValue) ?? .metric
    }

    init(workoutVM: WorkoutViewModel, navigationPath: Binding<[HomeRoute]>) {
        self.workoutVM = workoutVM
        _navigationPath = navigationPath
        _viewModel = State(initialValue: ActiveWorkoutViewModel(workoutVM: workoutVM))
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        isShowingDiscardConfirmation = true
                    } label: {
                        Label("Discard workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .fontWeight(.semibold)
                }
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
    }

    private func workoutContent(for workout: Workout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sessionHeader(for: workout)

                if viewModel.isTimerVisible, let timerPause = viewModel.timerPause {
                    restTimer(endDate: timerPause)
                }

                exerciseList(for: workout)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(WorkoutPalette.background)
        .safeAreaInset(edge: .bottom) {
            finishButton(for: workout)
        }
        .onAppear {
            selectInitialDisclosure(in: workout)
        }
    }

    private func sessionHeader(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.nom?.isEmpty == false ? workout.nom! : "Today’s workout")
                    .font(.title2.weight(.bold))

                Spacer()

                Text(workout.startTime, style: .timer)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(WorkoutPalette.text)
            }

            HStack {
                Text("\(completedSetCount(in: workout)) / \(totalSetCount(in: workout)) sets")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WorkoutPalette.subduedText)
                Spacer()
                Text("\(workout.exercises.count) exercises")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            ProgressView(value: Double(completedSetCount(in: workout)), total: Double(max(totalSetCount(in: workout), 1)))
                .tint(WorkoutPalette.secondary)
        }
        .padding(14)
        .background(WorkoutPalette.accentSurface)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WorkoutPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func restTimer(endDate: Date) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .foregroundStyle(WorkoutPalette.accent)
                .background(WorkoutPalette.accentSurface)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest between sets")
                    .font(.subheadline.weight(.semibold))
                Text("Take a breath. Your next set is ready when you are.")
                    .font(.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            Spacer(minLength: 0)

            Text(timerInterval: Date.now...endDate, countsDown: true)
                .font(.headline.monospacedDigit())
                .foregroundStyle(WorkoutPalette.accent)
        }
        .padding(14)
        .background(WorkoutPalette.accentSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func exerciseList(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EXERCISES")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(WorkoutPalette.subduedText)

                Spacer()

                NavigationLink {
                    ExerciceLibrairyView(
                        isSelectingExercise: true,
                        availableExercises: exerciceTemplates,
                        onSelect: viewModel.addExercise
                    )
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WorkoutPalette.primary)
                }
                .buttonStyle(.plain)
            }

            if workout.exercises.isEmpty {
                emptyExerciseState
            } else {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.persistentModelID) { _, exercise in
                    ExerciceEntryCard(
                        exerciseEntry: exercise,
                        viewModel: viewModel,
                        onButtonPress: viewModel.startTime,
                        unitSystem: unitSystem,
                        expandedExerciseID: $expandedExerciseID,
                        onExerciseCompleted: {
                            advanceDisclosure(after: exercise, in: workout)
                        }
                    )
                }
            }
        }
    }

    private var emptyExerciseState: some View {
        VStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(WorkoutPalette.secondary)
            Text("Build your session")
                .font(.headline)
            Text("Add an exercise to begin logging your training.")
                .font(.subheadline)
                .foregroundStyle(WorkoutPalette.subduedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(WorkoutPalette.mutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func finishButton(for workout: Workout) -> some View {
        VStack(spacing: 0) {
            Button {
                viewModel.cancelTimer()
                navigationPath.append(.saveWorkout)
            } label: {
                Label("Finish workout", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .foregroundStyle(.white)
                    .background(WorkoutPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(workout.exercises.isEmpty)
            .opacity(workout.exercises.isEmpty ? 0.45 : 1)
            .accessibilityHint(workout.exercises.isEmpty ? "Add an exercise before finishing." : "Review and save your workout.")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(WorkoutPalette.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkoutPalette.border)
                .frame(height: 1)
        }
    }

    private func completedSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter(\.done).count
        }
    }

    private func totalSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func selectInitialDisclosure(in workout: Workout) {
        guard expandedExerciseID == nil else { return }
        expandedExerciseID = workout.exercises.first(where: { $0.sets.contains(where: { !$0.done }) })?.persistentModelID
    }

    private func advanceDisclosure(after completedExercise: ExerciceEntry, in workout: Workout) {
        guard let completedIndex = workout.exercises.firstIndex(where: {
            $0.persistentModelID == completedExercise.persistentModelID
        }) else {
            return
        }

        let nextExercise = workout.exercises.dropFirst(completedIndex + 1).first(where: {
            $0.sets.contains(where: { !$0.done })
        })

        withAnimation(.snappy) {
            expandedExerciseID = nextExercise?.persistentModelID
        }
    }

    private func discardWorkout() {
        viewModel.cancelTimer()
        viewModel.workoutVM.workout = nil
        navigationPath.removeAll()
    }
}

import SwiftUI
import SwiftData

struct WorkoutSaveView: View {
    @Environment(\.modelContext) private var modelContext

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    @Binding var isPresented: Bool
    let onDiscardRequested: () -> Void

    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingPartialSaveConfirmation = false
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        Group {
            if let workout = workoutVM.activeWorkout {
                saveReview(for: workout)
            } else {
                ContentUnavailableView(
                    "No workout to save",
                    systemImage: "checkmark.circle",
                    description: Text("Return home to start a new session.")
                )
            }
        }
        .foregroundStyle(WorkoutPalette.text)
        .background(WorkoutPalette.background.ignoresSafeArea())
        .tint(WorkoutPalette.primary)
        .navigationTitle("Review workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WorkoutPalette.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
    }

    private func saveReview(for workout: Workout) -> some View {
        if workout.completedSetCount == 0 {
            return AnyView(emptySaveReview(for: workout))
        } else {
            return AnyView(standardSaveReview(for: workout))
        }
    }

    private func emptySaveReview(for workout: Workout) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(WorkoutPalette.accent)
                
            VStack(spacing: Spacing.s) {
                Text("Empty Session")
                    .font(AppFont.displayMedium)
                    .multilineTextAlignment(.center)
                Text("No sets have been completed. Add exercises and complete sets to log your training.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(WorkoutPalette.subduedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.l)
            }
            
            Spacer()
            
            VStack(spacing: Spacing.m) {
                Button {
                    navigationPath.removeLast()
                } label: {
                    Text("Return to Workout")
                        .font(AppFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(WorkoutPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button("Discard Workout", role: .destructive) {
                    isShowingDiscardConfirmation = true
                }
                .font(AppFont.subheadlineSemibold)
                .padding(.vertical, Spacing.s)
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.bottom, Spacing.xl)
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
        } message: {
            Text("Your logged sets and notes will not be saved.")
        }
    }

    private func standardSaveReview(for workout: Workout) -> some View {
        @Bindable var workout = workout
        let hasIncomplete = workout.incompleteSetCount > 0

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl - 2) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Image(systemName: hasIncomplete ? "square.and.pencil" : AppIcon.checkmarkCircle)
                        .font(AppFont.title)
                        .foregroundStyle(hasIncomplete ? WorkoutPalette.primary : WorkoutPalette.secondary)
                    Text(hasIncomplete ? "Ready to save?" : "Nice work.")
                        .font(AppFont.displayMedium)
                    Text(hasIncomplete 
                         ? "Only completed sets will be saved to History. Incomplete sets will be excluded."
                         : "Give this session a name, then save it to your history.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("WORKOUT NAME")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(WorkoutPalette.subduedText)
                    TextField(
                        workout.displayTitle,
                        text: Binding(
                            get: { workout.name ?? "" },
                            set: { workout.name = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(AppFont.titleSmallSemibold)
                    .padding(Spacing.l)
                    .background(WorkoutPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("NOTES")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(WorkoutPalette.subduedText)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Binding(
                            get: { workout.notes ?? "" },
                            set: { workout.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .focused($isNotesFocused)
                        .frame(minHeight: notesEditorHeight(for: workout))
                        .padding(Spacing.md)

                        if !hasNotes(for: workout) {
                            Text("Add a note…")
                                .font(AppFont.body)
                                .foregroundStyle(WorkoutPalette.subduedText)
                                .padding(.horizontal, Spacing.l + Spacing.md)
                                .padding(.vertical, Spacing.l)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(WorkoutPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .stroke(WorkoutPalette.border, lineWidth: 1)
                    }
                }

                summaryCard(for: workout)
                exerciseReview(for: workout)
            }
            .padding(Spacing.xl)
            .padding(.bottom, 98)
        }
        .scrollIndicators(.hidden)
        .background(WorkoutPalette.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.md) {
                if workout.incompleteSetCount > 0 {
                    Label(
                        "^[\(saveableSetCount(for: workout)) completed set](inflect: true) will be saved; ^[\(workout.incompleteSetCount) incomplete set](inflect: true) will be excluded",
                        systemImage: AppIcon.warningCircle
                    )
                    .font(AppFont.footnote)
                    .foregroundStyle(WorkoutPalette.accent)
                    .accessibilityLabel("^[\(saveableSetCount(for: workout)) completed set](inflect: true) will be saved. ^[\(workout.incompleteSetCount) incomplete set](inflect: true) will be excluded from History.")
                }

                Button(action: requestSave) {
                    Label("Save workout", systemImage: AppIcon.save)
                        .font(AppFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(WorkoutPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("save-workout")

                Button("Discard workout", role: .destructive) {
                    isShowingDiscardConfirmation = true
                }
                .font(AppFont.subheadlineSemibold)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .background(.ultraThinMaterial)
        }
        .confirmationDialog(
            "Save only completed sets?",
            isPresented: $isShowingPartialSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save completed sets", action: saveWorkout)
            Button("Keep editing") {
                isShowingPartialSaveConfirmation = false
            }
                .accessibilityIdentifier("keep-editing-partial-save")
        } message: {
            Text("^[\(saveableSetCount(for: workout)) completed set](inflect: true) will be saved to History. ^[\(workout.incompleteSetCount) incomplete set](inflect: true) will be excluded. Your workout name and notes will be saved.")
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
        } message: {
            Text("Your logged sets and notes will not be saved.")
        }
    }

    private func workoutDuration(for workout: Workout) -> String {
        let duration = Date.now.timeIntervalSince(workout.startTime)
        let minutes = max(1, Int(duration) / 60)
        return String(localized: "\(minutes) min")
    }

    private func summaryCard(for workout: Workout) -> some View {
        HStack(spacing: 0) {
            summaryMetric(value: workoutDuration(for: workout), label: "Duration")
            Divider().frame(height: 38)
            summaryMetric(value: "\(saveableExercises(for: workout).count)", label: "Exercises")
            Divider().frame(height: 38)
            summaryMetric(value: "\(saveableSetCount(for: workout))", label: "Sets saved")
        }
        .padding(.vertical, Spacing.xl - 2)
        .background(WorkoutPalette.mutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(AppFont.headlineMonospaced)
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseReview(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SESSION SUMMARY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            ForEach(workout.orderedExercises.filter { $0.orderedSets.contains(where: \.done) }, id: \.persistentModelID) { exercise in
                let savedSets = exercise.orderedSets.filter(\.done)
                let incompleteCount = exercise.orderedSets.filter { !$0.done }.count

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: AppIcon.checkmarkCircle)
                            .foregroundStyle(WorkoutPalette.secondary)

                        Text(exercise.exercise.name)
                            .font(AppFont.subheadlineSemibold)

                        Spacer()

                        Text("\(savedSets.count) saved")
                            .font(AppFont.subheadlineMonospaced)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }
                    .padding(Spacing.m)

                    Divider()
                        .padding(.horizontal, Spacing.m)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        let comparison = WorkoutPerformanceComparison(exercise: exercise)
                        if comparison.hasTargets {
                            PerformanceComparisonView(comparison: comparison)
                                .padding(.horizontal, Spacing.m)
                                .padding(.top, Spacing.s)
                        }

                        ForEach(Array(savedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                            HStack(spacing: Spacing.s) {
                                Text("Set \(index + 1)")
                                    .font(AppFont.caption)
                                    .foregroundStyle(WorkoutPalette.subduedText)

                                Spacer()

                                Text(set.displayText())
                                    .font(AppFont.captionSemiboldMonospaced)

                                Image(systemName: AppIcon.checkmark)
                                    .font(.caption2.bold())
                                    .foregroundStyle(WorkoutPalette.secondary)
                            }
                            .padding(.horizontal, Spacing.m + 2)
                            .padding(.vertical, Spacing.xxs)
                        }
                    }
                    .padding(.vertical, Spacing.s)

                    if incompleteCount > 0 {
                        Label("\(incompleteCount) incomplete • excluded from History", systemImage: AppIcon.warningCircle)
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.accent)
                            .padding(.horizontal, Spacing.m + 2)
                            .padding(.bottom, Spacing.m)
                    }
                }
                .background(WorkoutPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(WorkoutPalette.border, lineWidth: 1)
                }
            }
        }
    }

    private func requestSave() {
        guard let workout = workoutVM.activeWorkout else { return }

        if workout.incompleteSetCount > 0 {
            isShowingPartialSaveConfirmation = true
        } else {
            saveWorkout()
        }
    }

    private func hasNotes(for workout: Workout) -> Bool {
        !(workout.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private func notesEditorHeight(for workout: Workout) -> CGFloat {
        hasNotes(for: workout) || isNotesFocused ? 104 : 44
    }

    private func saveableExercises(for workout: Workout) -> [ExerciseEntry] {
        workout.orderedExercises.filter { exercise in
            exercise.orderedSets.contains(where: \.done)
        }
    }

    private func saveableSetCount(for workout: Workout) -> Int {
        saveableExercises(for: workout).reduce(0) { total, exercise in
            total + exercise.orderedSets.filter(\.done).count
        }
    }

    private func saveWorkout() {
        guard workoutVM.saveWorkout(using: modelContext) else { return }
        navigationPath.removeAll()
        isPresented = false
    }

    private func discardWorkout() {
        navigationPath.removeAll()
        onDiscardRequested()
    }
}

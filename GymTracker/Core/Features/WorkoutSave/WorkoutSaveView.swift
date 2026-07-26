import SwiftUI
import SwiftData

struct WorkoutSaveView: View {
    @Environment(\.modelContext) private var modelContext

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [ActiveWorkoutRoute]
    @Binding var isPresented: Bool
    let onWorkoutSaved: (UUID) -> Void
    let onDiscardRequested: () -> Void

    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingPartialSaveConfirmation = false
    @State private var saveErrorMessage: String?
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
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground.ignoresSafeArea())
        .tint(Color.gymPrimary)
        .navigationTitle("Review workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.gymBackground, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNotesFocused = false
                }
                .accessibilityIdentifier("dismiss-review-notes-keyboard")
            }
        }
        .alert(
            "Couldn’t save workout",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
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
            
            Image(systemName: AppIcon.warningFill)
                .font(AppFont.displayLarge)
                .foregroundStyle(Color.gymAccent)
                
            VStack(spacing: Spacing.s) {
                Text("Empty Session")
                    .font(AppFont.displayMedium)
                    .multilineTextAlignment(.center)
                Text("No sets have been completed. Add exercises and complete sets to log your training.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.l)
                repeatingPlanSaveContext(for: workout)
                    .multilineTextAlignment(.center)
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
                        .background(Color.gymPrimary)
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
            Text(discardConfirmationMessage(for: workout))
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
                        .foregroundStyle(hasIncomplete ? Color.gymPrimary : Color.gymSecondary)
                    Text(hasIncomplete ? "Ready to save?" : "Nice work.")
                        .font(AppFont.displayMedium)
                    Text(hasIncomplete 
                         ? "Only completed sets will be saved to History. Incomplete sets will be excluded."
                         : "Give this session a name, then save it to your history.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                    repeatingPlanSaveContext(for: workout)
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("WORKOUT NAME")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymSubduedText)
                    TextField(
                        workout.displayTitle,
                        text: Binding(
                            get: { workout.name ?? "" },
                            set: { workout.name = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(AppFont.titleSmallSemibold)
                    .padding(Spacing.l)
                    .background(Color.gymCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("NOTES")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymSubduedText)

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
                                .foregroundStyle(Color.gymSubduedText)
                                .padding(.horizontal, Spacing.l + Spacing.md)
                                .padding(.vertical, Spacing.l)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Color.gymCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .stroke(Color.gymBorder, lineWidth: 1)
                    }
                }

                summaryCard(for: workout)
                exerciseReview(for: workout)
            }
            .padding(Spacing.xl)
            .padding(.bottom, 98)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gymBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.md) {
                if workout.incompleteSetCount > 0 {
                    Label(
                        "^[\(saveableSetCount(for: workout)) completed set](inflect: true) will be saved; ^[\(workout.incompleteSetCount) incomplete set](inflect: true) will be excluded",
                        systemImage: AppIcon.warningCircle
                    )
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymAccent)
                    .accessibilityLabel("^[\(saveableSetCount(for: workout)) completed set](inflect: true) will be saved. ^[\(workout.incompleteSetCount) incomplete set](inflect: true) will be excluded from History.")
                }

                Button(action: requestSave) {
                    Label("Save workout", systemImage: AppIcon.save)
                        .font(AppFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(Color.gymPrimary)
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
            partialSaveConfirmationMessage(for: workout)
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
        } message: {
            Text(discardConfirmationMessage(for: workout))
        }
    }

    @ViewBuilder
    private func repeatingPlanSaveContext(for workout: Workout) -> some View {
        if let repeatingPlanName = repeatingPlanName(for: workout) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Label("Rotation: \(repeatingPlanName)", systemImage: AppIcon.routine)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymSecondary)
                Text("When this workout saves successfully, the rotation advances to the next workout.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Rotation \(repeatingPlanName). It advances only after this workout is saved successfully."
            )
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

    @ViewBuilder
    private func partialSaveConfirmationMessage(for workout: Workout) -> some View {
        Text("^[\(saveableSetCount(for: workout)) completed set](inflect: true) will be saved to History. ^[\(workout.incompleteSetCount) incomplete set](inflect: true) will be excluded. Your workout name and notes will be saved.")
        if let repeatingPlanName = repeatingPlanName(for: workout) {
            Text("When the save succeeds, \(repeatingPlanName) advances to the next workout.")
        }
    }

    private func discardConfirmationMessage(for workout: Workout) -> String {
        let base = String(localized: "Your logged sets and notes will not be saved.")
        guard let repeatingPlanName = repeatingPlanName(for: workout) else {
            return base
        }
        return String(
            localized: "Your logged sets and notes will not be saved. \(repeatingPlanName) will not advance."
        )
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
        .background(Color.gymMutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(AppFont.headlineMonospaced)
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseReview(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SESSION SUMMARY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            ForEach(workout.orderedExercises.filter { $0.orderedSets.contains(where: \.done) }, id: \.persistentModelID) { exercise in
                let savedSets = exercise.orderedSets.filter(\.done)
                let incompleteCount = exercise.orderedSets.filter { !$0.done }.count

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: AppIcon.checkmarkCircle)
                            .foregroundStyle(Color.gymSecondary)

                        Text(exercise.exercise.name)
                            .font(AppFont.subheadlineSemibold)

                        Spacer()

                        Text("\(savedSets.count) saved")
                            .font(AppFont.subheadlineMonospaced)
                            .foregroundStyle(Color.gymSubduedText)
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
                                    .foregroundStyle(Color.gymSubduedText)

                                Spacer()

                                Text(set.displayText())
                                    .font(AppFont.captionSemiboldMonospaced)

                                Image(systemName: AppIcon.checkmark)
                                    .font(AppFont.caption2Bold)
                                    .foregroundStyle(Color.gymSecondary)
                            }
                            .padding(.horizontal, Spacing.m + 2)
                            .padding(.vertical, Spacing.xxs)
                        }
                    }
                    .padding(.vertical, Spacing.s)

                    if incompleteCount > 0 {
                        Label("\(incompleteCount) incomplete • excluded from History", systemImage: AppIcon.warningCircle)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymAccent)
                            .padding(.horizontal, Spacing.m + 2)
                            .padding(.bottom, Spacing.m)
                    }
                }
                .background(Color.gymCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.gymBorder, lineWidth: 1)
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
        guard let workoutID = workoutVM.activeWorkout?.id,
              workoutVM.saveWorkout(using: modelContext)
        else {
            saveErrorMessage = String(localized: "Your workout is still open. Try saving again.")
            return
        }
        onWorkoutSaved(workoutID)
        navigationPath.removeAll()
        isPresented = false
    }

    private func discardWorkout() {
        navigationPath.removeAll()
        onDiscardRequested()
    }
}

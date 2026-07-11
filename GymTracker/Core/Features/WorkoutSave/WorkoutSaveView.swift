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
        .navigationTitle("Finish workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WorkoutPalette.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    navigationPath.removeLast()
                }
            }
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
                    Text(hasIncomplete ? "Review your workout." : "Nice work.")
                        .font(AppFont.displayMedium)
                    Text(hasIncomplete 
                         ? "You have some incomplete sets. You can save the completed ones."
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
                        "Today’s workout",
                        text: Binding(
                            get: { workout.nom ?? "" },
                            set: { workout.nom = $0.isEmpty ? nil : $0 }
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

                    TextEditor(text: Binding(
                        get: { workout.notes ?? "" },
                        set: { workout.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 90)
                    .padding(Spacing.md)
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
                        "\(workout.incompleteSetCount) sets are still incomplete",
                        systemImage: AppIcon.warningCircle
                    )
                    .font(AppFont.footnote)
                    .foregroundStyle(WorkoutPalette.accent)
                    .accessibilityLabel("\(workout.incompleteSetCount) sets are still incomplete. You can save a partial workout or return to finish them.")
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
            "Save partial workout?",
            isPresented: $isShowingPartialSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save completed sets", action: saveWorkout)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Incomplete sets will remain in the session, but only completed sets count toward your progress.")
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
            summaryMetric(value: "\(workout.exercises.count)", label: "Exercises")
            Divider().frame(height: 38)
            summaryMetric(value: "\(workout.completedSetCount)", label: "Sets done")
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

            ForEach(Array(workout.exercises.enumerated()), id: \.element.persistentModelID) { _, exercise in
                let completedCount = exercise.sets.filter(\.done).count
                let totalCount = exercise.sets.count
                let statusIcon = completedCount == totalCount ? AppIcon.checkmarkCircle : (completedCount > 0 ? "minus.circle.fill" : "circle")
                let statusColor = completedCount == totalCount ? WorkoutPalette.secondary : (completedCount > 0 ? WorkoutPalette.primary : WorkoutPalette.subduedText.opacity(0.6))

                HStack(spacing: Spacing.m) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)

                    Text(exercise.exercice.name)
                        .font(AppFont.subheadlineSemibold)

                    Spacer()

                    Text("\(completedCount)/\(totalCount)")
                        .font(AppFont.subheadlineMonospaced)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }
                .padding(Spacing.m - 1)
                .background(WorkoutPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.large - 1, style: .continuous))
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

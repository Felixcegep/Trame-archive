import SwiftUI
import SwiftData

struct WorkoutSaveView: View {
    @Environment(\.modelContext) private var modelContext

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    @Binding var isPresented: Bool

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
        @Bindable var workout = workout

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(WorkoutPalette.secondary)
                    Text("Nice work.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Give this session a name, then save it to your history.")
                        .font(.subheadline)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("WORKOUT NAME")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkoutPalette.subduedText)
                    TextField(
                        "Today’s workout",
                        text: Binding(
                            get: { workout.nom ?? "" },
                            set: { workout.nom = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(.title3.weight(.semibold))
                    .padding(16)
                    .background(WorkoutPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTES")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkoutPalette.subduedText)

                    TextEditor(text: Binding(
                        get: { workout.notes ?? "" },
                        set: { workout.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 90)
                    .padding(10)
                    .background(WorkoutPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WorkoutPalette.border, lineWidth: 1)
                    }
                }

                summaryCard(for: workout)
                exerciseReview(for: workout)
            }
            .padding(20)
            .padding(.bottom, 98)
        }
        .scrollIndicators(.hidden)
        .background(WorkoutPalette.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if incompleteSetCount(in: workout) > 0 {
                    Label(
                        "\(incompleteSetCount(in: workout)) sets are still incomplete",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(WorkoutPalette.accent)
                    .accessibilityLabel("\(incompleteSetCount(in: workout)) sets are still incomplete. You can save a partial workout or return to finish them.")
                }

                Button(action: requestSave) {
                    Label("Save workout", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(WorkoutPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(completedSetCount(in: workout) == 0)
                .opacity(completedSetCount(in: workout) == 0 ? 0.45 : 1)

                Button("Discard workout", role: .destructive) {
                    isShowingDiscardConfirmation = true
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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

    private func summaryCard(for workout: Workout) -> some View {
        HStack(spacing: 0) {
            summaryMetric(value: "\(workout.exercises.count)", label: "Exercises")
            Divider().frame(height: 38)
            summaryMetric(value: "\(completedSetCount(in: workout))", label: "Sets done")
            Divider().frame(height: 38)
            summaryMetric(value: workout.startTime.formatted(.dateTime.hour().minute()), label: "Started")
        }
        .padding(.vertical, 18)
        .background(WorkoutPalette.mutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseReview(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SESSION SUMMARY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            ForEach(Array(workout.exercises.enumerated()), id: \.element.persistentModelID) { _, exercise in
                HStack(spacing: 12) {
                    Image(systemName: exercise.sets.allSatisfy(\.done) ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(exercise.sets.allSatisfy(\.done) ? WorkoutPalette.secondary : WorkoutPalette.accent)

                    Text(exercise.exercice.name)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("\(exercise.sets.filter(\.done).count)/\(exercise.sets.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(WorkoutPalette.subduedText)
                }
                .padding(15)
                .background(WorkoutPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }

    private func completedSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    private func incompleteSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.done }.count }
    }

    private func requestSave() {
        guard let workout = workoutVM.activeWorkout else { return }

        if incompleteSetCount(in: workout) > 0 {
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
        workoutVM.discardActiveWorkout()
        navigationPath.removeAll()
        isPresented = false
    }
}

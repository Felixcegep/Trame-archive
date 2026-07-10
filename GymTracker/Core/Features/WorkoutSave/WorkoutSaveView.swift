import SwiftUI
import SwiftData

struct WorkoutSaveView: View {
    @Environment(\.modelContext) private var modelContext

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]

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

                summaryCard(for: workout)
                exerciseReview(for: workout)
            }
            .padding(20)
            .padding(.bottom, 98)
        }
        .scrollIndicators(.hidden)
        .background(WorkoutPalette.background)
        .safeAreaInset(edge: .bottom) {
            Button(action: saveWorkout) {
                Label("Save workout", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .foregroundStyle(.white)
                    .background(WorkoutPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
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

    private func saveWorkout() {
        workoutVM.saveWorkout(using: modelContext)
        navigationPath.removeAll()
    }
}

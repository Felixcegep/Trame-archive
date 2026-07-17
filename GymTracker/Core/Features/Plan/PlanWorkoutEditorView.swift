import SwiftData
import SwiftUI

struct PlanWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: PlanWorkoutDraft
    let exercises: [Exercise]
    @State private var selectedExerciseIndex: Int?
    @State private var isShowingExerciseEditor = false
    @State private var isShowingExercisePicker = false

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $workout.name)
                Stepper("Day \(workout.dayOffset + 1)", value: $workout.dayOffset, in: 0...6)
            }

            Section("Exercises") {
                if workout.exercises.isEmpty {
                    ContentUnavailableView("No exercises", systemImage: AppIcon.workout, description: Text("Add an exercise to prescribe this workout."))
                } else {
                    ForEach($workout.exercises) { $exercise in
                        Button {
                            selectedExerciseIndex = workout.exercises.firstIndex { $0.id == exercise.id }
                            isShowingExerciseEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(exercise.displayName)
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(Color.gymText)
                                Text(exercise.summary)
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("plan-workout-exercise")
                    }
                    .onDelete { workout.exercises.remove(atOffsets: $0) }
                    .onMove { workout.exercises.move(fromOffsets: $0, toOffset: $1) }
                }

                Button("Add Exercise", systemImage: AppIcon.plus) {
                    isShowingExercisePicker = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(workout.name.isEmpty ? "Workout" : workout.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $isShowingExerciseEditor) {
            if let index = selectedExerciseIndex {
                NavigationStack {
                    PlanExerciseEditorView(
                        exercise: $workout.exercises[index],
                        availableExercises: exercises
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                PlanExercisePickerView(exercises: exercises) { exercise in
                    workout.exercises.append(PlanExerciseDraft(exercise: exercise, orderIndex: workout.exercises.count))
                    isShowingExercisePicker = false
                }
            }
        }
    }
}

struct PlanExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @State private var searchText = ""

    var body: some View {
        List(filteredExercises, id: \.persistentModelID) { exercise in
            Button {
                onSelect(exercise)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(exercise.name)
                        .foregroundStyle(Color.gymText)
                    Text(exercise.subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exercises.sorted { $0.name < $1.name } }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

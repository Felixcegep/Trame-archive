import SwiftData
import SwiftUI

struct PlanWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: PlanWorkoutDraft
    let exercises: [Exercise]
    @State private var selectedExerciseIndex: Int?
    @State private var isShowingExerciseEditor = false
    @State private var isShowingExercisePicker = false
    @State private var groupingExerciseID: UUID?

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $workout.name)
                Stepper("Day \(workout.dayOffset + 1)", value: $workout.dayOffset, in: 0...6)
                Toggle("Optional session", isOn: $workout.isOptional)
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
                        .contextMenu {
                            if exercise.supersetGroupID == nil {
                                Button("Superset with…") {
                                    groupingExerciseID = exercise.id
                                }
                            } else {
                                Button("Remove from superset") {
                                    exercise.supersetGroupID = nil
                                    normalizeSupersetGroups()
                                }
                            }
                        }
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
        .confirmationDialog(
            "Superset with…",
            isPresented: Binding(
                get: { groupingExerciseID != nil },
                set: { if !$0 { groupingExerciseID = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let sourceID = groupingExerciseID {
                ForEach(workout.exercises.filter { $0.id != sourceID && $0.supersetGroupID == nil }) { candidate in
                    Button(candidate.displayName) {
                        createSuperset(sourceID: sourceID, candidateID: candidate.id)
                    }
                }
            }
        }
    }

    private func createSuperset(sourceID: UUID, candidateID: UUID) {
        guard
            let sourceIndex = workout.exercises.firstIndex(where: { $0.id == sourceID }),
            let candidateIndex = workout.exercises.firstIndex(where: { $0.id == candidateID })
        else { return }
        let groupID = UUID()
        workout.exercises[sourceIndex].supersetGroupID = groupID
        workout.exercises[candidateIndex].supersetGroupID = groupID
        let candidate = workout.exercises.remove(at: candidateIndex)
        let adjustedSourceIndex = candidateIndex < sourceIndex ? sourceIndex - 1 : sourceIndex
        workout.exercises.insert(candidate, at: adjustedSourceIndex + 1)
        groupingExerciseID = nil
    }

    private func normalizeSupersetGroups() {
        let groups = Dictionary(grouping: workout.exercises.compactMap { draft in
            draft.supersetGroupID.map { ($0, draft.id) }
        }, by: \.0)
        for (_, members) in groups where members.count < 2 {
            for member in members {
                if let index = workout.exercises.firstIndex(where: { $0.id == member.1 }) {
                    workout.exercises[index].supersetGroupID = nil
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

//
//  WorkoutTemplateFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

/// Builds a saved workout: name it, pick exercises, order them, pair them.
///
/// Supersets already existed in the plan editor and during a live session, but
/// not here — so a workout you could improvise or prescribe could not be saved.
/// Selection is an ordered list rather than a name set, because a superset is
/// defined by contiguous position.
struct WorkoutTemplateFormView: View {
    /// Selection has to survive reordering and grouping, so each pick gets its
    /// own identity rather than being keyed by the exercise it points at.
    private struct Selection: Identifiable, Equatable {
        let id = UUID()
        let exercise: Exercise
        var supersetGroupID: UUID?
        var targetSets = 3
        var repRangeMinimum = 8
        var repRangeMaximum = 12
        var restSeconds = 90
        var targetRIR: Int?
        var targetRPE: Double?
        var notes: String?

        static func == (lhs: Selection, rhs: Selection) -> Bool {
            lhs.id == rhs.id && lhs.supersetGroupID == rhs.supersetGroupID
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let availableExercises: [Exercise]
    let onSave: (String, [TemplateExercise]) -> Void

    @State private var name = ""
    @State private var selection: [Selection] = []
    @State private var detailExercise: Exercise?
    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var isCreatingExercise = false
    @State private var isShowingPersonalizedBuilder = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("template-name-field")

                if FeatureFlags.current.isEnabled(.workoutGeneration) {
                    Button {
                        isShowingPersonalizedBuilder = true
                    } label: {
                        Label("Draft a personalized workout", systemImage: AppIcon.recipeGenerate)
                    }
                    .accessibilityIdentifier("template-personalized-workout-entry")
                    Text("Use your goals, equipment, and available time to draft an editable workout.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }

            if !selection.isEmpty {
                selectedSection
            }

            exercisePickerSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationDestination(item: $detailExercise) { exercise in
            ExerciseView(exercise: ExerciseDetailSnapshot(exercise: exercise))
        }
        .navigationTitle("New Workout")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(trimmedName, templateExercises)
                    dismiss()
                }
                .accessibilityIdentifier("save-template")
                .disabled(trimmedName.isEmpty)
            }
        }
        .sheet(isPresented: $isCreatingExercise) {
            NavigationStack {
                ExerciseFormView { exercise in
                    _ = LibraryService.createCustomExercise(exercise, using: modelContext)
                }
            }
        }
        .sheet(isPresented: $isShowingPersonalizedBuilder) {
            PersonalizedWorkoutBuilderView(
                availableExercises: availableExercises,
                onApply: applyGeneratedDraft
            )
        }
    }
}

// MARK: - Selected exercises

private extension WorkoutTemplateFormView {
    var selectedSection: some View {
        Section {
            ForEach(Array(selection.enumerated()), id: \.element.id) { index, item in
                selectedRow(at: index, item: item)
            }
        } header: {
            Text("Selected · \(selection.count)")
        } footer: {
            if selection.contains(where: { $0.supersetGroupID != nil }) {
                Text("Superset exercises are performed back to back with no rest between them.")
            }
        }
    }

    private func selectedRow(at index: Int, item: Selection) -> some View {
        HStack(spacing: Spacing.m) {
            if item.supersetGroupID != nil {
                Image(systemName: AppIcon.relationship)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
                    .frame(width: 20)
                    .accessibilityLabel("In a superset")
            } else {
                Color.clear.frame(width: 20)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.exercise.name)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                if item.supersetGroupID != nil {
                    Text("Superset")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymPrimary)
                }
            }

            Spacer(minLength: Spacing.s)

            Menu {
                Button("Move up") { move(from: index, to: index - 1) }
                    .disabled(index == 0)
                Button("Move down") { move(from: index, to: index + 1) }
                    .disabled(index == selection.count - 1)

                if item.supersetGroupID == nil {
                    Button("Superset with next") { supersetWithNext(at: index) }
                        .disabled(!canSupersetWithNext(at: index))
                } else {
                    Button("Remove from superset") { removeFromSuperset(at: index) }
                }

                Button("Remove", role: .destructive) { remove(at: index) }
            } label: {
                Image(systemName: AppIcon.ellipsis)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(item.exercise.name)")
            .accessibilityIdentifier("template-selected-menu-\(item.exercise.name)")
        }
        .accessibilityIdentifier("template-selected-\(item.exercise.name)")
    }
}

// MARK: - Exercise picker

private extension WorkoutTemplateFormView {
    var exercisePickerSection: some View {
        let results = filteredExercises

        return Section {
            if availableExercises.isEmpty {
                ContentUnavailableView {
                    Label("No exercises yet", systemImage: AppIcon.workout)
                } description: {
                    Text("Create an exercise to start building this workout.")
                } actions: {
                    Button("Create Exercise") {
                        isCreatingExercise = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gymPrimary)
                    .accessibilityIdentifier("create-exercise-empty-state")
                }
            } else {
                ExerciseFilterControls(filter: $filter, resultCount: results.count)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                if results.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("No exercises match your filters.")
                                .foregroundStyle(Color.gymSubduedText)
                            Button("Clear filters") {
                                filter.clear()
                            }
                            .font(AppFont.subheadlineSemibold)
                        }
                    }
                } else {
                    ForEach(results, id: \.id) { exercise in
                        ExerciseSelectionRow(
                            exercise: exercise,
                            isSelected: isSelected(exercise),
                            onSelect: { toggle(exercise) },
                            onShowDetail: { detailExercise = exercise }
                        )
                    }
                }
            }
        } header: {
            Text("Exercises")
        }
    }
}

// MARK: - Selection editing

private extension WorkoutTemplateFormView {
    func isSelected(_ exercise: Exercise) -> Bool {
        selection.contains { $0.exercise.id == exercise.id }
    }

    func toggle(_ exercise: Exercise) {
        if let index = selection.firstIndex(where: { $0.exercise.id == exercise.id }) {
            remove(at: index)
        } else {
            selection.append(Selection(exercise: exercise, supersetGroupID: nil))
        }
    }

    func applyGeneratedDraft(_ draft: ValidatedWorkoutDraft) {
        name = draft.name
        selection = draft.exercises.map { item in
            Selection(
                exercise: item.exercise,
                supersetGroupID: item.supersetGroupID,
                targetSets: item.targetSets,
                repRangeMinimum: item.repRangeMinimum,
                repRangeMaximum: item.repRangeMaximum,
                restSeconds: item.restSeconds,
                targetRIR: item.targetRIR,
                targetRPE: item.targetRPE,
                notes: item.notes
            )
        }
        normalizeSupersets()
    }

    func remove(at index: Int) {
        guard selection.indices.contains(index) else { return }
        selection.remove(at: index)
        normalizeSupersets()
    }

    /// Moving an exercise out of its pair's neighbourhood dissolves the pair
    /// rather than silently dragging the partner along.
    func move(from index: Int, to destination: Int) {
        guard selection.indices.contains(index), selection.indices.contains(destination) else { return }
        let item = selection.remove(at: index)
        selection.insert(item, at: destination)
        normalizeSupersets()
    }

    func canSupersetWithNext(at index: Int) -> Bool {
        selection.indices.contains(index + 1)
    }

    /// Pairing with an already-grouped neighbour extends that group, so three or
    /// more exercises can share one superset without a separate control.
    func supersetWithNext(at index: Int) {
        guard canSupersetWithNext(at: index) else { return }
        let groupID = selection[index + 1].supersetGroupID ?? UUID()
        selection[index].supersetGroupID = groupID
        selection[index + 1].supersetGroupID = groupID
        normalizeSupersets()
    }

    func removeFromSuperset(at index: Int) {
        guard selection.indices.contains(index) else { return }
        selection[index].supersetGroupID = nil
        normalizeSupersets()
    }

    /// Mirrors `SupersetGrouping`'s rule — at least two contiguous members —
    /// against the in-memory draft, which has no `TemplateExercise` yet.
    func normalizeSupersets() {
        let grouped = Dictionary(grouping: selection.indices.compactMap { index in
            selection[index].supersetGroupID.map { ($0, index) }
        }, by: \.0)

        for (groupID, members) in grouped {
            let indexes = members.map(\.1).sorted()
            let isContiguous = indexes.enumerated().allSatisfy { offset, index in
                index == indexes[0] + offset
            }
            guard indexes.count >= 2, isContiguous else {
                for index in selection.indices where selection[index].supersetGroupID == groupID {
                    selection[index].supersetGroupID = nil
                }
                continue
            }
        }
    }
}

// MARK: - Output

private extension WorkoutTemplateFormView {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredExercises: [Exercise] {
        availableExercises
            .filter { filter.matches($0, searchText: searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var templateExercises: [TemplateExercise] {
        let built = selection.enumerated().map { index, item in
            TemplateExercise(
                exercise: item.exercise,
                order: index,
                targetSets: item.targetSets,
                repRangeMinimum: item.repRangeMinimum,
                repRangeMaximum: item.repRangeMaximum,
                restSeconds: item.restSeconds,
                targetRPE: item.targetRPE,
                targetRIR: item.targetRIR,
                notes: item.notes,
                supersetGroupID: item.supersetGroupID
            )
        }
        SupersetGrouping.dissolveInvalidGroups(in: built)
        return built
    }
}

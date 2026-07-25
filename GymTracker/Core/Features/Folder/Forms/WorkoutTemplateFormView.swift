//
//  WorkoutTemplateFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct WorkoutTemplateFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let availableExercises: [Exercise]
    let onSave: (String, [Exercise]) -> Void

    @State private var name = ""
    @State private var selectedExerciseNames: Set<String> = []
    @State private var detailExercise: Exercise?
    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var isCreatingExercise = false

    var body: some View {
        let results = filteredExercises

        Form {
            Section {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("template-name-field")
            }

            Section {
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
                    if !selectedExercises.isEmpty {
                        selectedExercisesStrip
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }

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
                                isSelected: selectedExerciseNames.contains(exercise.name),
                                onSelect: {
                                    toggle(exercise.name, in: &selectedExerciseNames)
                                },
                                onShowDetail: {
                                    detailExercise = exercise
                                }
                            )
                        }
                    }
                }
            } header: {
                if selectedExerciseNames.isEmpty {
                    Text("Exercises")
                } else {
                    Text("Exercises · \(selectedExerciseNames.count) selected")
                }
            }
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
                    onSave(trimmedName, selectedExercises)
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
    }

    private var selectedExercisesStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                ForEach(selectedExercises, id: \.id) { exercise in
                    Button {
                        toggle(exercise.name, in: &selectedExerciseNames)
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(exercise.name)
                                .font(AppFont.subheadlineSemibold)
                                .lineLimit(1)
                            Image(systemName: AppIcon.remove)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.m)
                        .frame(height: 34)
                        .background(Color.gymSecondary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("template-selected-\(exercise.name)")
                    .accessibilityLabel("Remove \(exercise.name)")
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .scrollIndicators(.hidden)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExercises: [Exercise] {
        availableExercises
            .filter { filter.matches($0, searchText: searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedExercises: [Exercise] {
        availableExercises.filter { selectedExerciseNames.contains($0.name) }
    }
}

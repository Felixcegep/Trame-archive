//
//  WorkoutTemplateFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct WorkoutTemplateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let availableExercises: [Exercise]
    let onSave: (String, [Exercise]) -> Void

    @State private var name = ""
    @State private var selectedExerciseNames: Set<String> = []
    @State private var detailExercise: Exercise?
    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("template-name-field")
            }

            Section {
                if availableExercises.isEmpty {
                    Text("Create an exercise first")
                        .foregroundStyle(.secondary)
                } else {
                    ExerciseFilterControls(filter: $filter, resultCount: filteredExercises.count)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    if filteredExercises.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("No exercises match your search or filters.")
                                .foregroundStyle(Color.gymSubduedText)
                            Button("Clear filters") {
                                searchText = ""
                                filter.clear()
                            }
                            .font(AppFont.subheadlineSemibold)
                        }
                    } else {
                        ForEach(filteredExercises, id: \.self) { exercise in
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
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search exercises"
        )
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
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

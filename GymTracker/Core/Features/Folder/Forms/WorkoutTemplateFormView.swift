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

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("template-name-field")
            }

            Section("Exercises") {
                if availableExercises.isEmpty {
                    Text("Create an exercise first")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableExercises, id: \.self) { exercise in
                        ExerciseSelectionRow(
                            exercise: exercise,
                            isSelected: selectedExerciseNames.contains(exercise.name)
                        ) {
                            toggle(exercise.name, in: &selectedExerciseNames)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
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

    private var selectedExercises: [Exercise] {
        availableExercises.filter { selectedExerciseNames.contains($0.name) }
    }
}

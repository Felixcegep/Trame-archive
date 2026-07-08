//
//  ExerciseFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (ExerciceTemplate) -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var trackingType: TrackingType = .weightAndReps
    @State private var primaryMuscles: Set<Muscle> = [.middleChest]
    @State private var secondaryMuscles: Set<Muscle> = []
    @State private var difficulty: Difficulty = .beginner

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                Picker("Tracking", selection: $trackingType) {
                    ForEach(TrackingType.allCases, id: \.self) { trackingType in
                        Text(trackingType.rawValue).tag(trackingType)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue).tag(difficulty)
                    }
                }
            }

            MuscleSelectionSection(
                title: "Primary Muscles",
                selectedMuscles: primaryMuscles,
                onSelect: togglePrimaryMuscle
            )

            MuscleSelectionSection(
                title: "Secondary Muscles",
                selectedMuscles: secondaryMuscles,
                onSelect: toggleSecondaryMuscle
            )
        }
        .navigationTitle("New Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(newExercise)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty || primaryMuscles.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var newExercise: ExerciceTemplate {
        ExerciceTemplate(
            name: trimmedName,
            PrimaryMuscle: sortedMuscles(primaryMuscles),
            SecondaryMuscle: secondaryMuscles.isEmpty ? nil : sortedMuscles(secondaryMuscles),
            category: category,
            trackingType: trackingType,
            difficulty: difficulty
        )
    }

    private func togglePrimaryMuscle(_ muscle: Muscle) {
        if primaryMuscles.contains(muscle) {
            primaryMuscles.remove(muscle)
        } else {
            primaryMuscles.insert(muscle)
            secondaryMuscles.remove(muscle)
        }
    }

    private func toggleSecondaryMuscle(_ muscle: Muscle) {
        if secondaryMuscles.contains(muscle) {
            secondaryMuscles.remove(muscle)
        } else {
            secondaryMuscles.insert(muscle)
            primaryMuscles.remove(muscle)
        }
    }

    private func sortedMuscles(_ muscles: Set<Muscle>) -> [Muscle] {
        Muscle.allCases.filter { muscles.contains($0) }
    }
}

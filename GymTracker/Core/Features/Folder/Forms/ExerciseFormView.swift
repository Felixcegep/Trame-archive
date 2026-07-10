//
//  ExerciseFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: ExerciceTemplate?
    let onSave: (ExerciceTemplate) -> Void

    @State private var name: String
    @State private var category: ExerciseCategory
    @State private var equipmentType: EquipmentType
    @State private var trackingType: TrackingType
    @State private var resistanceType: ResistanceType?
    @State private var movementPattern: MovementPattern?
    @State private var primaryMuscles: Set<Muscle>
    @State private var secondaryMuscles: Set<Muscle>
    @State private var difficulty: Difficulty
    @State private var tagsText: String

    init(exercise: ExerciceTemplate? = nil, onSave: @escaping (ExerciceTemplate) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _name = State(initialValue: exercise?.name ?? "")
        _category = State(initialValue: exercise?.displayCategory ?? .strength)
        _equipmentType = State(initialValue: exercise?.equipmentType ?? .other)
        _trackingType = State(initialValue: exercise?.trackingType ?? .weightAndReps)
        _resistanceType = State(initialValue: exercise?.resistanceType)
        _movementPattern = State(initialValue: exercise?.movementPattern)
        _primaryMuscles = State(initialValue: Set(exercise?.PrimaryMuscle ?? [.middleChest]))
        _secondaryMuscles = State(initialValue: Set(exercise?.SecondaryMuscle ?? []))
        _difficulty = State(initialValue: exercise?.displayDifficulty ?? .beginner)
        _tagsText = State(initialValue: exercise?.tags.joined(separator: ", ") ?? "")
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                Picker("Equipment", selection: $equipmentType) {
                    ForEach(EquipmentType.allCases, id: \.self) { equipment in
                        Text(equipment.rawValue).tag(equipment)
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

            Section("Movement") {
                Picker("Resistance", selection: $resistanceType) {
                    Text("None").tag(ResistanceType?.none)
                    ForEach(ResistanceType.allCases, id: \.self) { resistance in
                        Text(resistance.rawValue).tag(Optional(resistance))
                    }
                }

                Picker("Movement Pattern", selection: $movementPattern) {
                    Text("None").tag(MovementPattern?.none)
                    ForEach(MovementPattern.allCases, id: \.self) { movement in
                        Text(movement.rawValue).tag(Optional(movement))
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

            Section("Tags") {
                TextField("Tags, separated by commas", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(exercise == nil ? "Add" : "Save") {
                    onSave(savedExercise)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty || primaryMuscles.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var savedExercise: ExerciceTemplate {
        let selectedPrimaryMuscles = sortedMuscles(primaryMuscles)
        let selectedSecondaryMuscles = secondaryMuscles.isEmpty ? nil : sortedMuscles(secondaryMuscles)

        if let exercise {
            exercise.name = trimmedName
            exercise.PrimaryMuscle = selectedPrimaryMuscles
            exercise.SecondaryMuscle = selectedSecondaryMuscles
            exercise.category = category
            exercise.equipmentType = equipmentType
            exercise.trackingType = trackingType
            exercise.resistanceType = resistanceType
            exercise.movementPattern = movementPattern
            exercise.difficulty = difficulty
            exercise.tags = tags
            return exercise
        }

        return ExerciceTemplate(
            name: trimmedName,
            PrimaryMuscle: selectedPrimaryMuscles,
            SecondaryMuscle: selectedSecondaryMuscles,
            category: category,
            trackingType: trackingType,
            equipmentType: equipmentType,
            resistanceType: resistanceType,
            movementPattern: movementPattern,
            difficulty: difficulty,
            tags: tags
        )
    }

    private var tags: [String] {
        Array(Set(tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
            .sorted()
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

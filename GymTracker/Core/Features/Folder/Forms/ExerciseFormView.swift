//
//  ExerciseFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?
    let onSave: (Exercise) -> Void

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
    @State private var isPlateLoaded: Bool

    init(exercise: Exercise? = nil, onSave: @escaping (Exercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _name = State(initialValue: exercise?.name ?? "")
        _category = State(initialValue: exercise?.displayCategory ?? .strength)
        _equipmentType = State(initialValue: exercise?.equipmentType ?? .other)
        _trackingType = State(initialValue: exercise?.trackingType ?? .weightAndReps)
        _resistanceType = State(initialValue: exercise?.resistanceType)
        _movementPattern = State(initialValue: exercise?.movementPattern)
        _primaryMuscles = State(initialValue: Set(exercise?.primaryMuscles ?? [.middleChest]))
        _secondaryMuscles = State(initialValue: Set(exercise?.secondaryMuscles ?? []))
        _difficulty = State(initialValue: exercise?.displayDifficulty ?? .beginner)
        _tagsText = State(initialValue: exercise?.tags.joined(separator: ", ") ?? "")
        _isPlateLoaded = State(initialValue: exercise?.isPlateLoaded ?? false)
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("exercise-name-field")

                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(LocalizedStringKey(category.rawValue)).tag(category)
                    }
                }

                Picker("Equipment", selection: $equipmentType) {
                    ForEach(EquipmentType.allCases, id: \.self) { equipment in
                        Text(LocalizedStringKey(equipment.rawValue)).tag(equipment)
                    }
                }

                Picker("Tracking", selection: $trackingType) {
                    ForEach(TrackingType.allCases, id: \.self) { trackingType in
                        Text(LocalizedStringKey(trackingType.rawValue)).tag(trackingType)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(LocalizedStringKey(difficulty.rawValue)).tag(difficulty)
                    }
                }
            }

            Section("Movement") {
                Picker("Resistance", selection: $resistanceType) {
                    Text("None").tag(ResistanceType?.none)
                    ForEach(ResistanceType.allCases, id: \.self) { resistance in
                        Text(LocalizedStringKey(resistance.rawValue)).tag(Optional(resistance))
                    }
                }

                Picker("Movement Pattern", selection: $movementPattern) {
                    Text("None").tag(MovementPattern?.none)
                    ForEach(MovementPattern.allCases, id: \.self) { movement in
                        Text(LocalizedStringKey(movement.rawValue)).tag(Optional(movement))
                    }
                }
            }

            if trackingType.usesWeight && equipmentType == .barbell {
                Section {
                    Label("Plate calculator enabled", systemImage: AppIcon.plateCalculator)
                } header: {
                    Text("Weight entry")
                } footer: {
                    Text("Barbell exercises use the plate calculator automatically.")
                }
            } else if canConfigurePlateLoading {
                Section {
                    Toggle("Uses weight plates", isOn: $isPlateLoaded)
                } header: {
                    Text("Weight entry")
                } footer: {
                    Text("Enable this for plate-loaded machines or equipment loaded equally on both sides.")
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
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
        .onChange(of: equipmentType) { previousEquipment, equipment in
            if previousEquipment == .barbell && equipment != .barbell {
                isPlateLoaded = false
            } else if equipment != .machine && equipment != .other && equipment != .barbell {
                isPlateLoaded = false
            }
        }
        .onChange(of: trackingType) { _, tracking in
            if !tracking.usesWeight {
                isPlateLoaded = false
            }
        }
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
                .accessibilityIdentifier("save-exercise")
                .disabled(trimmedName.isEmpty || primaryMuscles.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var savedExercise: Exercise {
        let selectedPrimaryMuscles = sortedMuscles(primaryMuscles)
        let selectedSecondaryMuscles = secondaryMuscles.isEmpty ? nil : sortedMuscles(secondaryMuscles)

        if let exercise {
            exercise.name = trimmedName
            exercise.primaryMuscles = selectedPrimaryMuscles
            exercise.secondaryMuscles = selectedSecondaryMuscles
            exercise.category = category
            exercise.equipmentType = equipmentType
            exercise.trackingType = trackingType
            exercise.resistanceType = resistanceType
            exercise.movementPattern = movementPattern
            exercise.difficulty = difficulty
            exercise.tags = tags
            exercise.isPlateLoaded = equipmentType == .barbell || isPlateLoaded
            return exercise
        }

        return Exercise(
            name: trimmedName,
            primaryMuscles: selectedPrimaryMuscles,
            secondaryMuscles: selectedSecondaryMuscles,
            category: category,
            trackingType: trackingType,
            equipmentType: equipmentType,
            resistanceType: resistanceType,
            movementPattern: movementPattern,
            difficulty: difficulty,
            tags: tags,
            isPlateLoaded: equipmentType == .barbell || isPlateLoaded
        )
    }

    private var canConfigurePlateLoading: Bool {
        trackingType.usesWeight && (equipmentType == .machine || equipmentType == .other)
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

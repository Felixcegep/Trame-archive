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
    @State private var forceType: ForceType?
    @State private var mechanics: ExerciseMechanics?
    @State private var gripStyle: GripStyle?
    @State private var stance: ExerciseStance?
    @State private var rangeOfMotion: RangeOfMotion?
    @State private var setupAngleDegrees: Int?
    @State private var variationFamilyID: String
    @State private var primaryMuscles: Set<Muscle>
    @State private var secondaryMuscles: Set<Muscle>
    @State private var difficulty: Difficulty
    @State private var tagsText: String
    @State private var isPlateLoaded: Bool
    @State private var laterality: Laterality
    @State private var repCountingStyle: RepCountingStyle
    @State private var weightEntryStyle: WeightEntryStyle
    @State private var loadUnitCount: Int

    init(exercise: Exercise? = nil, onSave: @escaping (Exercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _name = State(initialValue: exercise?.name ?? "")
        _category = State(initialValue: exercise?.displayCategory ?? .strength)
        _equipmentType = State(initialValue: exercise?.equipmentType ?? .other)
        _trackingType = State(initialValue: exercise?.trackingType ?? .weightAndReps)
        _resistanceType = State(initialValue: exercise?.resistanceType)
        _movementPattern = State(initialValue: exercise?.movementPattern)
        _forceType = State(initialValue: exercise?.forceType)
        _mechanics = State(initialValue: exercise?.mechanics)
        _gripStyle = State(initialValue: exercise?.gripStyle)
        _stance = State(initialValue: exercise?.stance)
        _rangeOfMotion = State(initialValue: exercise?.rangeOfMotion)
        _setupAngleDegrees = State(initialValue: exercise?.setupAngleDegrees)
        _variationFamilyID = State(initialValue: exercise?.variationFamilyID ?? "")
        _primaryMuscles = State(initialValue: Set(exercise?.primaryMuscles ?? [.middleChest]))
        _secondaryMuscles = State(initialValue: Set(exercise?.secondaryMuscles ?? []))
        _difficulty = State(initialValue: exercise?.displayDifficulty ?? .beginner)
        _tagsText = State(initialValue: exercise?.tags.joined(separator: ", ") ?? "")
        _isPlateLoaded = State(initialValue: exercise?.isPlateLoaded ?? false)
        _laterality = State(initialValue: exercise?.laterality ?? .bilateral)
        _repCountingStyle = State(initialValue: exercise?.repCountingStyle ?? .total)
        _weightEntryStyle = State(initialValue: exercise?.weightEntryStyle ?? .totalLoad)
        _loadUnitCount = State(initialValue: exercise?.loadUnitCount ?? 1)
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

            Section("Advanced — Classification") {
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

                Picker("Mechanics", selection: $mechanics) {
                    Text("None").tag(ExerciseMechanics?.none)
                    ForEach(ExerciseMechanics.allCases, id: \.self) { mechanics in
                        Text(LocalizedStringKey(mechanics.rawValue)).tag(Optional(mechanics))
                    }
                }

                Picker("Force", selection: $forceType) {
                    Text("None").tag(ForceType?.none)
                    ForEach(ForceType.allCases, id: \.self) { forceType in
                        Text(LocalizedStringKey(forceType.rawValue)).tag(Optional(forceType))
                    }
                }
            }

            variationSection

            Section("Advanced — Logging") {
                Picker("Laterality", selection: $laterality) {
                    ForEach(Laterality.allCases, id: \.self) { laterality in
                        Text(LocalizedStringKey(laterality.rawValue)).tag(laterality)
                    }
                }
                .pickerStyle(.segmented)

                if laterality == .unilateral {
                    Picker("Rep Counting", selection: $repCountingStyle) {
                        ForEach(RepCountingStyle.allCases, id: \.self) { style in
                            Text(LocalizedStringKey(style.rawValue)).tag(style)
                        }
                    }
                }

                if trackingType.usesWeight {
                    Picker("Weight Entry", selection: $weightEntryStyle) {
                        ForEach(WeightEntryStyle.allCases, id: \.self) { style in
                            Text(LocalizedStringKey(style.rawValue)).tag(style)
                        }
                    }

                    if weightEntryStyle == .perLoadUnit {
                        Stepper("Load Units: \(loadUnitCount)", value: $loadUnitCount, in: 1...4)
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
            handleEquipmentChange(from: previousEquipment, to: equipment)
        }
        .onChange(of: trackingType) { _, tracking in
            handleTrackingChange(tracking)
        }
        .onChange(of: laterality) { _, updatedLaterality in
            handleLateralityChange(updatedLaterality)
        }
        .onChange(of: weightEntryStyle) { _, updatedWeightEntryStyle in
            handleWeightEntryStyleChange(updatedWeightEntryStyle)
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
            exercise.forceType = forceType
            exercise.mechanics = mechanics
            exercise.gripStyle = gripStyle
            exercise.stance = stance
            exercise.rangeOfMotion = rangeOfMotion
            exercise.setupAngleDegrees = setupAngleDegrees
            exercise.variationFamilyID = normalizedVariationFamilyID
            exercise.difficulty = difficulty
            exercise.tags = tags
            exercise.isPlateLoaded = equipmentType == .barbell || isPlateLoaded
            exercise.laterality = laterality
            exercise.repCountingStyle = repCountingStyle
            exercise.weightEntryStyle = weightEntryStyle
            exercise.loadUnitCount = loadUnitCount
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
            forceType: forceType,
            mechanics: mechanics,
            gripStyle: gripStyle,
            stance: stance,
            rangeOfMotion: rangeOfMotion,
            setupAngleDegrees: setupAngleDegrees,
            variationFamilyID: normalizedVariationFamilyID,
            difficulty: difficulty,
            tags: tags,
            isPlateLoaded: equipmentType == .barbell || isPlateLoaded,
            laterality: laterality,
            repCountingStyle: repCountingStyle,
            weightEntryStyle: weightEntryStyle,
            loadUnitCount: loadUnitCount
        )
    }

    private var canConfigurePlateLoading: Bool {
        trackingType.usesWeight && (equipmentType == .machine || equipmentType == .other)
    }

    private var normalizedVariationFamilyID: String? {
        let value = variationFamilyID.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var variationSection: some View {
        Section {
            Picker("Grip", selection: $gripStyle) {
                Text("None").tag(GripStyle?.none)
                ForEach(GripStyle.allCases, id: \.self) { gripStyle in
                    Text(LocalizedStringKey(gripStyle.rawValue)).tag(Optional(gripStyle))
                }
            }

            Picker("Stance", selection: $stance) {
                Text("None").tag(ExerciseStance?.none)
                ForEach(ExerciseStance.allCases, id: \.self) { stance in
                    Text(LocalizedStringKey(stance.rawValue)).tag(Optional(stance))
                }
            }

            Picker("Range of Motion", selection: $rangeOfMotion) {
                Text("None").tag(RangeOfMotion?.none)
                ForEach(RangeOfMotion.allCases, id: \.self) { rangeOfMotion in
                    Text(LocalizedStringKey(rangeOfMotion.rawValue)).tag(Optional(rangeOfMotion))
                }
            }

            Picker("Setup Angle", selection: $setupAngleDegrees) {
                Text("None").tag(Int?.none)
                ForEach(Self.setupAngles, id: \.self) { angle in
                    Text(String(angle) + "°").tag(Optional(angle))
                }
            }

            TextField("Variation family", text: $variationFamilyID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Advanced — Variation")
        } footer: {
            Text("Use a shared family only to help people discover related variants. It does not make exercises interchangeable.")
        }
    }

    private static let setupAngles = Array(stride(from: 0, through: 90, by: 5))

    private func handleEquipmentChange(from previous: EquipmentType, to current: EquipmentType) {
        if previous == .barbell && current != .barbell {
            isPlateLoaded = false
        } else if current != .machine && current != .other && current != .barbell {
            isPlateLoaded = false
        }
    }

    private func handleTrackingChange(_ tracking: TrackingType) {
        guard !tracking.usesWeight else { return }
        isPlateLoaded = false
        weightEntryStyle = .totalLoad
    }

    private func handleLateralityChange(_ laterality: Laterality) {
        if laterality == .bilateral {
            repCountingStyle = .total
        }
    }

    private func handleWeightEntryStyleChange(_ style: WeightEntryStyle) {
        if style == .totalLoad {
            loadUnitCount = 1
        }
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

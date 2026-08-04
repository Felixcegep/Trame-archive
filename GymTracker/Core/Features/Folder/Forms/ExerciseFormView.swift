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
    @State private var sportDiscipline: SportDiscipline?
    @State private var strongmanImplementKind: StrongmanImplementKind?
    @State private var strongmanLoadConvention: LoadConvention?
    @State private var strongmanEventFamily: StrongmanEventFamily?

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
        _sportDiscipline = State(initialValue: exercise?.sportDiscipline)
        _strongmanImplementKind = State(initialValue: exercise?.strongmanImplementProfile?.kind)
        _strongmanLoadConvention = State(initialValue: exercise?.strongmanImplementProfile?.loadConvention)
        _strongmanEventFamily = State(initialValue: exercise?.strongmanEventFamily)
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("exercise-name-field")

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
            }

            Section("Muscles") {
                NavigationLink {
                    MusclePickerView(
                        primaryMuscles: $primaryMuscles,
                        secondaryMuscles: $secondaryMuscles
                    )
                } label: {
                    drillDownRow(
                        icon: AppIcon.muscles,
                        tint: Color.gymPrimary,
                        surface: Color.gymPrimarySurface,
                        title: "Muscles Worked",
                        subtitle: muscleSummary
                    )
                }
                .accessibilityIdentifier("exercise-muscles-link")
            }

            Section {
                NavigationLink {
                    ExerciseAdvancedDetailsView(
                        trackingType: trackingType,
                        equipmentType: equipmentType,
                        category: $category,
                        difficulty: $difficulty,
                        resistanceType: $resistanceType,
                        movementPattern: $movementPattern,
                        mechanics: $mechanics,
                        forceType: $forceType,
                        gripStyle: $gripStyle,
                        stance: $stance,
                        rangeOfMotion: $rangeOfMotion,
                        setupAngleDegrees: $setupAngleDegrees,
                        variationFamilyID: $variationFamilyID,
                        laterality: $laterality,
                        repCountingStyle: $repCountingStyle,
                        weightEntryStyle: $weightEntryStyle,
                        loadUnitCount: $loadUnitCount,
                        isPlateLoaded: $isPlateLoaded,
                        tagsText: $tagsText,
                        sportDiscipline: $sportDiscipline,
                        strongmanImplementKind: $strongmanImplementKind,
                        strongmanLoadConvention: $strongmanLoadConvention,
                        strongmanEventFamily: $strongmanEventFamily
                    )
                } label: {
                    drillDownRow(
                        icon: AppIcon.advanced,
                        tint: Color.gymAccent,
                        surface: Color.gymAccentSurface,
                        title: "Advanced Details",
                        subtitle: advancedSummary
                    )
                }
                .accessibilityIdentifier("exercise-advanced-link")
            } header: {
                Text("More")
            } footer: {
                Text("Everything in Advanced Details is optional — sensible defaults are already applied.")
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
            exercise.sportDiscipline = sportDiscipline
            exercise.strongmanEventFamily = sportDiscipline == .strongman ? strongmanEventFamily : nil
            exercise.strongmanImplementProfile = savedStrongmanImplementProfile
            return exercise
        }

        let newExercise = Exercise(
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
        newExercise.sportDiscipline = sportDiscipline
        newExercise.strongmanEventFamily = sportDiscipline == .strongman ? strongmanEventFamily : nil
        newExercise.strongmanImplementProfile = savedStrongmanImplementProfile
        return newExercise
    }

    /// `nil` unless the discipline is strongman and an implement was chosen —
    /// progressive disclosure means the convention/family pickers underneath
    /// it are never even reachable otherwise, so there is nothing to encode.
    private var savedStrongmanImplementProfile: StrongmanImplementProfile? {
        guard sportDiscipline == .strongman, let strongmanImplementKind else { return nil }
        return StrongmanImplementProfile(kind: strongmanImplementKind, loadConvention: strongmanLoadConvention)
    }

    private var normalizedVariationFamilyID: String? {
        let value = variationFamilyID.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func drillDownRow(
        icon: String,
        tint: Color,
        surface: Color,
        title: LocalizedStringKey,
        subtitle: String
    ) -> some View {
        HStack(spacing: Spacing.m) {
            RoundedRectangle(cornerRadius: Radius.small)
                .fill(surface)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymText)
                Text(subtitle)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var muscleSummary: String {
        let names = sortedMuscles(primaryMuscles).map(\.displayName)
        guard !names.isEmpty else {
            return NSLocalizedString("Choose at least one primary muscle", comment: "")
        }

        var summary = names.prefix(3).joined(separator: " · ")
        if names.count > 3 {
            summary += " +\(names.count - 3)"
        }
        if !secondaryMuscles.isEmpty {
            let format = NSLocalizedString("%d secondary", comment: "Count of secondary muscles")
            summary += " · " + String(format: format, secondaryMuscles.count)
        }
        return summary
    }

    private var advancedSummary: String {
        NSLocalizedString(category.rawValue, comment: "")
            + " · "
            + NSLocalizedString(difficulty.rawValue, comment: "")
    }

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

    private func sortedMuscles(_ muscles: Set<Muscle>) -> [Muscle] {
        Muscle.allCases.filter { muscles.contains($0) }
    }
}

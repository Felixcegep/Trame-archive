//
//  ExerciseAdvancedDetailsView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-19.
//

import SwiftUI

struct ExerciseAdvancedDetailsView: View {
    let trackingType: TrackingType
    let equipmentType: EquipmentType

    @Binding var category: ExerciseCategory
    @Binding var difficulty: Difficulty
    @Binding var resistanceType: ResistanceType?
    @Binding var movementPattern: MovementPattern?
    @Binding var mechanics: ExerciseMechanics?
    @Binding var forceType: ForceType?
    @Binding var gripStyle: GripStyle?
    @Binding var stance: ExerciseStance?
    @Binding var rangeOfMotion: RangeOfMotion?
    @Binding var setupAngleDegrees: Int?
    @Binding var variationFamilyID: String
    @Binding var laterality: Laterality
    @Binding var repCountingStyle: RepCountingStyle
    @Binding var weightEntryStyle: WeightEntryStyle
    @Binding var loadUnitCount: Int
    @Binding var isPlateLoaded: Bool
    @Binding var tagsText: String

    var body: some View {
        Form {
            Section("General") {
                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(LocalizedStringKey(category.rawValue)).tag(category)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(LocalizedStringKey(difficulty.rawValue)).tag(difficulty)
                    }
                }
            }

            Section("Classification") {
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

            Section("Logging") {
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

            Section("Tags") {
                TextField("Tags, separated by commas", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Advanced Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canConfigurePlateLoading: Bool {
        trackingType.usesWeight && (equipmentType == .machine || equipmentType == .other)
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
            Text("Variation")
        } footer: {
            Text("Use a shared family only to help people discover related variants. It does not make exercises interchangeable.")
        }
    }

    private static let setupAngles = Array(stride(from: 0, through: 90, by: 5))
}

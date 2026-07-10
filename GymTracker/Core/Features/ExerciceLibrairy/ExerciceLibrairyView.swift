//
//  ExerciceLibrairyView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI

struct ExerciceLibrairyView : View {
    @Environment(\.dismiss) private var dismiss
    
    @State var isSelectingExercise : Bool
    var selectedExercise: ExerciceTemplate?
    var availableExercises: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void

    @State private var searchText = ""
    @State private var selectedMuscle: Muscle?
    @State private var selectedEquipment: EquipmentType?
    @State private var selectedTracking: TrackingType?

    var body: some View {
        List {
            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredExercises, id: \.self) { exercise in
                    HStack(spacing: 8) {
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.body.weight(.medium))
                                Text(exerciseSubtitle(exercise))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExerciceView(exercice: exercise)
                        } label: {
                            Image(systemName: "info.circle")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Details for \(exercise.name)")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Muscle", selection: $selectedMuscle) {
                        Text("All muscles").tag(Muscle?.none)
                        ForEach(Muscle.allCases, id: \.self) { muscle in
                            Text(muscle.displayName).tag(Optional(muscle))
                        }
                    }
                    Picker("Equipment", selection: $selectedEquipment) {
                        Text("All equipment").tag(EquipmentType?.none)
                        ForEach(EquipmentType.allCases, id: \.self) { equipment in
                            Text(equipment.rawValue).tag(Optional(equipment))
                        }
                    }
                    Picker("Tracking", selection: $selectedTracking) {
                        Text("All tracking").tag(TrackingType?.none)
                        ForEach(TrackingType.allCases, id: \.self) { tracking in
                            Text(tracking.rawValue).tag(Optional(tracking))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var filteredExercises: [ExerciceTemplate] {
        availableExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesMuscle = selectedMuscle.map { exercise.PrimaryMuscle.contains($0) } ?? true
            let matchesEquipment = selectedEquipment == nil || exercise.equipmentType == selectedEquipment
            let matchesTracking = selectedTracking == nil || exercise.trackingType == selectedTracking
            return matchesSearch && matchesMuscle && matchesEquipment && matchesTracking
        }
    }

    private func exerciseSubtitle(_ exercise: ExerciceTemplate) -> String {
        let muscle = exercise.PrimaryMuscle.first?.displayName ?? "General"
        let equipment = exercise.equipmentType?.rawValue ?? "Other"
        return "\(muscle) · \(equipment) · \(exercise.trackingType.rawValue)"
    }
}

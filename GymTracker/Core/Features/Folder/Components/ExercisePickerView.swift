//
//  ExercisePickerView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void

    @State private var addedExerciseIDs: Set<ObjectIdentifier> = []

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("No exercises to add")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exercises, id: \.self) { exercise in
                    let isAdded = addedExerciseIDs.contains(ObjectIdentifier(exercise))

                    Button {
                        addedExerciseIDs.insert(ObjectIdentifier(exercise))
                        onSelect(exercise)
                    } label: {
                        HStack {
                            FolderRow(
                                title: exercise.name,
                                subtitle: exercise.trackingType.rawValue,
                                systemImage: "figure.strengthtraining.traditional"
                            )

                            Spacer()

                            if isAdded {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Text("Add")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded)
                }
            }
        }
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

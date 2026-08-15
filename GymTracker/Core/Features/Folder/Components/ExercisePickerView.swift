//
//  ExercisePickerView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var addedExerciseIDs: Set<ObjectIdentifier> = []

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("No exercises to add")
                    .foregroundStyle(Color.gymSubduedText)
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
                                subtitle: NSLocalizedString(exercise.trackingType.rawValue, comment: ""),
                                systemImage: "figure.strengthtraining.traditional"
                            )

                            Spacer()

                            if isAdded {
                                Image(systemName: AppIcon.checkmark)
                                    .foregroundStyle(Color.trameCompleted)
                            } else {
                                Text("Add")
                                    .font(AppFont.metadata)
                                    .foregroundStyle(Color.trameStrength)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded)
                    .listRowBackground(Color.trameCanvas)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .tint(Color.trameStrength)
    }
}

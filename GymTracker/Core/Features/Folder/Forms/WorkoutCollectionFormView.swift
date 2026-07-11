//
//  WorkoutCollectionFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct WorkoutCollectionFormView: View {
    @Environment(\.dismiss) private var dismiss

    let availableTemplates: [WorkoutTemplate]
    let onSave: (String, [WorkoutTemplate]) -> Void

    @State private var name = ""
    @State private var selectedTemplateNames: Set<String> = []

    var body: some View {
        Form {
            Section("Collection") {
                TextField("Name", text: $name)
            }

            Section("Templates") {
                if availableTemplates.isEmpty {
                    Text("Create a workout template first")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableTemplates, id: \.self) { template in
                        SelectionRow(
                            title: template.name,
                            isSelected: selectedTemplateNames.contains(template.name)
                        ) {
                            toggle(template.name, in: &selectedTemplateNames)
                        }
                    }
                }
            }
        }
        .navigationTitle("New Collection")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(trimmedName, selectedTemplates)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedTemplates: [WorkoutTemplate] {
        availableTemplates.filter { selectedTemplateNames.contains($0.name) }
    }
}

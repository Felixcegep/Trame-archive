//
//  TemplatePickerView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void

    @State private var addedTemplateIDs: Set<ObjectIdentifier> = []

    var body: some View {
        List {
            if templates.isEmpty {
                Text("No templates to add")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(templates, id: \.self) { template in
                    let isAdded = addedTemplateIDs.contains(ObjectIdentifier(template))

                    Button {
                        addedTemplateIDs.insert(ObjectIdentifier(template))
                        onSelect(template)
                    } label: {
                        HStack {
                            FolderRow(
                                title: template.name,
                                subtitle: String(localized: "\(template.exercises.count) exercises"),
                                systemImage: "list.bullet.rectangle"
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
        .navigationTitle("Add Template")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

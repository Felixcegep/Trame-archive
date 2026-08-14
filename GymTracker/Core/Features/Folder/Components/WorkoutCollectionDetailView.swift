//
//  WorkoutCollectionDetailView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct WorkoutCollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var availableTemplates: [WorkoutTemplate]

    let collection: WorkoutCollection
    let onStartWorkout: (WorkoutTemplate) -> Void

    @State private var isShowingTemplatePicker = false

    var body: some View {
        let templatesToAdd = makeTemplatesToAdd()

        List {
            Section("Workouts") {
                if collection.workoutTemplates.isEmpty {
                    Text("No workouts in this folder")
                        .foregroundStyle(Color.gymSubduedText)
                } else {
                    ForEach(collection.workoutTemplates, id: \.self) { template in
                        StartableWorkoutRow(
                            accessibilityName: template.name,
                            isStartDisabled: template.exercises.isEmpty,
                            onStart: { onStartWorkout(template) }
                        ) {
                            FolderRow(
                                title: template.name,
                                subtitle: String(localized: "\(template.exercises.count) exercises"),
                                systemImage: "list.bullet.rectangle"
                            )
                        } editor: {
                            WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                        }
                    }
                    .onDelete(perform: removeTemplates)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(collection.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingTemplatePicker = true
                } label: {
                    Image(systemName: AppIcon.plus)
                }
                .disabled(templatesToAdd.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingTemplatePicker) {
            NavigationStack {
                TemplatePickerView(templates: templatesToAdd) { template in
                    addTemplate(template)
                }
            }
        }
    }

    private func makeTemplatesToAdd() -> [WorkoutTemplate] {
        let existingTemplateIDs = Set(
            collection.workoutTemplates.map(\.persistentModelID)
        )
        return availableTemplates.filter { template in
            existingTemplateIDs.contains(template.persistentModelID) == false
        }
    }

    private func addTemplate(_ template: WorkoutTemplate) {
        guard !collection.workoutTemplates.contains(where: {
            $0.persistentModelID == template.persistentModelID
        }) else {
            return
        }

        collection.workoutTemplates.append(template)
        saveModelContext(modelContext)
    }

    private func removeTemplates(at offsets: IndexSet) {
        collection.workoutTemplates.remove(atOffsets: offsets)
        saveModelContext(modelContext)
    }
}

//
//  WorkoutPlanDetailView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct WorkoutPlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var availableTemplates: [WorkoutTemplate]

    let plan: WorkoutPlan

    @State private var isShowingTemplatePicker = false

    var body: some View {
        List {
            Section("Templates") {
                if plan.workoutTemplates.isEmpty {
                    Text("No templates in this plan")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plan.workoutTemplates, id: \.self) { template in
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template)
                        } label: {
                            FolderRow(
                                title: template.name,
                                subtitle: "\(template.exercises.count) exercises",
                                systemImage: "list.bullet.rectangle"
                            )
                        }
                    }
                    .onDelete(perform: removeTemplates)
                }
            }
        }
        .navigationTitle(plan.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingTemplatePicker = true
                } label: {
                    Image(systemName: "plus")
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

    private var templatesToAdd: [WorkoutTemplate] {
        availableTemplates.filter { template in
            !plan.workoutTemplates.contains {
                $0.persistentModelID == template.persistentModelID
            }
        }
    }

    private func addTemplate(_ template: WorkoutTemplate) {
        guard !plan.workoutTemplates.contains(where: {
            $0.persistentModelID == template.persistentModelID
        }) else {
            return
        }

        plan.workoutTemplates.append(template)
        saveModelContext(modelContext)
    }

    private func removeTemplates(at offsets: IndexSet) {
        plan.workoutTemplates.remove(atOffsets: offsets)
        saveModelContext(modelContext)
    }
}

//
//  FolderView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query private var exerciceTemplates: [ExerciceTemplate]

    @State private var activeSheet: FolderSheet?

    var body: some View {
        List {
            Section("Workout Plans") {
                if workoutPlans.isEmpty {
                    Text("No workout plans")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workoutPlans) { plan in
                        NavigationLink {
                            WorkoutPlanDetailView(plan: plan)
                        } label: {
                            FolderRow(
                                title: plan.name,
                                subtitle: "\(plan.workoutTemplates.count) templates",
                                systemImage: "calendar"
                            )
                        }
                    }
                }
            }

            Section("Workout Templates") {
                if workoutTemplates.isEmpty {
                    Text("No workout templates")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workoutTemplates, id: \.self) { template in
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
                }
            }

            Section("Exercises") {
                if exerciceTemplates.isEmpty {
                    Text("No exercises")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(exerciceTemplates, id: \.self) { exercice in
                        NavigationLink {
                            ExerciceView(exercice: exercice)
                        } label: {
                            FolderRow(
                                title: exercice.name,
                                subtitle: exercice.trackingType.rawValue,
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Folders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Workout Plan", systemImage: "calendar.badge.plus") {
                        activeSheet = .workoutPlan
                    }

                    Button("Workout Template", systemImage: "list.bullet.rectangle.portrait") {
                        activeSheet = .workoutTemplate
                    }

                    Button("Exercise", systemImage: "figure.strengthtraining.traditional") {
                        activeSheet = .exercise
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .workoutPlan:
                    WorkoutPlanFormView(availableTemplates: workoutTemplates) { name, templates in
                        modelContext.insert(WorkoutPlan(name: name, workoutTemplates: templates))
                        saveModelContext(modelContext)
                    }
                case .workoutTemplate:
                    WorkoutTemplateFormView(availableExercises: exerciceTemplates) { name, exercises in
                        modelContext.insert(WorkoutTemplate(name: name, exercises: exercises))
                        saveModelContext(modelContext)
                    }
                case .exercise:
                    ExerciseFormView { exercise in
                        modelContext.insert(exercise)
                        saveModelContext(modelContext)
                    }
                }
            }
        }
    }
}

private enum FolderSheet: String, Identifiable {
    case workoutPlan
    case workoutTemplate
    case exercise

    var id: String { rawValue }
}

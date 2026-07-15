//
//  WorkoutTemplateDetailView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct WorkoutTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ExerciceTemplate> { !$0.isArchived }) private var availableExercises: [ExerciceTemplate]

    let template: WorkoutTemplate
    let onStartWorkout: (WorkoutTemplate) -> Void

    @State private var isShowingExercisePicker = false

    var body: some View {
        List {
            Section("Exercises") {
                if orderedTemplateExercises.isEmpty {
                    Text("No exercises in this template")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orderedTemplateExercises, id: \.persistentModelID) { templateExercise in
                        NavigationLink {
                            TemplateExerciseEditorView(templateExercise: templateExercise)
                        } label: {
                            FolderRow(
                                title: templateExercise.exercise.name,
                                subtitle: prescriptionSummary(templateExercise),
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        }
                        .accessibilityIdentifier("template-exercise-editor-\(templateExercise.exercise.name)")
                    }
                    .onDelete(perform: removeExercises)
                }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Start", systemImage: "play.fill") {
                    onStartWorkout(template)
                }
                .disabled(orderedTemplateExercises.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(exercisesToAdd.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                ExercisePickerView(exercises: exercisesToAdd) { exercise in
                    addExercise(exercise)
                }
            }
        }
    }

    private var exercisesToAdd: [ExerciceTemplate] {
        availableExercises.filter { exercise in
            !template.exercises.contains {
                $0.persistentModelID == exercise.persistentModelID
            }
        }
    }

    private func addExercise(_ exercise: ExerciceTemplate) {
        guard !template.exercises.contains(where: {
            $0.persistentModelID == exercise.persistentModelID
        }) else {
            return
        }

        template.templateExercises.append(
            TemplateExercise(exercise: exercise, order: template.templateExercises.count)
        )
        template.normalizeTemplateExerciseOrder()
        saveModelContext(modelContext)
    }

    private func removeExercises(at offsets: IndexSet) {
        let prescriptionsToRemove = offsets.map { orderedTemplateExercises[$0] }
        template.templateExercises.removeAll { prescription in
            prescriptionsToRemove.contains { $0.persistentModelID == prescription.persistentModelID }
        }

        for prescription in prescriptionsToRemove {
            modelContext.delete(prescription)
        }
        template.normalizeTemplateExerciseOrder()
        saveModelContext(modelContext)
    }

    private var orderedTemplateExercises: [TemplateExercise] {
        template.orderedTemplateExercises
    }

    private func prescriptionSummary(_ templateExercise: TemplateExercise) -> String {
        var components = [
            "\(templateExercise.targetSets) sets",
            "\(templateExercise.repRangeMinimum)-\(templateExercise.repRangeMaximum) reps",
            "\(templateExercise.restSeconds) sec rest"
        ]

        if let rpe = templateExercise.targetRPE {
            components.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        }
        if let rir = templateExercise.targetRIR {
            components.append("RIR \(rir)")
        }
        return components.joined(separator: " · ")
    }
}

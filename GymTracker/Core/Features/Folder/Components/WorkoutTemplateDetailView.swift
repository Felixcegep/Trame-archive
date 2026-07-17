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
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var availableExercises: [Exercise]

    let template: WorkoutTemplate
    let onStartWorkout: (WorkoutTemplate) -> Void

    @State private var isShowingExercisePicker = false
    @State private var groupingExercise: TemplateExercise?

    var body: some View {
        List {
            Section("Exercises") {
                if orderedTemplateExercises.isEmpty {
                    Text("No exercises in this workout")
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
                        .contextMenu {
                            if templateExercise.supersetGroupID == nil {
                                Button("Superset with…") {
                                    groupingExercise = templateExercise
                                }
                            } else {
                                Button("Remove from superset") {
                                    templateExercise.supersetGroupID = nil
                                    template.normalizeTemplateExerciseOrder()
                                    saveModelContext(modelContext)
                                }
                            }
                        }
                    }
                    .onDelete(perform: removeExercises)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
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
        .confirmationDialog(
            "Superset with…",
            isPresented: Binding(
                get: { groupingExercise != nil },
                set: { if !$0 { groupingExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let source = groupingExercise {
                ForEach(orderedTemplateExercises.filter {
                    $0.persistentModelID != source.persistentModelID && $0.supersetGroupID == nil
                }, id: \.persistentModelID) { candidate in
                    Button(candidate.exercise.name) {
                        createSuperset(source, with: candidate)
                    }
                }
            }
        }
    }

    private var exercisesToAdd: [Exercise] {
        availableExercises.filter { exercise in
            !template.exercises.contains {
                $0.persistentModelID == exercise.persistentModelID
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
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

    private func createSuperset(_ first: TemplateExercise, with second: TemplateExercise) {
        let groupID = UUID()
        first.supersetGroupID = groupID
        second.supersetGroupID = groupID
        var ordered = orderedTemplateExercises
        ordered.removeAll { $0.persistentModelID == second.persistentModelID }
        guard let firstIndex = ordered.firstIndex(where: { $0.persistentModelID == first.persistentModelID }) else {
            return
        }
        ordered.insert(second, at: firstIndex + 1)
        for (index, exercise) in ordered.enumerated() {
            exercise.orderIndex = index
        }
        template.normalizeTemplateExerciseOrder()
        saveModelContext(modelContext)
        groupingExercise = nil
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

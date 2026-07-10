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
    @Query private var availableExercises: [ExerciceTemplate]

    let template: WorkoutTemplate
    let onStartWorkout: (WorkoutTemplate) -> Void

    @State private var isShowingExercisePicker = false

    var body: some View {
        List {
            Section("Exercises") {
                if template.exercises.isEmpty {
                    Text("No exercises in this template")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(template.exercises, id: \.self) { exercice in
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
                .disabled(template.exercises.isEmpty)
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

        template.exercises.append(exercise)
        saveModelContext(modelContext)
    }

    private func removeExercises(at offsets: IndexSet) {
        template.exercises.remove(atOffsets: offsets)
        saveModelContext(modelContext)
    }
}

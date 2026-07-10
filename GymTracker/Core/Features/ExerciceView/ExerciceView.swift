//
//  ExerciceView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-03.
//

import Foundation
import SwiftUI
import SwiftData

struct ExerciceDetailSnapshot {
    let name: String
    let primaryMuscles: [Muscle]
    let secondaryMuscles: [Muscle]
    let category: ExerciseCategory
    let trackingType: TrackingType
    let equipmentType: EquipmentType
    let resistanceType: ResistanceType?
    let movementPattern: MovementPattern?
    let difficulty: Difficulty

    init(exercice: ExerciceTemplate) {
        name = exercice.name
        primaryMuscles = exercice.PrimaryMuscle
        secondaryMuscles = exercice.SecondaryMuscle ?? []
        category = exercice.displayCategory
        trackingType = exercice.trackingType
        equipmentType = exercice.equipmentType ?? .other
        resistanceType = exercice.resistanceType
        movementPattern = exercice.movementPattern
        difficulty = exercice.displayDifficulty
    }
}

struct ExerciceView : View {
    @Environment(\.modelContext) private var modelContext

    private let editableExercise: ExerciceTemplate?
    private let snapshot: ExerciceDetailSnapshot?
    @State private var isShowingEditor = false

    init(exercice: ExerciceTemplate) {
        editableExercise = exercice
        snapshot = nil
    }

    init(exercice: ExerciceDetailSnapshot) {
        editableExercise = nil
        snapshot = exercice
    }

    private var exercice: ExerciceDetailSnapshot {
        if let editableExercise {
            return ExerciceDetailSnapshot(exercice: editableExercise)
        }
        return snapshot!
    }

    var body: some View {
        List {
            Section("Exercise") {
                LabeledContent("Name", value: exercice.name)
                LabeledContent("Category", value: exercice.category.rawValue)
                LabeledContent("Tracking", value: exercice.trackingType.rawValue)
                LabeledContent("Equipment", value: exercice.equipmentType.rawValue)
                LabeledContent("Resistance", value: exercice.resistanceType?.rawValue ?? "None")
                LabeledContent("Movement", value: exercice.movementPattern?.rawValue ?? "None")
                LabeledContent("Difficulty", value: exercice.difficulty.rawValue)
            }

            Section("Actions") {
                Button {
                    showExerciseHistory()
                } label: {
                    Label("Exercise History", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    showOneRepMax()
                } label: {
                    Label("1RM", systemImage: "chart.line.uptrend.xyaxis")
                }

                Button {
                    showExerciseStats()
                } label: {
                    Label("Exercise Stats", systemImage: "chart.bar")
                }
            }

            Section("Primary Muscles") {
                ForEach(exercice.primaryMuscles, id: \.self) { muscle in
                    Text(muscle.displayName)
                }
            }

            if !exercice.secondaryMuscles.isEmpty {
                Section("Secondary Muscles") {
                    ForEach(exercice.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                    }
                }
            }
        }
        .navigationTitle(exercice.name)
        .toolbar {
            if editableExercise != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        isShowingEditor = true
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            if let editableExercise {
                NavigationStack {
                    ExerciseFormView(exercise: editableExercise) { _ in
                        saveModelContext(modelContext)
                    }
                }
            }
        }
    }

    private func showExerciseHistory() {
        // Placeholder for the future exercise-specific history screen.
    }

    private func showOneRepMax() {
        // Placeholder for the future 1RM screen.
    }

    private func showExerciseStats() {
        // Placeholder for future exercise stats.
    }
}

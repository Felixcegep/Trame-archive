//
//  ExerciceView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-03.
//

import Foundation
import SwiftUI

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
    private let exercice: ExerciceDetailSnapshot

    init(exercice: ExerciceTemplate) {
        self.exercice = ExerciceDetailSnapshot(exercice: exercice)
    }

    init(exercice: ExerciceDetailSnapshot) {
        self.exercice = exercice
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

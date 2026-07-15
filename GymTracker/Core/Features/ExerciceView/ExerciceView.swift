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
    let usesWeightPlates: Bool

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
        usesWeightPlates = exercice.supportsPlateCalculator
    }
}

struct ExerciceView : View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editableExercise: ExerciceTemplate?
    private let snapshot: ExerciceDetailSnapshot?
    @State private var isShowingEditor = false
    @State private var isShowingInsights = false

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
                LabeledContent("Category") { Text(LocalizedStringKey(exercice.category.rawValue)) }
                LabeledContent("Tracking") { Text(LocalizedStringKey(exercice.trackingType.rawValue)) }
                LabeledContent("Equipment") { Text(LocalizedStringKey(exercice.equipmentType.rawValue)) }
                LabeledContent("Resistance") { Text(LocalizedStringKey(exercice.resistanceType?.rawValue ?? "None")) }
                LabeledContent("Movement") { Text(LocalizedStringKey(exercice.movementPattern?.rawValue ?? "None")) }
                LabeledContent("Difficulty") { Text(LocalizedStringKey(exercice.difficulty.rawValue)) }
                if exercice.trackingType.usesWeight {
                    LabeledContent("Weight entry") {
                        Text(LocalizedStringKey(exercice.usesWeightPlates ? "Plate calculator" : "Direct weight entry"))
                    }
                }
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
                .accessibilityIdentifier("exercise-stats")
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
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: editableExercise?.isFavorite == true ? AppIcon.favoriteFilled : AppIcon.favorite)
                    }
                    .accessibilityLabel(editableExercise?.isFavorite == true ? "Remove from favorites" : "Add to favorites")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        isShowingEditor = true
                    }
                }

                if editableExercise?.isCustom == true {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            deleteExercise()
                        } label: {
                            Image(systemName: AppIcon.trash)
                                .foregroundStyle(Color.gymDestructive)
                        }
                        .accessibilityLabel("Delete exercise")
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
        .navigationDestination(isPresented: $isShowingInsights) {
            if let editableExercise {
                ExerciseDetailInsightsDestination(exercise: editableExercise)
            }
        }
    }

    private func showExerciseHistory() {
        // Placeholder for the future exercise-specific history screen.
    }

    private func toggleFavorite() {
        guard let editableExercise else { return }
        editableExercise.isFavorite.toggle()
        saveModelContext(modelContext)
    }

    private func showOneRepMax() {
        // Placeholder for the future 1RM screen.
    }

    private func showExerciseStats() {
        guard editableExercise != nil else { return }
        isShowingInsights = true
    }

    private func deleteExercise() {
        guard let editableExercise else { return }
        do {
            try ExerciseArchiveService.hideOrDelete(editableExercise, using: modelContext)
            dismiss()
        } catch {
            print("Failed to delete exercise: \(error)")
        }
    }
}

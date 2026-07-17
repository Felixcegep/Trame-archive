//
//  ExerciseView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-03.
//

import Foundation
import SwiftUI
import SwiftData

struct ExerciseDetailSnapshot {
    let name: String
    let primaryMuscles: [Muscle]
    let secondaryMuscles: [Muscle]
    let category: ExerciseCategory
    let trackingType: TrackingType
    let equipmentType: EquipmentType
    let resistanceType: ResistanceType?
    let movementPattern: MovementPattern?
    let forceType: ForceType?
    let mechanics: ExerciseMechanics?
    let gripStyle: GripStyle?
    let stance: ExerciseStance?
    let rangeOfMotion: RangeOfMotion?
    let setupAngleDegrees: Int?
    let laterality: Laterality
    let difficulty: Difficulty
    let usesWeightPlates: Bool

    init(exercise: Exercise) {
        name = exercise.name
        primaryMuscles = exercise.primaryMuscles
        secondaryMuscles = exercise.secondaryMuscles ?? []
        category = exercise.displayCategory
        trackingType = exercise.trackingType
        equipmentType = exercise.equipmentType ?? .other
        resistanceType = exercise.resistanceType
        movementPattern = exercise.movementPattern
        forceType = exercise.forceType
        mechanics = exercise.mechanics
        gripStyle = exercise.gripStyle
        stance = exercise.stance
        rangeOfMotion = exercise.rangeOfMotion
        setupAngleDegrees = exercise.setupAngleDegrees
        laterality = exercise.laterality
        difficulty = exercise.displayDifficulty
        usesWeightPlates = exercise.supportsPlateCalculator
    }
}

struct ExerciseView : View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var availableExercises: [Exercise]

    private let editableExercise: Exercise?
    private let snapshot: ExerciseDetailSnapshot?
    @State private var isShowingEditor = false
    @State private var isShowingInsights = false
    @State private var isShowingRelationshipEditor = false

    init(exercise: Exercise) {
        editableExercise = exercise
        snapshot = nil
    }

    init(exercise: ExerciseDetailSnapshot) {
        editableExercise = nil
        snapshot = exercise
    }

    private var exercise: ExerciseDetailSnapshot {
        if let editableExercise {
            return ExerciseDetailSnapshot(exercise: editableExercise)
        }
        return snapshot!
    }

    var body: some View {
        List {
            Section("Exercise") {
                LabeledContent("Name", value: exercise.name)
                LabeledContent("Category") { Text(LocalizedStringKey(exercise.category.rawValue)) }
                LabeledContent("Tracking") { Text(LocalizedStringKey(exercise.trackingType.rawValue)) }
                LabeledContent("Equipment") { Text(LocalizedStringKey(exercise.equipmentType.rawValue)) }
                LabeledContent("Resistance") { Text(LocalizedStringKey(exercise.resistanceType?.rawValue ?? "None")) }
                LabeledContent("Movement") { Text(LocalizedStringKey(exercise.movementPattern?.rawValue ?? "None")) }
                LabeledContent("Mechanics") { Text(LocalizedStringKey(exercise.mechanics?.rawValue ?? "None")) }
                LabeledContent("Force") { Text(LocalizedStringKey(exercise.forceType?.rawValue ?? "None")) }
                LabeledContent("Laterality") { Text(LocalizedStringKey(exercise.laterality.rawValue)) }
                LabeledContent("Grip") { Text(LocalizedStringKey(exercise.gripStyle?.rawValue ?? "None")) }
                LabeledContent("Stance") { Text(LocalizedStringKey(exercise.stance?.rawValue ?? "None")) }
                LabeledContent("Range of Motion") { Text(LocalizedStringKey(exercise.rangeOfMotion?.rawValue ?? "None")) }
                if let setupAngleDegrees = exercise.setupAngleDegrees {
                    LabeledContent("Setup Angle", value: "\(setupAngleDegrees)°")
                }
                LabeledContent("Difficulty") { Text(LocalizedStringKey(exercise.difficulty.rawValue)) }
                if exercise.trackingType.usesWeight {
                    LabeledContent("Weight entry") {
                        Text(LocalizedStringKey(exercise.usesWeightPlates ? "Plate calculator" : "Direct weight entry"))
                    }
                }
            }

            if !variations.isEmpty {
                Section {
                    ForEach(variations, id: \.persistentModelID) { variation in
                        NavigationLink {
                            ExerciseView(exercise: variation)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(variation.name)
                                    .font(AppFont.bodyMedium)
                                    .foregroundStyle(Color.gymText)
                                Text(variationSubtitle(for: variation))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityIdentifier("exercise-variation-\(variation.name)")
                    }
                } header: {
                    Text("Variations")
                } footer: {
                    Text("Related variants share a movement family. They are not automatic substitutions.")
                }
            }

            if editableExercise != nil {
                Section("Performance") {
                    Button {
                        showExerciseStats()
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Label("View Performance", systemImage: AppIcon.chart)
                                .font(AppFont.subheadlineSemibold)
                            Text("History, estimated 1RM, volume, records, notes, and progression")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("exercise-stats")
                }
            }

            Section("Primary Muscles") {
                ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                    Text(muscle.displayName)
                }
            }

            if !exercise.secondaryMuscles.isEmpty {
                Section("Secondary Muscles") {
                    ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingRelationshipEditor = true
                    } label: {
                        Image(systemName: AppIcon.relationship)
                    }
                    .accessibilityLabel("Manage exercise relationships")
                    .accessibilityIdentifier("exercise-relationships")
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
        .sheet(isPresented: $isShowingRelationshipEditor) {
            if let editableExercise {
                NavigationStack {
                    ExerciseRelationshipEditorView(exercise: editableExercise)
                }
            }
        }
        .navigationDestination(isPresented: $isShowingInsights) {
            if let editableExercise {
                ExerciseDetailInsightsDestination(exercise: editableExercise)
            }
        }
    }

    private func toggleFavorite() {
        guard let editableExercise else { return }
        editableExercise.isFavorite.toggle()
        saveModelContext(modelContext)
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

    private var variations: [Exercise] {
        guard let editableExercise,
              let familyID = editableExercise.variationFamilyID,
              !familyID.isEmpty else {
            return []
        }

        return availableExercises
            .filter { $0.persistentModelID != editableExercise.persistentModelID && $0.variationFamilyID == familyID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func variationSubtitle(for exercise: Exercise) -> String {
        [
            exercise.equipmentType?.rawValue,
            exercise.gripStyle?.rawValue,
            exercise.stance?.rawValue,
            exercise.setupAngleDegrees.map { "\($0)°" }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

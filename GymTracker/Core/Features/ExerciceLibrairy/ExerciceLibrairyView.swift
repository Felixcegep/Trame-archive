//
//  ExerciceLibrairyView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI
import SwiftData

struct ExerciceLibrairyView : View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    
    let isSelectingExercise: Bool
    var selectedExercise: ExerciceTemplate?
    var availableExercises: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void

    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var selectedExerciseNames: Set<String>

    init(
        isSelectingExercise: Bool,
        selectedExercise: ExerciceTemplate? = nil,
        availableExercises: [ExerciceTemplate],
        selectedExerciseNames: Set<String> = [],
        onSelect: @escaping (ExerciceTemplate) -> Void
    ) {
        self.isSelectingExercise = isSelectingExercise
        self.selectedExercise = selectedExercise
        self.availableExercises = availableExercises
        self.onSelect = onSelect
        _selectedExerciseNames = State(initialValue: selectedExerciseNames)
    }

    var body: some View {
        List {
            Section {
                ExerciseFilterControls(filter: $filter, resultCount: filteredExercises.count)
            }

            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredExercises, id: \.self) { exercise in
                    exerciseRow(for: exercise)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var filteredExercises: [ExerciceTemplate] {
        let filtered = availableExercises.filter { exercise in
            filter.matches(exercise, searchText: searchText)
        }
        let recentRanks = recentExerciseRanks
        return filtered.sorted { first, second in
            if isSelectingExercise {
                let firstRank = recentRanks[first.name] ?? Int.max
                let secondRank = recentRanks[second.name] ?? Int.max
                if firstRank != secondRank { return firstRank < secondRank }
            }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    private func exerciseRow(for exercise: ExerciceTemplate) -> some View {
        let isSelected = selectedExerciseNames.contains(exercise.name)

        return HStack(spacing: Spacing.s) {
            Button {
                if isSelected {
                    selectedExerciseNames.remove(exercise.name)
                } else {
                    selectedExerciseNames.insert(exercise.name)
                }
                onSelect(exercise)
            } label: {
                HStack(spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.gymText)
                        Text(exercise.subtitle)
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }

                    Spacer(minLength: Spacing.s)

                    Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.plus)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(isSelected ? Color.gymSecondary : Color.gymPrimary)
                        .frame(width: 44, height: 44)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-exercise-\(exercise.name)")
            .accessibilityLabel("\(isSelected ? "Remove" : "Add") \(exercise.name)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")

            NavigationLink {
                ExerciceView(exercice: exercise)
            } label: {
                Image(systemName: AppIcon.info)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(exercise.name)")
        }
    }

    private var recentExerciseRanks: [String: Int] {
        guard isSelectingExercise else { return [:] }
        var ranks: [String: Int] = [:]
        var nextRank = 0
        for workout in workouts where workout.status == .completed {
            for exercise in workout.orderedExercises where ranks[exercise.exercice.name] == nil {
                ranks[exercise.exercice.name] = nextRank
                nextRank += 1
            }
        }
        return ranks
    }

}

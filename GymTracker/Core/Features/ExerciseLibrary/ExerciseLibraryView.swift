//
//  ExerciseLibraryView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView : View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    
    let isSelectingExercise: Bool
    var selectedExercise: Exercise?
    var availableExercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    /// Exercises already in the destination. This picker only ever adds to it:
    /// an entry here can never be tapped back out. Removal belongs to the
    /// exercise's own card, which is the only place the sets that would be
    /// destroyed are visible.
    @State private var addedExerciseIDs: Set<UUID>

    init(
        isSelectingExercise: Bool,
        selectedExercise: Exercise? = nil,
        availableExercises: [Exercise],
        addedExerciseIDs: Set<UUID> = [],
        onSelect: @escaping (Exercise) -> Void
    ) {
        self.isSelectingExercise = isSelectingExercise
        self.selectedExercise = selectedExercise
        self.availableExercises = availableExercises
        self.onSelect = onSelect
        _addedExerciseIDs = State(initialValue: addedExerciseIDs)
    }

    var body: some View {
        let results = filteredExercises

        List {
            Section {
                ExerciseFilterControls(filter: $filter, resultCount: results.count)
            }

            if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(results, id: \.id) { exercise in
                    exerciseRow(for: exercise)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Add Exercise")
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("exercise-picker-screen", label: "Exercise picker")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("close-exercise-picker")
            }
        }
    }

    private var filteredExercises: [Exercise] {
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

    private func exerciseRow(for exercise: Exercise) -> some View {
        // Identity is the catalog id, not the name: two exercises can share a
        // name, and a name match would let one stand in for the other.
        let isAdded = addedExerciseIDs.contains(exercise.id)

        return ExerciseLibrarySelectionRow(exercise: exercise, isAdded: isAdded) {
            guard !isAdded else { return }
            addedExerciseIDs.insert(exercise.id)
            onSelect(exercise)
        }
    }

    private var recentExerciseRanks: [String: Int] {
        guard isSelectingExercise else { return [:] }
        var ranks: [String: Int] = [:]
        var nextRank = 0
        for workout in workouts where workout.status == .completed {
            for exercise in workout.orderedExercises where ranks[exercise.exercise.name] == nil {
                ranks[exercise.exercise.name] = nextRank
                nextRank += 1
            }
        }
        return ranks
    }

}

private struct ExerciseLibrarySelectionRow: View {
    let exercise: Exercise
    let isAdded: Bool
    let onAdd: () -> Void
    @State private var isShowingDetails = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Button {
                isShowingDetails = true
            } label: {
                HStack(alignment: .top, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.gymText)
                            .multilineTextAlignment(.leading)
                        Text(exercise.subtitle)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .multilineTextAlignment(.leading)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: Spacing.s)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-link-\(exercise.name)")

            // An already-added exercise renders as a status, not a control.
            // As a button it read as a toggle, and tapping it deleted the
            // exercise and every set logged against it from a screen where
            // none of that work was visible.
            if isAdded {
                Image(systemName: AppIcon.checkmarkCircle)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymSecondary)
                    .frame(width: 44, height: 44)
                    .accessibilityIdentifier("added-exercise-\(exercise.name)")
                    .accessibilityLabel("\(exercise.name), already added")
            } else {
                Button(action: onAdd) {
                    Image(systemName: AppIcon.plus)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("add-exercise-\(exercise.name)")
                .accessibilityLabel("Add \(exercise.name)")
            }
        }
        .navigationDestination(isPresented: $isShowingDetails) {
            ExerciseView(exercise: exercise)
        }
    }
}

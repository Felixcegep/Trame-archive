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
    @Query private var workouts: [Workout]
    
    let isSelectingExercise: Bool
    var selectedExercise: Exercise?
    var availableExercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var recentExerciseRanks: [UUID: Int] = [:]
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
        _workouts = Query(
            filter: #Predicate<Workout> {
                $0.endTime != nil && isSelectingExercise
            },
            sort: [SortDescriptor(\Workout.startTime, order: .reverse)]
        )
    }

    var body: some View {
        let results = filteredExercises

        List {
            Section {
                ExerciseFilterControls(filter: $filter, resultCount: results.count)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(results, id: \.id) { exercise in
                    exerciseRow(for: exercise)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(Color.trameSeparator)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search exercises")
        // Recent ranking depends on workout history, not on the search query.
        // Project it once per history change so typing does not rescan every
        // completed workout and relationship for each character.
        .task(id: recentRankInputID) {
            recentExerciseRanks = buildRecentExerciseRanks()
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Add Exercise")
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("exercise-picker-screen", label: "Exercise picker")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .font(AppFont.body.weight(.semibold))
                .foregroundStyle(Color.trameText)
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
                let firstRank = recentRanks[first.id] ?? Int.max
                let secondRank = recentRanks[second.id] ?? Int.max
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

    private func buildRecentExerciseRanks() -> [UUID: Int] {
        guard isSelectingExercise else { return [:] }
        var ranks: [UUID: Int] = [:]
        var nextRank = 0
        for workout in workouts where workout.status == .completed {
            for exercise in workout.orderedExercises where ranks[exercise.historicalExerciseID] == nil {
                ranks[exercise.historicalExerciseID] = nextRank
                nextRank += 1
            }
        }
        return ranks
    }

    private var recentRankInputID: Int {
        guard isSelectingExercise else { return 0 }
        var revision = Hasher()
        // Completed workout graphs are immutable. Hashing every root catches
        // a delete/restore that keeps the same count and newest workout, while
        // still avoiding a second traversal of every exercise during body.
        for workout in workouts {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
        }
        return revision.finalize()
    }

}

private struct ExerciseLibrarySelectionRow: View {
    let exercise: Exercise
    let isAdded: Bool
    let onAdd: () -> Void
    @State private var isShowingDetails = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Button {
                isShowingDetails = true
            } label: {
                HStack(alignment: .top, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(exercise.name)
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(Color.trameText)
                            .multilineTextAlignment(.leading)
                        Text(exercise.subtitle)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .multilineTextAlignment(.leading)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: Spacing.s)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-link-\(exercise.name)")

            if isAdded {
                Image(systemName: AppIcon.checkmarkCircle)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.trameCompleted)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("added-exercise-\(exercise.name)")
                    .accessibilityLabel("\(exercise.name), already added")
            } else {
                Button(action: onAdd) {
                    Image(systemName: AppIcon.plus)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.trameStrength)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add-exercise-\(exercise.name)")
                .accessibilityLabel("Add \(exercise.name)")
            }
        }
        .padding(.vertical, Spacing.xs)
        .navigationDestination(isPresented: $isShowingDetails) {
            ExerciseView(exercise: exercise)
        }
    }
}

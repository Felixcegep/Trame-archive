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
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    
    let isSelectingExercise: Bool
    var selectedExercise: Exercise?
    @State private var availableExercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var recentExerciseRanks: [UUID: Int] = [:]
    /// Exercises already in the destination. This picker only ever adds to it:
    /// an entry here can never be tapped back out. Removal belongs to the
    /// exercise's own card, which is the only place the sets that would be
    /// destroyed are visible.
    @State private var addedExerciseIDs: Set<UUID>
    @FocusState private var isSearchFocused: Bool
    @State private var isCreatingExercise = false

    init(
        isSelectingExercise: Bool,
        selectedExercise: Exercise? = nil,
        availableExercises: [Exercise],
        addedExerciseIDs: Set<UUID> = [],
        onSelect: @escaping (Exercise) -> Void
    ) {
        self.isSelectingExercise = isSelectingExercise
        self.selectedExercise = selectedExercise
        _availableExercises = State(initialValue: availableExercises)
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
                pickerEmptyState
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("exercise-picker-no-results")
            } else {
                if showsBrowseSections {
                    exerciseSections(results)
                } else {
                    Section("Results") {
                        exerciseRows(results)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $searchText,
            placement: isSelectingExercise ? .navigationBarDrawer(displayMode: .always) : .automatic,
            prompt: "Search by exercise, muscle, or equipment"
        )
        .searchFocused($isSearchFocused)
        .scrollDismissesKeyboard(.interactively)
        // Recent ranking depends on workout history, not on the search query.
        // Project it once per history change so typing does not rescan every
        // completed workout and relationship for each character.
        .task(id: recentRankInputID) {
            recentExerciseRanks = buildRecentExerciseRanks()
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("exercise-picker-screen", label: "Exercise picker")
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectingExercise {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: Spacing.m) {
                        Text("Done")
                            .accessibilityIdentifier("close-exercise-picker")
                        Spacer(minLength: Spacing.s)
                        Image(systemName: AppIcon.checkmark)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.tramePrimaryAction)
                .accessibilityLabel("Done")
                .padding(.horizontal, Spacing.screenInset)
                .padding(.vertical, Spacing.s)
                .background(Color.trameSurface)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
            }
        }
        .toolbar {
            if !isSelectingExercise {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .accessibilityIdentifier("close-exercise-picker")
                    }
                    .font(AppFont.body.weight(.semibold))
                    .foregroundStyle(Color.trameText)
                    .accessibilityLabel("Done")
                }
            }
        }
        .sheet(isPresented: $isCreatingExercise) {
            NavigationStack {
                ExerciseFormView(initialName: searchText) { exercise in
                    modelContext.insert(exercise)
                    do {
                        try modelContext.save()
                    } catch {
                        modelContext.delete(exercise)
                        return
                    }
                    availableExercises.append(exercise)
                    addedExerciseIDs.insert(exercise.id)
                    onSelect(exercise)
                }
            }
        }
    }

    private var showsBrowseSections: Bool {
        isSelectingExercise && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filter.activeFilterCount == 0
    }

    @ViewBuilder
    private func exerciseSections(_ results: [Exercise]) -> some View {
        let recent = Array(results.filter { recentExerciseRanks[$0.id] != nil }.prefix(6))
        let recentIDs = Set(recent.map(\.id))
        let favorites = results.filter { $0.isFavorite && !recentIDs.contains($0.id) }
        let featuredIDs = recentIDs.union(favorites.map(\.id))
        let all = results.filter { !featuredIDs.contains($0.id) }

        if !recent.isEmpty { Section("Recent") { exerciseRows(recent) } }
        if !favorites.isEmpty { Section("Favorites") { exerciseRows(favorites) } }
        Section("All Exercises") { exerciseRows(all) }
    }

    @ViewBuilder
    private func exerciseRows(_ exercises: [Exercise]) -> some View {
        ForEach(exercises, id: \.id) { exercise in
            exerciseRow(for: exercise)
                .listRowBackground(Color.clear)
                .listRowSeparator(.visible)
                .listRowSeparatorTint(Color.trameSeparator)
        }
    }

    @ViewBuilder
    private var pickerEmptyState: some View {
        if !searchText.isEmpty {
            VStack(spacing: Spacing.m) {
                ContentUnavailableView(
                    "No matching exercises",
                    systemImage: AppIcon.search,
                    description: Text("Try another name, muscle, or equipment type.")
                )
                Button("Create “\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))”") {
                    isCreatingExercise = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("create-exercise-from-search")
                if filter.activeFilterCount > 0 { clearFiltersButton }
            }
        } else if filter != ExerciseFilterState() {
            VStack(spacing: Spacing.m) {
                ContentUnavailableView(
                    "No exercises in these filters",
                    systemImage: AppIcon.filters,
                    description: Text("Clear a filter to see more exercises.")
                )
                clearFiltersButton
            }
        } else {
            ContentUnavailableView(
                "No exercises available",
                systemImage: AppIcon.exercise,
                description: Text("Create an exercise in the library, then return here to add it.")
            )
        }
    }

    private var clearFiltersButton: some View {
        Button("Clear filters") { filter.clear() }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("clear-exercise-filters")
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
            Button(action: onAdd) {
                HStack(alignment: .center, spacing: Spacing.m) {
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

                    Image(systemName: isAdded ? AppIcon.checkmarkCircle : AppIcon.plus)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(isAdded ? Color.trameCompleted : Color.trameStrength)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityIdentifier(isAdded ? "added-exercise-\(exercise.name)" : "add-exercise-\(exercise.name)")
            .accessibilityLabel(isAdded ? "\(exercise.name), added" : "Add \(exercise.name)")

            Button {
                isShowingDetails = true
            } label: {
                Image(systemName: AppIcon.info)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameSubdued)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-link-\(exercise.name)")
            .accessibilityLabel("About \(exercise.name)")
        }
        .padding(.vertical, Spacing.xs)
        .navigationDestination(isPresented: $isShowingDetails) {
            ExerciseView(exercise: exercise)
        }
    }
}

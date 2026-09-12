//
//  WorkoutTemplateFormView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

/// Builds a saved workout: name it, pick exercises, order them, pair them,
/// and optionally attach a warm-up or post-workout stretch.
///
/// Supersets already existed in the plan editor and during a live session, but
/// not here — so a workout you could improvise or prescribe could not be saved.
/// Selection is an ordered list rather than a name set, because a superset is
/// defined by contiguous position.
///
/// The live exercise catalogue is queried here rather than snapshotted by the
/// presenter, so a custom exercise created from this sheet appears immediately
/// and can be added without closing the draft.
struct WorkoutTemplateFormView: View {
    /// Selection has to survive reordering and grouping, so each pick gets its
    /// own identity rather than being keyed by the exercise it points at.
    private struct Selection: Identifiable, Equatable {
        let id = UUID()
        let exercise: Exercise
        var supersetGroupID: UUID?
        var targetSets = 3
        var repRangeMinimum = 8
        var repRangeMaximum = 12
        var restSeconds = 90
        var targetRIR: Int?
        var targetRPE: Double?
        var notes: String?

        static func == (lhs: Selection, rhs: Selection) -> Bool {
            lhs.id == rhs.id && lhs.supersetGroupID == rhs.supersetGroupID
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { !$0.isArchived })
    private var availableExercises: [Exercise]
    @Query(
        filter: #Predicate<MobilityRoutine> { !$0.isArchived },
        sort: \MobilityRoutine.name
    )
    private var mobilityRoutines: [MobilityRoutine]

    let onSave: (String, [TemplateExercise], MobilityRoutine?, MobilityRoutine?) -> Void

    @State private var name = ""
    @State private var selection: [Selection] = []
    @State private var detailExercise: Exercise?
    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var isCreatingExercise = false
    @State private var isShowingPersonalizedBuilder = false
    @State private var isShowingDiscardConfirmation = false
    @State private var preWorkoutRoutine: MobilityRoutine?
    @State private var postWorkoutRoutine: MobilityRoutine?
    @State private var mobilityPlacementToEdit: WorkoutMobilityPlacement?
    @FocusState private var isNameFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private var showsMobility: Bool {
        FeatureFlags.current.isEnabled(.mobility)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .focused($isNameFocused)
                    .accessibilityIdentifier("template-name-field")

                if FeatureFlags.current.isEnabled(.workoutGeneration) {
                    Button {
                        isShowingPersonalizedBuilder = true
                    } label: {
                        Label("Draft a personalized workout", systemImage: AppIcon.recipeGenerate)
                    }
                    .accessibilityIdentifier("template-personalized-workout-entry")
                    Text("Use your goals, equipment, and available time to draft an editable workout.")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                }
            } footer: {
                if trimmedName.isEmpty && hasUnsavedWork {
                    Text("Name this workout to save it.")
                }
            }

            if !selection.isEmpty {
                selectedSection
            }

            if showsMobility {
                mobilitySection
            }

            exercisePickerSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(item: $detailExercise) { exercise in
            ExerciseView(exercise: ExerciseDetailSnapshot(exercise: exercise))
        }
        .navigationTitle("New Workout")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.trameStrength)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedWork {
                        isShowingDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        trimmedName,
                        templateExercises,
                        preWorkoutRoutine,
                        postWorkoutRoutine
                    )
                    dismiss()
                }
                .accessibilityIdentifier("save-template")
                .disabled(trimmedName.isEmpty)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNameFocused = false
                    isSearchFocused = false
                }
                .accessibilityIdentifier("dismiss-template-search-keyboard")
            }
        }
        // A named workout, a selected exercise, or a stretch is real work. The
        // system search bar used to sit at the sheet's thumb edge, so a swipe
        // meant to dismiss search wiped the draft. Block that, and confirm
        // Cancel the same way the plan form does.
        .interactiveDismissDisabled(hasUnsavedWork)
        .presentationContentInteraction(.scrolls)
        .alert(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation
        ) {
            Button("Discard workout", role: .destructive) { dismiss() }
                .accessibilityIdentifier("confirm-discard-workout-template")
            Button("Keep editing", role: .cancel) {}
                .accessibilityIdentifier("keep-editing-workout-template")
        } message: {
            Text("The name, exercises, and stretches you have chosen will not be saved.")
        }
        .sheet(isPresented: $isCreatingExercise) {
            NavigationStack {
                ExerciseFormView { exercise in
                    _ = LibraryService.createCustomExercise(exercise, using: modelContext)
                    add(exercise)
                }
            }
        }
        .sheet(isPresented: $isShowingPersonalizedBuilder) {
            PersonalizedWorkoutBuilderView(
                availableExercises: availableExercises,
                onApply: applyGeneratedDraft
            )
        }
        .sheet(item: $mobilityPlacementToEdit) { placement in
            WorkoutMobilityRoutinePicker(
                placement: placement,
                routines: mobilityRoutines,
                currentRoutine: routine(for: placement)
            ) { routine in
                setRoutine(routine, for: placement)
            }
        }
    }
}

// MARK: - Selected exercises

private extension WorkoutTemplateFormView {
    var selectedSection: some View {
        Section {
            ForEach(Array(selection.enumerated()), id: \.element.id) { index, item in
                selectedRow(at: index, item: item)
            }
        } header: {
            Text("Selected · \(selection.count)")
        } footer: {
            if selection.contains(where: { $0.supersetGroupID != nil }) {
                Text("Superset exercises are performed back to back with no rest between them.")
            }
        }
    }

    private func selectedRow(at index: Int, item: Selection) -> some View {
        HStack(spacing: Spacing.m) {
            if item.supersetGroupID != nil {
                Image(systemName: AppIcon.relationship)
                    .font(AppFont.eyebrow)
                    .foregroundStyle(Color.trameStrength)
                    .frame(width: 20)
                    .accessibilityLabel("In a superset")
            } else {
                Color.clear.frame(width: 20)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.exercise.name)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)
                if item.supersetGroupID != nil {
                    Text("Superset")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameStrength)
                }
            }

            Spacer(minLength: Spacing.s)

            Menu {
                Button("Move up") { move(from: index, to: index - 1) }
                    .disabled(index == 0)
                Button("Move down") { move(from: index, to: index + 1) }
                    .disabled(index == selection.count - 1)

                if item.supersetGroupID == nil {
                    Button("Superset with next") { supersetWithNext(at: index) }
                        .disabled(!canSupersetWithNext(at: index))
                } else {
                    Button("Remove from superset") { removeFromSuperset(at: index) }
                }

                Button("Remove", role: .destructive) { remove(at: index) }
            } label: {
                    Image(systemName: AppIcon.ellipsis)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(item.exercise.name)")
            .accessibilityIdentifier("template-selected-menu-\(item.exercise.name)")
        }
        .accessibilityIdentifier("template-selected-\(item.exercise.name)")
    }
}

// MARK: - Workout mobility

private extension WorkoutTemplateFormView {
    var mobilitySection: some View {
        Section {
            ForEach(WorkoutMobilityPlacement.allCases, id: \.self) { placement in
                WorkoutMobilityLinkRow(
                    placement: placement,
                    routine: routine(for: placement),
                    unavailableName: nil,
                    isEditable: true
                ) {
                    mobilityPlacementToEdit = placement
                }
                .accessibilityIdentifier("template-form-\(placement.accessibilityIdentifier)")
            }
        } header: {
            Text("Stretches")
        } footer: {
            Text("These run before or after future starts of this workout.")
        }
    }

    func routine(for placement: WorkoutMobilityPlacement) -> MobilityRoutine? {
        switch placement {
        case .beforeWorkout: preWorkoutRoutine
        case .afterWorkout: postWorkoutRoutine
        }
    }

    func setRoutine(_ routine: MobilityRoutine?, for placement: WorkoutMobilityPlacement) {
        switch placement {
        case .beforeWorkout:
            preWorkoutRoutine = routine
        case .afterWorkout:
            postWorkoutRoutine = routine
        }
    }
}

// MARK: - Exercise picker

private extension WorkoutTemplateFormView {
    var exercisePickerSection: some View {
        let results = filteredExercises

        return Section {
            if availableExercises.isEmpty {
                ContentUnavailableView {
                    Label("No exercises yet", systemImage: AppIcon.exercise)
                } description: {
                    Text("Create an exercise to start building this workout.")
                } actions: {
                    Button("Create Exercise") {
                        isCreatingExercise = true
                    }
                    .buttonStyle(.tramePrimaryAction)
                    .accessibilityIdentifier("create-exercise-empty-state")
                }
            } else {
                exerciseSearchField
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: Spacing.s,
                        leading: 0,
                        bottom: Spacing.s,
                        trailing: 0
                    ))
                    .listRowSeparator(.hidden)

                ExerciseFilterControls(filter: $filter, resultCount: results.count)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                if results.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("No exercises match your filters.")
                                .foregroundStyle(Color.trameSubdued)
                            Button("Clear filters") {
                                filter.clear()
                            }
                            .font(AppFont.subheadlineSemibold)
                        }
                    }
                } else {
                    ForEach(results, id: \.id) { exercise in
                        ExerciseSelectionRow(
                            exercise: exercise,
                            isSelected: isSelected(exercise),
                            onSelect: { add(exercise) },
                            onShowDetail: { detailExercise = exercise }
                        )
                    }
                }
            }
        } header: {
            Text("Exercises")
        }
    }

    var exerciseSearchField: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: AppIcon.search)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .accessibilityHidden(true)
            TextField("Search exercises", text: $searchText)
                .font(AppFont.bodyMedium)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }
                .focused($isSearchFocused)
                .accessibilityIdentifier("template-exercise-search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: AppIcon.failureCircle)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .background(Color.trameRow, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Selection editing

private extension WorkoutTemplateFormView {
    func isSelected(_ exercise: Exercise) -> Bool {
        selection.contains { $0.exercise.id == exercise.id }
    }

    /// The catalogue only adds. Removal lives on the Selected row, where the
    /// sets and pairing that would be lost are visible.
    func add(_ exercise: Exercise) {
        guard !isSelected(exercise) else { return }
        selection.append(Selection(exercise: exercise, supersetGroupID: nil))
    }

    func applyGeneratedDraft(_ draft: ValidatedWorkoutDraft) {
        name = draft.name
        selection = draft.exercises.map { item in
            Selection(
                exercise: item.exercise,
                supersetGroupID: item.supersetGroupID,
                targetSets: item.targetSets,
                repRangeMinimum: item.repRangeMinimum,
                repRangeMaximum: item.repRangeMaximum,
                restSeconds: item.restSeconds,
                targetRIR: item.targetRIR,
                targetRPE: item.targetRPE,
                notes: item.notes
            )
        }
        normalizeSupersets()
    }

    func remove(at index: Int) {
        guard selection.indices.contains(index) else { return }
        selection.remove(at: index)
        normalizeSupersets()
    }

    /// Moving an exercise out of its pair's neighbourhood dissolves the pair
    /// rather than silently dragging the partner along.
    func move(from index: Int, to destination: Int) {
        guard selection.indices.contains(index), selection.indices.contains(destination) else { return }
        let item = selection.remove(at: index)
        selection.insert(item, at: destination)
        normalizeSupersets()
    }

    func canSupersetWithNext(at index: Int) -> Bool {
        selection.indices.contains(index + 1)
    }

    /// Pairing with an already-grouped neighbour extends that group, so three or
    /// more exercises can share one superset without a separate control.
    func supersetWithNext(at index: Int) {
        guard canSupersetWithNext(at: index) else { return }
        let groupID = selection[index + 1].supersetGroupID ?? UUID()
        selection[index].supersetGroupID = groupID
        selection[index + 1].supersetGroupID = groupID
        normalizeSupersets()
    }

    func removeFromSuperset(at index: Int) {
        guard selection.indices.contains(index) else { return }
        selection[index].supersetGroupID = nil
        normalizeSupersets()
    }

    /// Mirrors `SupersetGrouping`'s rule — at least two contiguous members —
    /// against the in-memory draft, which has no `TemplateExercise` yet.
    func normalizeSupersets() {
        let grouped = Dictionary(grouping: selection.indices.compactMap { index in
            selection[index].supersetGroupID.map { ($0, index) }
        }, by: \.0)

        for (groupID, members) in grouped {
            let indexes = members.map(\.1).sorted()
            let isContiguous = indexes.enumerated().allSatisfy { offset, index in
                index == indexes[0] + offset
            }
            guard indexes.count >= 2, isContiguous else {
                for index in selection.indices where selection[index].supersetGroupID == groupID {
                    selection[index].supersetGroupID = nil
                }
                continue
            }
        }
    }
}

// MARK: - Output

private extension WorkoutTemplateFormView {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether dismissing would lose something the lifter chose.
    var hasUnsavedWork: Bool {
        !trimmedName.isEmpty
            || !selection.isEmpty
            || preWorkoutRoutine != nil
            || postWorkoutRoutine != nil
    }

    var filteredExercises: [Exercise] {
        availableExercises
            .filter { filter.matches($0, searchText: searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var templateExercises: [TemplateExercise] {
        let built = selection.enumerated().map { index, item in
            TemplateExercise(
                exercise: item.exercise,
                order: index,
                targetSets: item.targetSets,
                repRangeMinimum: item.repRangeMinimum,
                repRangeMaximum: item.repRangeMaximum,
                restSeconds: item.restSeconds,
                targetRPE: item.targetRPE,
                targetRIR: item.targetRIR,
                notes: item.notes,
                supersetGroupID: item.supersetGroupID
            )
        }
        SupersetGrouping.dissolveInvalidGroups(in: built)
        return built
    }
}

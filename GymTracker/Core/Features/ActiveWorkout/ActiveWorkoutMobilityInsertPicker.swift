import SwiftUI
import SwiftData

/// Mid-session stretch picker for Active Workout.
///
/// Adds **one movement** after the current exercise so the session stays
/// Bench → stretch → next lift. A full routine remains a secondary path.
/// Never writes template or rotation mobility links — those stay on
/// `WorkoutMobilityRoutinePicker`.
struct ActiveWorkoutMobilityInsertPicker: View {
    @Environment(\.dismiss) private var dismiss

    let definitions: [MobilityDefinition]
    let routines: [MobilityRoutine]
    /// Returns `true` when the session started. `false` means the one-active
    /// gate refused; the parent shows Resume existing vs Cancel insert.
    let onStartMovement: (MobilityDefinition) -> Bool
    let onStartRoutine: (MobilityRoutine) -> Bool

    @State private var searchText = ""
    @State private var routineSearchText = ""
    @State private var filter = MobilityFilterState()
    @State private var isShowingRoutines = false
    @FocusState private var isSearchFocused: Bool

    private static let preferredPurposes: Set<MobilityRoutinePurpose?> = [
        .development,
        .preparation
    ]

    var body: some View {
        NavigationStack {
            movementContent
                .background(Color.trameCanvas)
                .navigationTitle(String(localized: "Add stretch"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("cancel-active-workout-mobility-insert")
                    }
                }
                .navigationDestination(isPresented: $isShowingRoutines) {
                    routineContent
                        .background(Color.trameCanvas)
                        .navigationTitle(String(localized: "Full routine"))
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .accessibilityIdentifier("active-workout-mobility-insert-picker")
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("stretch-picker-screen", label: "Stretch picker")
        }
    }

    @ViewBuilder
    private var movementContent: some View {
        let results = visibleDefinitions

        List {
            Section {
                MobilityFilterControls(filter: $filter, resultCount: results.count)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if selectableDefinitions.isEmpty {
                ContentUnavailableView {
                    Label("No mobility movements", systemImage: AppIcon.mobility)
                } description: {
                    Text("Create a movement in Mobility, then return here to add it between exercises.")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("active-workout-mobility-insert-movements-empty")
            } else if results.isEmpty {
                pickerEmptyState
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("stretch-picker-no-results")
            } else {
                Section(resultsSectionTitle) {
                    ForEach(results) { definition in
                        movementRow(definition)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.visible)
                            .listRowSeparatorTint(Color.trameSeparator)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search by stretch or region"
        )
        .searchFocused($isSearchFocused)
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            if selectableRoutines.isEmpty == false {
                Button {
                    isSearchFocused = false
                    isShowingRoutines = true
                } label: {
                    Text("Use a full routine instead")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.screenInset)
                .padding(.vertical, Spacing.s)
                .background(Color.trameSurface)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
                .accessibilityHint("Opens a list of multi-movement routines.")
                .accessibilityIdentifier("active-workout-mobility-insert-catalog")
            }
        }
    }

    @ViewBuilder
    private var routineContent: some View {
        List {
            if selectableRoutines.isEmpty {
                ContentUnavailableView {
                    Label("No mobility routines", systemImage: AppIcon.mobility)
                } description: {
                    Text("Create a routine in Mobility, then return here to run it mid-workout.")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("active-workout-mobility-insert-routines-empty")
            } else if visibleRoutineGroups.isEmpty {
                ContentUnavailableView.search(text: routineSearchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("active-workout-mobility-insert-routine-no-results")
            } else {
                ForEach(visibleRoutineGroups) { group in
                    Section(group.title) {
                        ForEach(group.routines) { routine in
                            routineRow(routine)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(Color.trameSeparator)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $routineSearchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search routines or movements"
        )
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
    }

    private var resultsSectionTitle: String {
        let isBrowsing = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filter.activeFilterCount == 0
        return isBrowsing ? String(localized: "All stretches") : String(localized: "Results")
    }

    @ViewBuilder
    private var pickerEmptyState: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(spacing: Spacing.m) {
                ContentUnavailableView(
                    "No matching stretches",
                    systemImage: AppIcon.search,
                    description: Text("Try another name or body region.")
                )
                if filter.activeFilterCount > 0 { clearFiltersButton }
            }
        } else if filter != MobilityFilterState() {
            VStack(spacing: Spacing.m) {
                ContentUnavailableView(
                    "No stretches in these filters",
                    systemImage: AppIcon.filters,
                    description: Text("Clear a filter to see more stretches.")
                )
                clearFiltersButton
            }
        } else {
            ContentUnavailableView(
                "No mobility movements",
                systemImage: AppIcon.mobility,
                description: Text("Create a movement in Mobility, then return here to add it between exercises.")
            )
        }
    }

    private var clearFiltersButton: some View {
        Button("Clear filters") { filter.clear() }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("clear-stretch-filters")
    }

    private func movementRow(_ definition: MobilityDefinition) -> some View {
        MobilityInsertSelectionRow(
            definition: definition,
            summary: movementSubtitle(for: definition)
        ) {
            isSearchFocused = false
            if onStartMovement(definition) {
                dismiss()
            }
        }
    }

    private func routineRow(_ routine: MobilityRoutine) -> some View {
        Button {
            if onStartRoutine(routine) {
                dismiss()
            }
        } label: {
            HStack(alignment: .center, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(routine.name)
                        .font(AppFont.body.weight(.semibold))
                        .foregroundStyle(Color.trameText)
                        .multilineTextAlignment(.leading)
                    Text(WorkoutMobilityPresentation.routineSummary(for: routine))
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.plus)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.trameMobility)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(routine.name), \(WorkoutMobilityPresentation.routineSummary(for: routine))")
        .accessibilityHint("Starts this routine inside the current workout.")
        .accessibilityIdentifier("active-workout-mobility-insert-routine-\(routine.id)")
    }

    private var selectableDefinitions: [MobilityDefinition] {
        definitions.filter { $0.isArchived == false }
    }

    private var selectableRoutines: [MobilityRoutine] {
        routines.filter { $0.isArchived == false && $0.orderedItems.isEmpty == false }
    }

    private var visibleDefinitions: [MobilityDefinition] {
        selectableDefinitions
            .filter { filter.matches($0, searchText: searchText) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var visibleRoutineGroups: [RoutineGroup] {
        let visibleRoutines = selectableRoutines
            .filter(matchesRoutineSearch)
            .sorted(by: routineSort)

        let preferred = visibleRoutines.filter { Self.preferredPurposes.contains($0.purpose) }
        let remaining = visibleRoutines.filter { !Self.preferredPurposes.contains($0.purpose) }

        var groups: [RoutineGroup] = []
        if preferred.isEmpty == false {
            groups.append(RoutineGroup(id: "suggested", title: String(localized: "Suggested"), routines: preferred))
        }
        if remaining.isEmpty == false {
            groups.append(RoutineGroup(id: "all", title: String(localized: "All routines"), routines: remaining))
        }
        return groups
    }

    private func matchesRoutineSearch(_ routine: MobilityRoutine) -> Bool {
        let query = routineSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return true }
        return routine.name.localizedCaseInsensitiveContains(query)
            || routine.orderedItems.contains {
                $0.definition.name.localizedCaseInsensitiveContains(query)
            }
    }

    private func routineSort(_ lhs: MobilityRoutine, _ rhs: MobilityRoutine) -> Bool {
        if lhs.purpose != rhs.purpose {
            return purposeRank(lhs.purpose) < purposeRank(rhs.purpose)
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func purposeRank(_ purpose: MobilityRoutinePurpose?) -> Int {
        guard let purpose else { return MobilityRoutinePurpose.displayOrder.count }
        return MobilityRoutinePurpose.displayOrder.firstIndex(of: purpose)
            ?? MobilityRoutinePurpose.displayOrder.count
    }

    private func movementSubtitle(for definition: MobilityDefinition) -> String {
        var parts: [String] = []
        if let familyName = definition.family?.name, familyName.isEmpty == false {
            parts.append(familyName)
        }
        parts.append(movementSummary(for: definition))
        return parts.joined(separator: WorkoutMobilityPresentation.separator)
    }

    private func movementSummary(for definition: MobilityDefinition) -> String {
        switch definition.trackingType {
        case .duration:
            if let seconds = definition.defaultDurationSeconds {
                return String(localized: "Hold · \(seconds)s")
            }
            return String(localized: "Hold")
        case .repetitions:
            if let reps = definition.defaultRepetitions {
                return String(localized: "Reps · \(reps)")
            }
            return String(localized: "Reps")
        }
    }

    private struct RoutineGroup: Identifiable {
        let id: String
        let title: String
        let routines: [MobilityRoutine]
    }
}

private struct MobilityInsertSelectionRow: View {
    let definition: MobilityDefinition
    let summary: String
    let onAdd: () -> Void
    @State private var isShowingDetails = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Button(action: onAdd) {
                HStack(alignment: .center, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(definition.name)
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(Color.trameText)
                            .multilineTextAlignment(.leading)
                        Text(summary)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .multilineTextAlignment(.leading)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: Spacing.s)

                    Image(systemName: AppIcon.plus)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.trameMobility)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("active-workout-mobility-insert-movement-\(definition.id)")
            .accessibilityLabel("Add \(definition.name), \(summary)")
            .accessibilityHint("Adds this stretch after the current exercise.")

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
            .accessibilityIdentifier("stretch-link-\(definition.name)")
            .accessibilityLabel("About \(definition.name)")
        }
        .padding(.vertical, Spacing.xs)
        .navigationDestination(isPresented: $isShowingDetails) {
            MobilityDefinitionInspectView(definition: definition, summary: summary)
        }
    }
}

private struct MobilityDefinitionInspectView: View {
    let definition: MobilityDefinition
    let summary: String

    var body: some View {
        List {
            Section {
                Text(summary)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .listRowBackground(Color.clear)
            }

            if let instructions = definition.instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
               instructions.isEmpty == false {
                Section("Instructions") {
                    Text(instructions)
                        .font(AppFont.body)
                        .foregroundStyle(Color.trameText)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

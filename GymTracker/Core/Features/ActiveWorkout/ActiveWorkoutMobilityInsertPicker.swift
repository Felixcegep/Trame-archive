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
    @State private var isShowingRoutines = false

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
    }

    @ViewBuilder
    private var movementContent: some View {
        VStack(spacing: 0) {
            Text("Adds one stretch after this exercise. Finish it, then continue to the next.")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenInset)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.s)
                .accessibilityIdentifier("active-workout-mobility-insert-hint")

            if selectableDefinitions.isEmpty {
                ContentUnavailableView {
                    Label("No mobility movements", systemImage: AppIcon.mobility)
                } description: {
                    Text("Create a movement in Mobility, then return here to add it between exercises.")
                }
                .accessibilityIdentifier("active-workout-mobility-insert-movements-empty")
            } else {
                movementList
                    .searchable(text: $searchText, prompt: "Search stretches")
            }

            if selectableRoutines.isEmpty == false {
                Button {
                    isShowingRoutines = true
                } label: {
                    Text("Use a full routine instead")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a list of multi-movement routines.")
                .accessibilityIdentifier("active-workout-mobility-insert-catalog")
            }
        }
    }

    @ViewBuilder
    private var routineContent: some View {
        VStack(spacing: 0) {
            Text("Runs the whole routine now, then returns to the next exercise.")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenInset)
                .padding(.vertical, Spacing.s)

            if selectableRoutines.isEmpty {
                ContentUnavailableView {
                    Label("No mobility routines", systemImage: AppIcon.mobility)
                } description: {
                    Text("Create a routine in Mobility, then return here to run it mid-workout.")
                }
                .accessibilityIdentifier("active-workout-mobility-insert-routines-empty")
            } else {
                routineList
                    .searchable(text: $searchText, prompt: "Search routines or movements")
            }
        }
    }

    private var movementList: some View {
        List {
            if visibleDefinitions.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("active-workout-mobility-insert-movement-no-results")
            } else {
                Section(String(localized: "Stretches")) {
                    ForEach(visibleDefinitions) { definition in
                        movementRow(definition)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var routineList: some View {
        List {
            if visibleRoutineGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("active-workout-mobility-insert-routine-no-results")
            } else {
                ForEach(visibleRoutineGroups) { group in
                    Section(group.title) {
                        ForEach(group.routines) { routine in
                            routineRow(routine)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func movementRow(_ definition: MobilityDefinition) -> some View {
        Button {
            if onStartMovement(definition) {
                dismiss()
            }
        } label: {
            HStack(alignment: .center, spacing: Spacing.m) {
                Image(systemName: AppIcon.mobility)
                    .foregroundStyle(Color.trameMobility)
                    .frame(width: ComponentSize.minimumTouchTarget)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(definition.name)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)

                    Text(movementSummary(for: definition))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(definition.name), \(movementSummary(for: definition))")
        .accessibilityHint("Adds this stretch after the current exercise.")
        .accessibilityIdentifier("active-workout-mobility-insert-movement-\(definition.id)")
    }

    private func routineRow(_ routine: MobilityRoutine) -> some View {
        Button {
            if onStartRoutine(routine) {
                dismiss()
            }
        } label: {
            HStack(alignment: .center, spacing: Spacing.m) {
                Image(systemName: routine.purpose.map(purposeIcon) ?? AppIcon.mobility)
                    .foregroundStyle(Color.trameMobility)
                    .frame(width: ComponentSize.minimumTouchTarget)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(routine.name)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)

                    Text(WorkoutMobilityPresentation.routineSummary(for: routine))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
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
            .filter(matchesDefinitionSearch)
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

    private func matchesDefinitionSearch(_ definition: MobilityDefinition) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return true }
        return definition.name.localizedCaseInsensitiveContains(query)
            || (definition.instructions?.localizedCaseInsensitiveContains(query) ?? false)
    }

    private func matchesRoutineSearch(_ routine: MobilityRoutine) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func purposeIcon(_ purpose: MobilityRoutinePurpose) -> String {
        switch purpose {
        case .preparation: AppIcon.mobilityPurposePreparation
        case .development: AppIcon.mobilityPurposeDevelopment
        case .cooldown: AppIcon.mobilityPurposeCooldown
        }
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

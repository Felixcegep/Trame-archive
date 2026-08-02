import SwiftUI

/// Presentation-only formatting shared by every workout-mobility surface, so the
/// picker, the placement rows, and the rotation slot rows describe the same
/// routine with the same words. It reads values that are already loaded and
/// performs no persistence or domain work.
enum WorkoutMobilityPresentation {
    static let separator = " · "

    static func durationText(for routine: MobilityRoutine) -> String {
        let estimate = MobilityRoutineDurationEstimate.estimate(for: routine)
        switch estimate.completeness {
        case .complete:
            return String(localized: "About \(minutesText(estimate.knownDurationSeconds))")
        case .partial:
            return String(localized: "At least \(minutesText(estimate.knownDurationSeconds))")
        case .unknown:
            return String(localized: "Duration varies")
        }
    }

    static func purposeText(for routine: MobilityRoutine) -> String {
        routine.purpose?.displayName ?? String(localized: "Purpose not specified")
    }

    /// The picker's supporting line: what the routine is for, how long it takes,
    /// and how much of it there is.
    static func routineSummary(for routine: MobilityRoutine) -> String {
        [
            durationText(for: routine),
            purposeText(for: routine),
            CountPhrase.movements(routine.items.count)
        ].joined(separator: separator)
    }

    /// The linked-routine line on a placement row. Purpose is omitted rather
    /// than guessed when the author never chose one.
    static func linkSummary(for routine: MobilityRoutine) -> String {
        var components = [routine.name, durationText(for: routine)]
        if let purpose = routine.purpose {
            components.append(purpose.displayName)
        }
        return components.joined(separator: separator)
    }

    /// Resolves what to call a link: the live routine when it still exists,
    /// otherwise the recorded name so a deleted routine stays legible.
    static func placementName(routine: MobilityRoutine?, snapshotName: String?) -> String? {
        routine?.name ?? snapshotName
    }

    /// One caption summarising both placements of a template or rotation slot,
    /// so a row that opens a mobility screen says so before it is tapped.
    static func placementsSummary(before: String?, after: String?) -> String {
        var components: [String] = []
        if let before {
            components.append("\(WorkoutMobilityPlacement.beforeWorkout.title): \(before)")
        }
        if let after {
            components.append("\(WorkoutMobilityPlacement.afterWorkout.title): \(after)")
        }
        guard components.isEmpty == false else {
            return String(localized: "No mobility linked")
        }
        return components.joined(separator: separator)
    }

    private static func minutesText(_ seconds: Int) -> String {
        let minutes = max(1, Int(ceil(Double(seconds) / 60)))
        return CountPhrase.minutes(minutes)
    }
}

struct WorkoutMobilityRoutinePicker: View {
    @Environment(\.dismiss) private var dismiss

    let placement: WorkoutMobilityPlacement
    let routines: [MobilityRoutine]
    let currentRoutine: MobilityRoutine?
    let onSave: (MobilityRoutine?) -> Void

    @State private var selection: MobilityRoutine?
    @State private var searchText = ""
    @State private var isConfirmingRemoval = false

    init(
        placement: WorkoutMobilityPlacement,
        routines: [MobilityRoutine],
        currentRoutine: MobilityRoutine?,
        onSave: @escaping (MobilityRoutine?) -> Void
    ) {
        self.placement = placement
        self.routines = routines
        self.currentRoutine = currentRoutine
        self.onSave = onSave
        _selection = State(initialValue: currentRoutine)
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.gymBackground)
                .navigationTitle(placement.pickerTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        // Cancel never calls onSave, so the existing link is
                        // preserved exactly as it was.
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("cancel-mobility-link")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(selection)
                            dismiss()
                        }
                        .disabled(hasUnsavedChange == false)
                        .accessibilityIdentifier("save-mobility-link")
                    }
                }
        }
        .accessibilityIdentifier("mobility-link-picker")
        .confirmationDialog(
            "Remove this routine?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Routine", role: .destructive) {
                onSave(nil)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This changes future starts only. Completed mobility history stays unchanged.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if selectableRoutines.isEmpty {
            // An empty library cannot be fixed from inside this sheet, so the
            // empty state names where the routine has to be created instead of
            // offering an action that would dead-end here.
            ContentUnavailableView {
                Label("No mobility routines", systemImage: AppIcon.mobility)
            } description: {
                Text("Create a routine in Mobility, then return here to connect it to this workout.")
            }
            .accessibilityIdentifier("mobility-link-picker-empty")
        } else {
            routineList
                .searchable(text: $searchText, prompt: "Search routines or movements")
        }
    }

    private var routineList: some View {
        List {
            if visibleGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("mobility-link-picker-no-results")
            } else {
                ForEach(visibleGroups) { group in
                    Section(group.title) {
                        ForEach(group.routines) { routine in
                            routineRow(routine)
                        }
                    }
                }
            }

            // Removal stays reachable regardless of the search term and stays in
            // its own section, away from Save.
            if currentRoutine != nil {
                Section {
                    Button("Remove routine", role: .destructive) {
                        isConfirmingRemoval = true
                    }
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("mobility-link-remove")
                } footer: {
                    Text("This changes future starts only. Completed mobility history stays unchanged.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func routineRow(_ routine: MobilityRoutine) -> some View {
        let isSelected = routine.id == selection?.id

        return Button {
            selection = routine
        } label: {
            HStack(alignment: .center, spacing: Spacing.m) {
                GymIconChip(
                    systemImage: routine.purpose.map(purposeIcon) ?? AppIcon.mobility,
                    tint: isSelected ? Color.gymPrimary : Color.gymAccent
                )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(routine.name)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)

                    Text(WorkoutMobilityPresentation.routineSummary(for: routine))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.s)

                // A symbol, not only a tint, carries the selected state.
                if isSelected {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .foregroundStyle(Color.gymPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(routine.name), \(WorkoutMobilityPresentation.routineSummary(for: routine))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("mobility-link-picker-routine-\(routine.id)")
    }

    private var hasUnsavedChange: Bool {
        selection?.id != currentRoutine?.id
    }

    /// Archived routines are never offered. The callers already query
    /// non-archived routines; this keeps the picker correct on its own terms.
    private var selectableRoutines: [MobilityRoutine] {
        routines.filter { $0.isArchived == false }
    }

    private var visibleGroups: [PickerGroup] {
        let visibleRoutines = selectableRoutines
            .filter(matchesSearch)
            .sorted(by: routineSort)

        // Purpose ranks the suggestions; it never removes a choice.
        let preferred = visibleRoutines.filter { placement.preferredPurposes.contains($0.purpose) }
        let remaining = visibleRoutines.filter { !placement.preferredPurposes.contains($0.purpose) }

        var groups: [PickerGroup] = []
        if preferred.isEmpty == false {
            groups.append(PickerGroup(id: "suggested", title: String(localized: "Suggested"), routines: preferred))
        }
        if remaining.isEmpty == false {
            groups.append(PickerGroup(id: "all", title: String(localized: "All routines"), routines: remaining))
        }
        return groups
    }

    private func matchesSearch(_ routine: MobilityRoutine) -> Bool {
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
        return MobilityRoutinePurpose.displayOrder.firstIndex(of: purpose) ?? MobilityRoutinePurpose.displayOrder.count
    }

    private func purposeIcon(_ purpose: MobilityRoutinePurpose) -> String {
        switch purpose {
        case .preparation: AppIcon.mobilityPurposePreparation
        case .development: AppIcon.mobilityPurposeDevelopment
        case .cooldown: AppIcon.mobilityPurposeCooldown
        }
    }

    private struct PickerGroup: Identifiable {
        let id: String
        let title: String
        let routines: [MobilityRoutine]
    }
}

struct WorkoutMobilityLinkRow: View {
    let placement: WorkoutMobilityPlacement
    let routine: MobilityRoutine?
    let unavailableName: String?
    let isEditable: Bool
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if isEditable {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Choose, replace, or remove this routine.")
            .accessibilityIdentifier(placement.accessibilityIdentifier)
        } else {
            rowContent
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("This routine is a snapshot from when the rotation started.")
                .accessibilityIdentifier(placement.accessibilityIdentifier)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            GymIconChip(systemImage: placement.systemImage, tint: Color.gymAccent)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(placement.title)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                Text(detailText)
                    .font(AppFont.caption)
                    .foregroundStyle(unavailableName == nil ? Color.gymSubduedText : Color.gymDestructive)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.s)

            // The trailing symbol, not the tint, says whether this row can be
            // edited or is a locked snapshot.
            Image(systemName: isEditable ? AppIcon.chevronRight : AppIcon.lock)
                .font(isEditable ? AppFont.captionBold : AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var accessibilityLabel: String {
        "\(placement.title), \(detailText)"
    }

    private var detailText: String {
        if let routine {
            return WorkoutMobilityPresentation.linkSummary(for: routine)
        }
        if let unavailableName {
            return String(localized: "\(unavailableName) is unavailable")
        }
        // A snapshot records that nothing was linked; an editable row invites
        // the user to link something.
        return isEditable ? String(localized: "Not configured") : String(localized: "None")
    }
}

extension WorkoutMobilityPlacement: Identifiable {
    var id: String {
        switch self {
        case .beforeWorkout: "before-workout"
        case .afterWorkout: "after-workout"
        }
    }

    var title: String {
        switch self {
        case .beforeWorkout: String(localized: "Before workout")
        case .afterWorkout: String(localized: "After workout")
        }
    }

    var pickerTitle: String {
        switch self {
        case .beforeWorkout: String(localized: "Choose before-workout mobility")
        case .afterWorkout: String(localized: "Choose after-workout mobility")
        }
    }

    var preferredPurposes: Set<MobilityRoutinePurpose?> {
        switch self {
        case .beforeWorkout: [.preparation]
        case .afterWorkout: [.cooldown]
        }
    }

    var systemImage: String {
        switch self {
        case .beforeWorkout: AppIcon.mobilityPurposePreparation
        case .afterWorkout: AppIcon.mobilityPurposeCooldown
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .beforeWorkout: "mobility-before-row"
        case .afterWorkout: "mobility-after-row"
        }
    }
}

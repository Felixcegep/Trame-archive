import SwiftUI
import SwiftData

/// Purpose-ranked mobility routine picker that **starts** a mid-session
/// `MobilitySession` inside Active Workout. It never writes template or
/// rotation mobility links — that path stays on `WorkoutMobilityRoutinePicker`.
struct ActiveWorkoutMobilityInsertPicker: View {
    @Environment(\.dismiss) private var dismiss

    let routines: [MobilityRoutine]
    /// Returns `true` when the session started. `false` means the one-active
    /// gate refused; the parent shows Resume existing vs Cancel insert.
    let onStart: (MobilityRoutine) -> Bool

    @State private var searchText = ""

    private static let preferredPurposes: Set<MobilityRoutinePurpose?> = [
        .development,
        .preparation
    ]

    var body: some View {
        NavigationStack {
            content
                .background(Color.trameCanvas)
                .navigationTitle(String(localized: "Add mobility"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("cancel-active-workout-mobility-insert")
                    }
                }
        }
        .accessibilityIdentifier("active-workout-mobility-insert-picker")
    }

    @ViewBuilder
    private var content: some View {
        if selectableRoutines.isEmpty {
            ContentUnavailableView {
                Label("No mobility routines", systemImage: AppIcon.mobility)
            } description: {
                Text("Create a routine in Mobility, then return here to run it mid-workout.")
            }
            .accessibilityIdentifier("active-workout-mobility-insert-empty")
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
                    .accessibilityIdentifier("active-workout-mobility-insert-no-results")
            } else {
                ForEach(visibleGroups) { group in
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

    private func routineRow(_ routine: MobilityRoutine) -> some View {
        Button {
            if onStart(routine) {
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

    private var selectableRoutines: [MobilityRoutine] {
        routines.filter { $0.isArchived == false && $0.orderedItems.isEmpty == false }
    }

    private var visibleGroups: [PickerGroup] {
        let visibleRoutines = selectableRoutines
            .filter(matchesSearch)
            .sorted(by: routineSort)

        let preferred = visibleRoutines.filter { Self.preferredPurposes.contains($0.purpose) }
        let remaining = visibleRoutines.filter { !Self.preferredPurposes.contains($0.purpose) }

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

    private struct PickerGroup: Identifiable {
        let id: String
        let title: String
        let routines: [MobilityRoutine]
    }
}

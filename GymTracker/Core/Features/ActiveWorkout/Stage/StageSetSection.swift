import SwiftUI
import SwiftData

/// The column titles a set list needs for one exercise.
///
/// Lifted out of `ExerciseEntryCard` so the paged stage and the legacy card
/// cannot drift into labelling the same columns differently — the per-side and
/// per-unit qualifiers in particular are the difference between "10 reps" and
/// "10 reps on each leg", and having two copies of that rule is how one of them
/// ends up wrong.
enum StageSetColumnTitles {
    static func titles(for entry: ExerciseEntry, unitSystem: UnitSystem) -> [String] {
        let trackingType = entry.trackingTypeSnapshot
        let semantics = entry.loggingSemanticsSnapshot
        var titles: [String] = []

        if trackingType.usesReps {
            let isPerSide = semantics.laterality == .unilateral && semantics.repCountingStyle == .perSide
            titles.append(isPerSide ? String(localized: "Reps / side") : String(localized: "Reps"))
        }
        if trackingType.usesWeight {
            // The unit alone, not "Weight (kg)".
            //
            // The metric's name is redundant over a column of loads and it was
            // the longest title on the row by a wide margin: on any exercise
            // tracking three metrics it wrapped to two lines while its
            // neighbours stayed on one, dropping the whole header off its
            // baseline. The qualifier survives because it changes what the
            // number means — "kg each" is per side, and losing that turns a
            // 20 kg dumbbell pair into a 20 kg total.
            let unitLabel = unitSystem == .metric ? "kg" : "lbs"
            let isPerUnit = semantics.weightEntryStyle == .perLoadUnit
            titles.append(
                isPerUnit
                    ? String(localized: "\(unitLabel) each")
                    : unitLabel
            )
        }
        // Matched to the unit suffix each cell already draws ("sec", "cal"), so
        // the column title and the value under it use one vocabulary.
        if trackingType.usesDuration { titles.append(String(localized: "sec")) }
        if trackingType.usesDistance { titles.append(String(localized: "Distance")) }
        if trackingType.usesCalories { titles.append(String(localized: "cal")) }
        return titles
    }
}

/// One band of sets — the warm-up ramp, or the working sets — with its own
/// heading and progress count. Working sets stay an open table; the warm-up
/// ramp remains one opaque object because it is a distinct training phase.
///
/// Splitting them is not decoration. Every non-UI layer in the app already
/// treats a warm-up as a different kind of set: excluded from volume, from
/// records, and from the prescribed set count, and generated as a percentage
/// ramp rather than prescribed directly. Presenting the two as one numbered
/// table with a "W (1)" subscript asked the lifter to hold that distinction in
/// their head while the app held it in a database column.
///
/// The rows themselves are the existing `SetRowView`. That component carries
/// completion validation, completed-set editing with discard, the per-set
/// duration countdown, Olympic component outcomes, daily-maximum selection, and
/// unit synchronisation — behaviour worth more than a bespoke row, and none of
/// it is what needed changing.
struct StageSetSection: View {
    let group: StageSetGrouping.Group
    let exerciseEntry: ExerciseEntry
    let viewModel: ActiveWorkoutViewModel
    let coordinator: SetInputCoordinator
    let unitSystem: UnitSystem
    @Binding var editingCompletedSetID: PersistentIdentifier?
    let previousPerformance: PreviousExercisePerformance?
    let onSetCompleted: () -> Void
    /// Only meaningful for the warm-up band; the working band is never
    /// collapsible, because collapsing the work is collapsing the page.
    @Binding var isCollapsed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isWarmUp: Bool { group.kind == .warmUp }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            header

            if !isWarmUp || !isCollapsed {
                columnHeader
                rows
                addSetButton
            }
        }
        .padding(isWarmUp ? Spacing.m : 0)
        .background {
            if isWarmUp {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.trameRow)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.layout, value: isCollapsed)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if isWarmUp {
            Button {
                isCollapsed.toggle()
            } label: {
                headerContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("warm-up-section-\(exerciseEntry.exercise.name)")
            .accessibilityHint(isCollapsed ? "Show warm-up sets" : "Hide warm-up sets")
        } else {
            headerContent
        }
    }

    private var headerContent: some View {
        HStack(spacing: Spacing.s) {
            Text(isWarmUp ? "WARM-UP" : "WORKING SETS")
                .font(AppFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(isWarmUp ? Color.trameText : Color.trameSubdued)

            Text("\(group.completedCount)/\(group.sets.count)")
                .font(AppFont.micro.monospacedDigit())
                .foregroundStyle(Color.trameSubdued)

            Spacer(minLength: Spacing.s)

            if isWarmUp {
                // States the rule rather than implying it with a tint. A lifter
                // who wonders why their warm-ups are missing from a volume
                // chart should be able to find the answer on the screen where
                // they logged them.
                if !isCollapsed, !dynamicTypeSize.isAccessibilitySize {
                    Text("Not counted in volume")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                }

                Image(systemName: isCollapsed ? AppIcon.chevronDown : AppIcon.chevronUp)
                    .font(AppFont.caption2Bold)
                    .foregroundStyle(Color.trameSubdued)
            }
        }
        .frame(minHeight: isWarmUp ? ComponentSize.minimumTouchTarget : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var headerAccessibilityLabel: String {
        let name = isWarmUp ? String(localized: "Warm-up sets") : String(localized: "Working sets")
        let progress = String(localized: "\(group.completedCount) of \(group.sets.count) complete")
        guard isWarmUp else { return "\(name). \(progress)" }
        return "\(name). \(progress). \(String(localized: "Not counted toward training volume"))"
    }

    // MARK: - Rows

    private var columnHeader: some View {
        HStack(spacing: Spacing.s) {
            Text("SET")
                .frame(width: 45, alignment: .leading)

            // Gated on the same condition `SetRowView` gates its own previous
            // column on, so the header never promises a column the rows do not
            // draw.
            if !dynamicTypeSize.isAccessibilitySize {
                Text("PREV")
                    .frame(width: 52, alignment: .leading)
            }

            ForEach(StageSetColumnTitles.titles(for: exerciseEntry, unitSystem: unitSystem), id: \.self) { title in
                Text(title.uppercased())
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer().frame(width: 44)
        }
        .font(AppFont.micro)
        .tracking(0.55)
        .foregroundStyle(Color.trameSubdued)
        // Matches the inner padding of a row card, so a column title sits over
        // the column it names rather than eight points to its left.
        .padding(.horizontal, Spacing.m)
        .accessibilityHidden(true)
    }

    /// The set table uses structural rules rather than a card around every row.
    /// Stateful rows may still receive an opaque current/completed field, while
    /// untouched work remains part of the open group.
    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(group.indexedSets, id: \.set.persistentModelID) { item in
                SetRowView(
                    index: item.index,
                    exerciseSet: item.set,
                    exerciseEntry: exerciseEntry,
                    viewModel: viewModel,
                    coordinator: coordinator,
                    editingCompletedSetID: $editingCompletedSetID,
                    onSetCompleted: onSetCompleted,
                    previousSet: previousPerformance?.set(at: item.set.orderIndex),
                    onRemove: { viewModel.removeSet(exerciseEntry, item.set) }
                )
                .id(item.set.persistentModelID)

                if item.set.persistentModelID != group.sets.last?.persistentModelID {
                    Rectangle()
                        .fill(Color.trameSeparator)
                        .frame(height: 1)
                }
            }
        }
    }

    private var addSetButton: some View {
        Button {
            viewModel.addSet(exerciseEntry)
        } label: {
            Label(isWarmUp ? "Add warm-up set" : "Add set", systemImage: AppIcon.plus)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            isWarmUp
                ? "add-warmup-set-\(exerciseEntry.exercise.name)"
                : "add-set-\(exerciseEntry.exercise.name)"
        )
    }
}

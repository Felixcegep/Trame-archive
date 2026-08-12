import SwiftUI
import SwiftData

/// Extension providing chip row controls (Set Type, Effort, Plate Calculator, Details) for `SetInputAccessoryPanel`.
extension SetInputAccessoryPanel {
    @ViewBuilder
    func chipRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                setTypeChip(set: set)

                effortChip(set: set)

                if exercise.exercise.supportsPlateCalculator {
                    // The chip answers its own question. "What do I hang on the
                    // bar" has one answer per weight, and printing it here
                    // means the sheet only has to open when the lifter wants to
                    // change the loading rather than read it.
                    //
                    // It leads the row while the weight differs from the last
                    // set they completed — that is the moment the bar
                    // physically changes — and settles back afterwards. A
                    // reference tool that shouts on every set stops being read.
                    chip(
                        title: plateChipTitle(exercise: exercise, set: set),
                        systemImage: AppIcon.plateCalculator,
                        identifier: "panel-chip-plates",
                        isProminent: needsPlateChange(exercise: exercise, set: set)
                    ) {
                        viewModel.noteSetEntryTool(.plateCalculator)
                        isShowingPlateCalculator = true
                    }
                }

                if viewModel.canCopyValuesForFocusedSet(coordinator.focus) {
                    chip(title: "Last set", systemImage: AppIcon.copy, identifier: "panel-chip-last set") {
                        viewModel.copyValuesForFocusedSet(coordinator.focus)
                        coordinator.endEntry()
                    }
                }

                chip(title: "Details", systemImage: AppIcon.advanced, identifier: "panel-details") {
                    isShowingSetDetails = true
                }
                .accessibilityHint("Tempo, set method, velocity, and other options")
            }
            .padding(.horizontal, Spacing.xxs)
        }
        .scrollIndicators(.visible)
    }

    private func setTypeChip(set: ExerciseSet) -> some View {
        Menu {
            let recent = RecentSetTypes.decode(recentSetTypesRaw).filter { $0 != set.setType }
            if recent.isEmpty == false {
                Section(String(localized: "Recently used")) {
                    setTypeOptions(recent, set: set)
                }
            }
            ForEach(SetTypeGroup.allCases, id: \.self) { group in
                Section(group.title) {
                    setTypeOptions(group.members, set: set)
                }
            }
        } label: {
            chipLabel(
                title: set.setType.title,
                systemImage: set.setType.icon,
                tint: set.setType.accentColor
            )
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel("Set type, \(set.setType.title)")
        .accessibilityHint("Change set type")
        .accessibilityIdentifier("panel-set-type")
    }

    @ViewBuilder
    private func setTypeOptions(_ types: [SetType], set: ExerciseSet) -> some View {
        ForEach(types, id: \.self) { type in
            Button {
                set.setType = type
                recentSetTypesRaw = RecentSetTypes.recording(type, into: recentSetTypesRaw)
                viewModel.persistChanges()
            } label: {
                if set.setType == type {
                    Label(type.title, systemImage: AppIcon.checkmark)
                } else {
                    Label(type.title, systemImage: type.icon)
                }
            }
            .accessibilityIdentifier("panel-set-type-option-\(type.rawValue)")
        }
    }

    private func effortChip(set: ExerciseSet) -> some View {
        Menu {
            effortQuickPicks(set: set)

            if set.rpe != nil || set.rir != nil {
                Button("Clear effort", role: .destructive) {
                    set.recordRPE(nil)
                    set.recordRIR(nil)
                    viewModel.persistChanges()
                }
            }

            Button {
                isShowingSetDetails = true
            } label: {
                Label("More options", systemImage: AppIcon.advanced)
            }
        } label: {
            chipLabel(
                title: effortChipTitle(set: set),
                systemImage: AppIcon.effort,
                tint: set.rpe != nil || set.rir != nil ? Color.gymPrimary : nil
            )
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(effortAccessibilityLabel(set: set))
        .accessibilityHint("Record how hard this set was")
        .accessibilityIdentifier("panel-effort")
    }

    @ViewBuilder
    private func effortQuickPicks(set: ExerciseSet) -> some View {
        switch effortMeasure {
        case .rir:
            ForEach(0...6, id: \.self) { value in
                Button {
                    set.recordRIR(value)
                    viewModel.noteSetEntryTool(.effortChip)
                    viewModel.persistChanges()
                } label: {
                    if set.rir == value {
                        Label("RIR \(value) · \(RIRScale.meaning(for: value))", systemImage: AppIcon.checkmark)
                    } else {
                        Text("RIR \(value) · \(RIRScale.meaning(for: value))")
                    }
                }
            }
        case .rpe:
            ForEach(Array(stride(from: 10.0, through: 6.0, by: -0.5)), id: \.self) { value in
                Button {
                    set.recordRPE(value)
                    viewModel.noteSetEntryTool(.effortChip)
                    viewModel.persistChanges()
                } label: {
                    if set.rpe == value {
                        Label("RPE \(Formatters.formatFloat(Float(value))) · \(RPEScale.meaning(for: value))", systemImage: AppIcon.checkmark)
                    } else {
                        Text("RPE \(Formatters.formatFloat(Float(value))) · \(RPEScale.meaning(for: value))")
                    }
                }
            }
        }
    }

    private func effortChipTitle(set: ExerciseSet) -> String {
        if let rir = set.rir {
            return "RIR \(rir)"
        }
        if let rpe = set.rpe {
            return "RPE \(Formatters.formatFloat(Float(rpe)))"
        }
        return String(localized: "Effort")
    }

    private func effortAccessibilityLabel(set: ExerciseSet) -> String {
        if let rir = set.rir {
            return "Effort, RIR \(rir), \(RIRScale.meaning(for: rir))"
        }
        if let rpe = set.rpe {
            return "Effort, RPE \(Formatters.formatFloat(Float(rpe))), \(RPEScale.meaning(for: rpe))"
        }
        return "Effort, not recorded"
    }

    private func chip(
        title: LocalizedStringKey,
        systemImage: String,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            chipLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(identifier ?? "panel-chip-\(systemImage)")
    }

    /// A chip whose title is composed at runtime — the plate stack, which is a
    /// number and cannot be a localisation key.
    ///
    /// `isProminent` is state, not decoration: it marks the one chip that is
    /// worth looking at right now. Nothing else in the row ever sets it, so it
    /// can only ever mean one thing.
    private func chip(
        title: String,
        systemImage: String,
        identifier: String? = nil,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(verbatim: title)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(AppFont.footnoteMedium)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(isProminent ? Color.gymPrimary : Color.gymText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(isProminent ? Color.gymPrimarySurface : Color.gymRowSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(
                    isProminent ? Color.gymPrimary.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(identifier ?? "panel-chip-\(systemImage)")
    }

    // MARK: - Plate chip

    /// The per-side stack, printed on the chip.
    ///
    /// Falls back to the bare word when the target is unreachable — below the
    /// bar, or not divisible by the plates on hand — because a partial stack
    /// shown as if it were complete is worse than no shortcut at all. The sheet
    /// explains those cases properly.
    private func plateChipTitle(exercise: ExerciseEntry, set: ExerciseSet) -> String {
        guard let calculation = plateCalculation(exercise: exercise, set: set),
              !calculation.plates.isEmpty,
              calculation.remainingWeight <= 0.001
        else {
            return String(localized: "Plates")
        }
        let stack = calculation.plates
            .map { Formatters.formatFloat($0) }
            .joined(separator: "·")
        return stack
    }

    /// Whether the bar has to be re-loaded before this set — the only moment
    /// the calculator is worth a glance.
    private func needsPlateChange(exercise: ExerciseEntry, set: ExerciseSet) -> Bool {
        guard set.weight > 0 else { return false }
        guard let lastCompleted = exercise.orderedSets
            .filter({ $0.done && $0.persistentModelID != set.persistentModelID })
            .last
        else {
            // Nothing logged yet on this exercise, so the bar is not yet
            // loaded for it.
            return true
        }
        let previous = UnitConversion.weight(
            lastCompleted.weight,
            from: lastCompleted.weightType,
            to: set.weightType
        )
        return abs(previous - set.weight) > 0.001
    }

    private func plateCalculation(exercise: ExerciseEntry, set: ExerciseSet) -> PlateCalculation? {
        guard set.weight > 0 else { return nil }
        let equipment = PlateEquipment(
            unitSystem: set.weightType == .kg ? .metric : .imperial,
            selectedBarID: BarKind.mensOlympic.id,
            usesBarbell: exercise.exercise.equipmentType == .barbell
        )
        let calculation = PlateCalculation(
            target: set.weight,
            barWeight: equipment.barWeight,
            plates: equipment.plates
        )
        return calculation
    }

    private func chipLabel(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color? = nil
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.footnoteMedium)
            .foregroundStyle(tint ?? Color.gymText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(tint.map { $0.opacity(0.12) } ?? Color.gymRowSurface)
            .clipShape(Capsule())
            // A border only where there is a tint to explain it — a recorded
            // effort value, a marked set type. "Normal", "Plates", "Details"
            // and an unrecorded effort chip are not states, and a grey outline
            // on all four made every chip look selectable-but-unselected
            // rather than letting the fill alone say "this is a control".
            .overlay {
                if let tint {
                    Capsule().stroke(tint.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
    }

    func chipLabel(
        title: String,
        systemImage: String,
        tint: Color? = nil
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.footnoteMedium)
            .foregroundStyle(tint ?? Color.gymText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(tint.map { $0.opacity(0.12) } ?? Color.gymRowSurface)
            .clipShape(Capsule())
            // A border only where there is a tint to explain it — a recorded
            // effort value, a marked set type. "Normal", "Plates", "Details"
            // and an unrecorded effort chip are not states, and a grey outline
            // on all four made every chip look selectable-but-unselected
            // rather than letting the fill alone say "this is a control".
            .overlay {
                if let tint {
                    Capsule().stroke(tint.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
    }
}

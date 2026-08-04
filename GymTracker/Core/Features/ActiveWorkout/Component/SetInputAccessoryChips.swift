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
                    chip(title: "Plates", systemImage: AppIcon.plateCalculator, identifier: "panel-chip-plates") {
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
            .overlay { Capsule().stroke(tint.map { $0.opacity(0.3) } ?? Color.gymBorder, lineWidth: 1) }
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
            .overlay { Capsule().stroke(tint.map { $0.opacity(0.3) } ?? Color.gymBorder, lineWidth: 1) }
            .contentShape(Capsule())
    }
}

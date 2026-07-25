import SwiftUI
import SwiftData

/// The set-entry panel that sits between the workout list and the custom
/// keypad while a value is being edited.
///
/// It replaces the old keyboard toolbar, which could only offer previous/next/
/// copy/done. Keeping every value of the set on screen at once — plus the
/// increments and per-set actions that used to hide in the row's `...` menu —
/// means an exercise can be logged without the keypad ever dismissing.
struct SetInputAccessoryPanel: View {
    let viewModel: ActiveWorkoutViewModel
    let coordinator: SetInputCoordinator
    let unitSystem: UnitSystem
    /// Invoked after a set is completed so the owner can start rest and advance
    /// the disclosure, exactly as the row's own completion button does.
    let onSetCompleted: (ExerciseEntry) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @AppStorage(DefaultsKey.effortMeasure) private var effortMeasure: EffortMeasure = .rir
    @State private var isShowingPlateCalculator = false
    @State private var isShowingSetDetails = false
    @State private var validationMessage: String?
    @State private var weightStepSelection: WeightStepSelection = .equipment

    private enum WeightStepSelection {
        case fine
        case equipment
    }

    private var models: (exercise: ExerciseEntry, set: ExerciseSet)? {
        viewModel.models(for: coordinator.focus)
    }

    private var focusedField: SetInputFocus.Field {
        coordinator.focus?.field ?? .repetitions
    }

    private var decimalSeparator: String {
        locale.decimalSeparator ?? "."
    }

    /// Seconds and calories are whole numbers; a decimal key there only
    /// produces values the model rounds away.
    private func fieldAllowsDecimals(_ field: SetInputFocus.Field) -> Bool {
        switch field {
        case .repetitions, .weight, .distance: true
        case .duration, .calories: false
        }
    }

    private func handle(_ key: KeypadKey, field: SetInputFocus.Field, set: ExerciseSet) {
        guard let text = coordinator.applyKey(key, decimalSeparator: decimalSeparator) else { return }
        viewModel.commitTypedValue(text, field: field, in: set)
        validationMessage = nil
    }

    var body: some View {
        if let models {
            content(exercise: models.exercise, set: models.set)
        }
    }

    private func content(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        VStack(spacing: Spacing.m) {
            contextHeader(exercise: exercise, set: set)

            valueRow(exercise: exercise, set: set)

            if let validationMessage {
                Text(validationMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(validationMessage)
            }

            chipRow(exercise: exercise, set: set)

            footer(exercise: exercise, set: set)

            // The keypad is part of this panel rather than a text field's
            // `inputView`. Nothing here is a first responder, so no system
            // keyboard is raised and no keyboard-avoidance inset competes with
            // the panel's own height.
            NumericKeypad(
                decimalSeparator: decimalSeparator,
                showsDecimalKey: fieldAllowsDecimals(focusedField)
            ) { key in
                handle(key, field: focusedField, set: set)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.m)
        .background(Color.gymCard)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: Radius.card,
            topTrailingRadius: Radius.card,
            style: .continuous
        ))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gymBorder)
                .frame(height: 1)
        }
        .shadow(color: Color.gymText.opacity(0.03), radius: 6, y: -2)
        .animation(reduceMotion ? nil : AppMotion.compact, value: coordinator.focus)
        .onChange(of: coordinator.focus) { _, _ in validationMessage = nil }
        .sheet(isPresented: $isShowingPlateCalculator, onDismiss: {
            viewModel.persistChanges()
        }) {
            PlateCalculatorView(
                exerciseSet: set,
                usesBarbell: exercise.exercise.equipmentType == .barbell
            )
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(560), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSetDetails, onDismiss: {
            viewModel.persistChanges()
        }) {
            SetDetailSheet(
                index: setPosition(of: set, in: exercise),
                exerciseSet: set,
                exerciseName: exercise.exercise.name,
                onPersist: { viewModel.persistChanges() },
                onDelete: {
                    viewModel.removeSet(exercise, set)
                    coordinator.focus = nil
                }
            )
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(480), .large])
            .presentationDragIndicator(.visible)
        }
        // Declared a container so the panel keeps one addressable identifier for
        // state assertions without stamping it over every control inside it —
        // an identifier on a plain container replaces its children's own.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("set-input-panel")
    }

    // MARK: - Context

    /// Grounds the floating panel: which set of which exercise is being
    /// edited, its logging semantics, and — when a prescription exists — the
    /// target it is asking for. The row this panel edits can be scrolled away,
    /// so the panel must identify its subject on its own. Set-to-set navigation
    /// lives in this same header rather than a separate row so the panel keeps
    /// as much of the screen free for the workout history above it as possible.
    private func contextHeader(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(exerciseIdentityText(exercise: exercise))
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.gymSubtleText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    coordinator.focus = nil
                } label: {
                    Image(systemName: AppIcon.minimize)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(width: 36, height: 36)
                        .background(Color.gymRowSurface, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.gymPress)
                .accessibilityLabel("Hide keypad")
                .accessibilityIdentifier("panel-dismiss")
            }

            HStack(spacing: Spacing.s) {
                navigationButton(systemImage: AppIcon.chevronLeft, offset: -1)

                VStack(spacing: Spacing.xxs) {
                    Text(setPositionText(exercise: exercise, set: set))
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                        .lineLimit(1)

                    if let target = prescribedTargetText(exercise: exercise, set: set) {
                        Text(target)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(setPositionText(exercise: exercise, set: set))

                navigationButton(systemImage: AppIcon.chevronRight, offset: 1)
            }
        }
    }

    private func setPosition(of set: ExerciseSet, in exercise: ExerciseEntry) -> Int {
        exercise.orderedSets.firstIndex(where: { $0.persistentModelID == set.persistentModelID }) ?? 0
    }

    private func exerciseIdentityText(exercise: ExerciseEntry) -> String {
        var parts = [exercise.exercise.name]
        let semantics = exercise.loggingSemanticsSnapshot
        if semantics.laterality == .unilateral && semantics.repCountingStyle == .perSide {
            parts.append(String(localized: "per side"))
        }
        return parts.joined(separator: " · ")
    }

    private func setPositionText(exercise: ExerciseEntry, set: ExerciseSet) -> String {
        let position = setPosition(of: set, in: exercise) + 1
        return String(localized: "Set \(position) of \(exercise.orderedSets.count)")
    }

    private func prescribedTargetText(exercise: ExerciseEntry, set: ExerciseSet) -> String? {
        var parts: [String] = []
        let usesDuration = exercise.trackingTypeSnapshot.usesDuration

        if let minimum = set.prescribedRepRangeMinimum,
           let maximum = set.prescribedRepRangeMaximum,
           minimum != maximum {
            parts.append(usesDuration
                ? String(localized: "\(minimum)–\(maximum) sec")
                : String(localized: "\(minimum)–\(maximum) reps"))
        } else if let count = set.prescribedRepetitions
            ?? set.prescribedRepRangeMinimum
            ?? set.prescribedRepRangeMaximum {
            parts.append(usesDuration
                ? String(localized: "\(count) sec")
                : String(localized: "\(count) reps"))
        }

        if let rpe = set.prescribedRPE {
            parts.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        } else if let rir = set.prescribedRIR {
            parts.append("RIR \(rir)")
        }

        if let load = set.prescribedSuggestedLoad, let type = set.prescribedSuggestedLoadType {
            let converted = UnitConversion.weight(Float(load), from: type, to: set.weightType)
            parts.append("\(Formatters.formatFloat(converted)) \(set.weightType.rawValue)")
        }

        guard !parts.isEmpty else { return nil }
        return String(localized: "Target \(parts.joined(separator: " · "))")
    }

    // MARK: - Values

    private func valueRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        let fields = SetInputCoordinator.inputFields(for: exercise.trackingTypeSnapshot)

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.m) {
                ForEach(fields, id: \.self) { field in
                    valuePill(field: field, exercise: exercise, set: set)
                }
            }
            VStack(spacing: Spacing.s) {
                ForEach(fields, id: \.self) { field in
                    valuePill(field: field, exercise: exercise, set: set)
                }
            }
        }
    }

    /// Label above, value centered between a symmetric minus/plus pair below —
    /// weight adds its step-size control (a single caption when there is only
    /// one sensible increment, a menu when fine vs. equipment steps differ) as
    /// a third line so the primary controls stay identical across fields.
    private func valuePill(
        field: SetInputFocus.Field,
        exercise: ExerciseEntry,
        set: ExerciseSet
    ) -> some View {
        let isActive = coordinator.focus?.field == field
        let isWeight = field == .weight
        let fine = isWeight ? fineWeightStep(for: set) : 0
        let coarse = isWeight ? coarseWeightStep(for: exercise, set: set) : 0
        let selectedStep = isWeight ? (weightStepSelection == .fine ? fine : coarse) : 1
        let longPressStep: Double? = field == .repetitions ? 5 : nil

        return VStack(spacing: Spacing.xs) {
            Text(fieldCaption(field))
                .font(AppFont.caption2Bold)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.gymSubtleText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.s) {
                stepperButton(
                    systemImage: AppIcon.minus,
                    step: -selectedStep,
                    longPressStep: longPressStep.map { -$0 },
                    field: field,
                    set: set,
                    controlSize: ComponentSize.minimumTouchTarget
                )

                valueButton(field: field, isActive: isActive, exercise: exercise, set: set)
                    .frame(maxWidth: .infinity)

                stepperButton(
                    systemImage: AppIcon.plus,
                    step: selectedStep,
                    longPressStep: longPressStep,
                    field: field,
                    set: set,
                    controlSize: ComponentSize.minimumTouchTarget
                )
            }

            if isWeight {
                if abs(fine - coarse) > 0.001 {
                    weightStepMenu(fine: fine, equipment: coarse, selectedStep: selectedStep, set: set)
                } else {
                    Text("Step: \(Formatters.formatFloat(Float(selectedStep))) \(set.weightType.rawValue)")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func fieldCaption(_ field: SetInputFocus.Field) -> String {
        switch field {
        case .repetitions: String(localized: "Reps")
        case .weight: String(localized: "Weight")
        case .duration: String(localized: "Duration")
        case .distance: String(localized: "Distance")
        case .calories: String(localized: "Calories")
        }
    }

    private func valueButton(
        field: SetInputFocus.Field,
        isActive: Bool,
        exercise: ExerciseEntry,
        set: ExerciseSet
    ) -> some View {
        // While this field is the one being typed into, show the keys pressed so
        // far — including a lone "0," that is not yet a number — instead of the
        // stored value the entry will replace.
        let shown = isActive
            ? coordinator.entryText ?? displayValue(field: field, set: set)
            : displayValue(field: field, set: set)

        return HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Button {
                coordinator.focusField(field)
            } label: {
                Text(shown.isEmpty ? "—" : shown)
                    .font(AppFont.titleSmallSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityValue(shown.isEmpty ? "—" : shown)
            .accessibilityLabel("\(fieldName(field)) \(unitLabel(field: field, exercise: exercise, set: set))")
            .accessibilityHint(isActive ? "Currently editing" : "Edit \(fieldName(field))")
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
            .accessibilityIdentifier("panel-value-\(fieldName(field))")

            if field == .weight {
                // Folded in from what used to be a standalone KG/LB chip —
                // the unit lives with the value it describes.
                Button {
                    toggleWeightType(on: set)
                } label: {
                    Text(unitLabel(field: field, exercise: exercise, set: set))
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymPrimary)
                        .underline()
                        .lineLimit(1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityLabel("Unit, \(set.weightType == .kg ? "kilograms" : "pounds")")
                .accessibilityHint("Switches to \(set.weightType == .kg ? "pounds" : "kilograms")")
                .accessibilityIdentifier("panel-weight-unit-toggle")
            } else {
                // Distance spells out its unit ("kilometers", "miles"),
                // unlike the two-letter "kg"/"sec"/"cal" this pill was sized
                // for, so it needs to shrink rather than wrap onto a second
                // line inside a fixed-width pill.
                Text(unitLabel(field: field, exercise: exercise, set: set))
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, Spacing.s)
        .background(isActive ? Color.gymPrimarySurface : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(
                    isActive ? Color.gymPrimary : Color.gymBorder,
                    lineWidth: isActive ? 1.5 : 1
                )
        }
    }

    private func weightStepMenu(
        fine: Double,
        equipment: Double,
        selectedStep: Double,
        set: ExerciseSet
    ) -> some View {
        Menu {
            weightStepOption(.fine, step: fine, set: set)
            weightStepOption(.equipment, step: equipment, set: set)
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text("Step: \(Formatters.formatFloat(Float(selectedStep))) \(set.weightType.rawValue)")
                    .font(AppFont.caption)
                Image(systemName: AppIcon.picker)
                    .font(AppFont.caption2Bold)
            }
            .foregroundStyle(Color.gymPrimary)
            .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Weight adjustment increment")
        .accessibilityValue("\(Formatters.formatFloat(Float(selectedStep))) \(set.weightType.rawValue)")
        .accessibilityHint("Choose how much the minus and plus buttons change the weight")
        .accessibilityIdentifier("panel-weight-step")
    }

    private func weightStepOption(
        _ selection: WeightStepSelection,
        step: Double,
        set: ExerciseSet
    ) -> some View {
        Button {
            weightStepSelection = selection
        } label: {
            if weightStepSelection == selection {
                Label(
                    "\(Formatters.formatFloat(Float(step))) \(set.weightType.rawValue)",
                    systemImage: AppIcon.checkmark
                )
            } else {
                Text("\(Formatters.formatFloat(Float(step))) \(set.weightType.rawValue)")
            }
        }
        .accessibilityIdentifier(
            selection == .fine ? "panel-weight-step-fine" : "panel-weight-step-equipment"
        )
    }

    private func stepperButton(
        systemImage: String,
        step: Double,
        longPressStep: Double?,
        field: SetInputFocus.Field,
        set: ExerciseSet,
        controlSize: CGFloat
    ) -> some View {
        StepperButton(
            label: Image(systemName: systemImage)
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymPrimary)
                .frame(width: controlSize, height: controlSize)
                .background(Color.gymPrimary.opacity(0.12), in: Circle())
                .contentShape(Circle()),
            accessibilityLabel: step < 0
                ? "Decrease \(fieldName(field)) by \(Formatters.formatFloat(Float(abs(step))))"
                : "Increase \(fieldName(field)) by \(Formatters.formatFloat(Float(step)))",
            longPressAccessibilityLabel: longPressStep.map { jump in
                jump < 0
                    ? "Jump \(fieldName(field)) down by \(Formatters.formatFloat(Float(abs(jump))))"
                    : "Jump \(fieldName(field)) up by \(Formatters.formatFloat(Float(jump)))"
            },
            onTap: { adjust(field: field, by: step, set: set) },
            onLongPress: longPressStep.map { jump in { adjust(field: field, by: jump, set: set) } }
        )
    }

    // MARK: - Chips

    private func chipRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                setTypeChip(set: set)

                effortChip(set: set)

                if exercise.exercise.supportsPlateCalculator {
                    chip(title: "Plates", systemImage: AppIcon.plateCalculator, identifier: "panel-chip-plates") {
                        isShowingPlateCalculator = true
                    }
                }

                if viewModel.canCopyValuesForFocusedSet(coordinator.focus) {
                    chip(title: "Last set", systemImage: AppIcon.copy, identifier: "panel-chip-last set") {
                        viewModel.copyValuesForFocusedSet(coordinator.focus)
                    }
                }

                chip(title: "Details", systemImage: AppIcon.advanced, identifier: "panel-details") {
                    isShowingSetDetails = true
                }
                .accessibilityHint("Tempo, set method, velocity, and other options")
            }
            .padding(.horizontal, Spacing.xxs)
        }
        .scrollIndicators(.hidden)
    }

    private func setTypeChip(set: ExerciseSet) -> some View {
        Menu {
            Picker("Set type", selection: Binding(
                get: { set.setType },
                set: {
                    set.setType = $0
                    viewModel.persistChanges()
                }
            )) {
                ForEach(SetType.allCases, id: \.self) { type in
                    Label(type.title, systemImage: type.icon).tag(type)
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

    /// Quick effort logging without leaving the keypad: the chip shows the
    /// recorded value and offers the active measure's scale inline. The full
    /// sliders (and measure switching) stay in the Set details sheet.
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
            .frame(minHeight: 36)
            .background(tint.map { $0.opacity(0.12) } ?? Color.gymRowSurface)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(tint.map { $0.opacity(0.3) } ?? Color.gymBorder, lineWidth: 1) }
            .contentShape(Capsule())
    }

    private func chipLabel(
        title: String,
        systemImage: String,
        tint: Color? = nil
    ) -> some View {
        chipLabel(title: LocalizedStringKey(title), systemImage: systemImage, tint: tint)
    }

    // MARK: - Footer

    private func footer(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        Button {
            confirm(exercise: exercise, set: set)
        } label: {
            Label("Complete set", systemImage: AppIcon.checkmark)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Color.gymSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel("Complete set")
        .accessibilityHint("Marks this set done, starts rest, and moves to the next set.")
        .accessibilityIdentifier("panel-complete-set")
    }

    private func navigationButton(systemImage: String, offset: Int) -> some View {
        let isEnabled = offset < 0 ? coordinator.previousInput != nil : coordinator.nextInput != nil

        return Button {
            coordinator.moveFocus(by: offset)
        } label: {
            Image(systemName: systemImage)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(isEnabled ? Color.gymPrimary : Color.gymSubtleText)
                .frame(width: 44, height: 44)
                .background(Color.gymRowSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.gymPress)
        .disabled(!isEnabled)
        .accessibilityLabel(offset < 0 ? "Previous field" : "Next field")
    }

    // MARK: - Actions

    private func confirm(exercise: ExerciseEntry, set: ExerciseSet) {
        switch viewModel.completeSet(set, in: exercise) {
        case .blocked(let message, let focus):
            validationMessage = message
            coordinator.focus = focus
        case .completed(let nextFocus):
            validationMessage = nil
            onSetCompleted(exercise)
            coordinator.refreshOrder(in: viewModel.activeWorkout)
            coordinator.focus = nextFocus
        case .reopened, .failed:
            break
        }
    }

    private func adjust(field: SetInputFocus.Field, by step: Double, set: ExerciseSet) {
        switch field {
        case .repetitions:
            set.repetitions = max(0, set.repetitions + Float(step))
        case .weight:
            set.weight = max(0, set.weight + Float(step))
        case .duration:
            set.duration = max(0, (set.duration ?? 0) + step)
        case .distance:
            set.distance = max(0, (set.distance ?? 0) + Float(step))
        case .calories:
            set.calories = max(0, (set.calories ?? 0) + step)
        }
        validationMessage = nil
        viewModel.persistChanges()
    }

    private func toggleWeightType(on set: ExerciseSet) {
        let target: WeightType = set.weightType == .kg ? .lbs : .kg
        set.weight = UnitConversion.weight(set.weight, from: set.weightType, to: target)
        set.weightType = target
        viewModel.persistChanges()
    }

    // MARK: - Steps

    /// The smallest sensible nudge — a microplate in metric, the smallest common
    /// fractional plate in imperial.
    private func fineWeightStep(for set: ExerciseSet) -> Double {
        set.weightType == .kg ? 1 : 2.5
    }

    /// The jump this equipment actually makes: plate pairs for a barbell, rack
    /// steps for dumbbells, pin steps for a stack.
    private func coarseWeightStep(for exercise: ExerciseEntry, set: ExerciseSet) -> Double {
        let template = exercise.exercise
        if let increment = EquipmentLoadRounding.increment(
            equipment: template.equipmentType,
            resistance: template.resistanceType,
            isPlateLoaded: template.isPlateLoaded,
            unit: set.weightType
        ) {
            return increment
        }
        return Double(Constants.Progression.increment(for: set.weightType))
    }

    // MARK: - Formatting

    private func displayValue(field: SetInputFocus.Field, set: ExerciseSet) -> String {
        switch field {
        case .repetitions:
            return set.repetitions == 0 ? "—" : Formatters.formatFloat(set.repetitions)
        case .weight:
            return set.weight == 0 ? "—" : Formatters.formatFloat(set.weight)
        case .duration:
            return (set.duration ?? 0) == 0 ? "—" : String(Int(set.duration ?? 0))
        case .distance:
            return (set.distance ?? 0) == 0 ? "—" : Formatters.formatFloat(set.distance ?? 0)
        case .calories:
            return (set.calories ?? 0) == 0 ? "—" : Formatters.formatFloat(Float(set.calories ?? 0))
        }
    }

    private func unitLabel(field: SetInputFocus.Field, exercise: ExerciseEntry, set: ExerciseSet) -> String {
        switch field {
        case .repetitions:
            return "rep"
        case .weight:
            // Per-load-unit exercises (a pair of dumbbells, one per hand) log
            // the weight of each unit, so the unit label carries that meaning.
            if exercise.loggingSemanticsSnapshot.weightEntryStyle == .perLoadUnit {
                return String(localized: "\(set.weightType.rawValue) each")
            }
            return set.weightType.rawValue
        case .duration:
            return "sec"
        case .distance:
            return set.distanceType.rawValue
        case .calories:
            return "cal"
        }
    }

    private func fieldName(_ field: SetInputFocus.Field) -> String {
        switch field {
        case .repetitions: return "reps"
        case .weight: return "weight"
        case .duration: return "duration"
        case .distance: return "distance"
        case .calories: return "calories"
        }
    }
}

/// A stepper control that answers a tap with `onTap` and, when `onLongPress`
/// is supplied, a hold past 0.45s with `onLongPress` instead — one button
/// standing in for what would otherwise be two stacked stepper rows.
///
/// Built on `Button` rather than a raw gesture so VoiceOver's double-tap
/// activation, the `.gymPress` visual feedback, and standard hit-testing all
/// keep working unmodified; the long press is layered on top as a
/// `simultaneousGesture` with a one-shot flag that swallows the tap action
/// it would otherwise also trigger on release, and exposed to VoiceOver as a
/// named accessibility action since holding is impractical there.
private struct StepperButton<Label: View>: View {
    let label: Label
    let accessibilityLabel: String
    let longPressAccessibilityLabel: String?
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    @State private var didLongPress = false

    var body: some View {
        if let onLongPress {
            button
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in
                            didLongPress = true
                            onLongPress()
                        }
                )
                .accessibilityAction(named: Text(longPressAccessibilityLabel ?? accessibilityLabel)) {
                    onLongPress()
                }
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            if didLongPress {
                didLongPress = false
                return
            }
            onTap()
        } label: {
            label
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(accessibilityLabel)
    }
}

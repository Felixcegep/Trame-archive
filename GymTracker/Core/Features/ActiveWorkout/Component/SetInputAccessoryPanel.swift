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
    /// Invoked after the transactional completion has committed so the owner
    /// can advance disclosure. Rest presentation is already reconciled by the
    /// view model from the post-commit receipt.
    let onSetCompleted: (ExerciseEntry) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @AppStorage(DefaultsKey.effortMeasure) var effortMeasure: EffortMeasure = .rir
    @AppStorage(DefaultsKey.recentSetTypes) var recentSetTypesRaw: String = ""
    @State var isShowingPlateCalculator = false
    @State var isShowingSetDetails = false
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
        // The panel competes with the set list for the same screen. Every block
        // here is load-bearing, so the height comes out of the gaps between them
        // and out of the keypad rather than out of any control.
        Group {
            if isShowingSetDetails {
                // The details sheet is presented from this safe-area inset.
                // Keep the presenting view alive for the sheet, but remove
                // the keypad itself so it cannot cover the sheet's lower
                // controls.
                Color.clear.frame(height: 0)
            } else {
                VStack(spacing: Spacing.s) {
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

                    // The keypad is part of this panel rather than a text
                    // field's `inputView`. Nothing here is a first responder,
                    // so no system keyboard is raised and no keyboard-
                    // avoidance inset competes with the panel's own height.
                    NumericKeypad(
                        decimalSeparator: decimalSeparator,
                        showsDecimalKey: fieldAllowsDecimals(focusedField)
                    ) { key in
                        handle(key, field: focusedField, set: set)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.s)
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
        // Both sheets can write the value the panel is displaying, so the typed
        // text has to be dropped when they close for the same reason a stepper
        // press drops it. The plate calculator only writes load; Set details can
        // write any of them.
        .sheet(isPresented: $isShowingPlateCalculator, onDismiss: {
            coordinator.endEntry(ifEditing: .weight)
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
            coordinator.endEntry()
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
            // The accessory keypad remains a safe-area inset while this sheet
            // is presented. A medium detent would leave that keypad over the
            // lower set-type choices, making the details sheet appear open but
            // not interactable. Details is already a dense editing surface;
            // present it full-screen so every option remains reachable.
            .presentationDetents([.large])
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
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    viewModel.flushPendingTypedInputSave()
                    coordinator.focus = nil
                } label: {
                    Image(systemName: AppIcon.minimize)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
                        .background(Color.gymRowSurface, in: Circle())
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
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

                    // What the plan asks for, and what the lifter actually did
                    // here last time — the two numbers a set is measured
                    // against, on the one surface guaranteed to stay visible.
                    //
                    // With the keypad raised the panel owns most of the screen
                    // and the set table is clipped to a couple of rows, so every
                    // affordance carrying previous performance — the card-level
                    // summary, the field placeholder, the "use last time" button
                    // — is off screen at exactly the moment the number is being
                    // typed. The target already lived here; its counterpart did
                    // not, and the data was already loaded one view model away.
                    if let reference = referenceText(exercise: exercise, set: set) {
                        Text(reference)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(referenceAccessibilityLabel(exercise: exercise, set: set))

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
            let converted = WorkoutLoadRounding.converted(
                Float(load),
                from: type,
                to: set.weightType,
                for: exercise.exercise
            )
            parts.append("\(Formatters.formatFloat(converted)) \(set.weightType.rawValue)")
        }

        guard !parts.isEmpty else { return nil }
        return String(localized: "Target \(parts.joined(separator: " · "))")
    }

    /// The prescription, what was lifted here last time, or both.
    ///
    /// One line rather than two: the panel's whole justification is leaving the
    /// workout above it as much room as possible, and a lifter comparing a
    /// target against last time is comparing two numbers, not reading two
    /// sentences. Either half may be absent — a free workout has no target, a
    /// first-ever session has no history — and the line simply carries whatever
    /// is true.
    private func referenceText(exercise: ExerciseEntry, set: ExerciseSet) -> String? {
        let parts = [
            prescribedTargetText(exercise: exercise, set: set),
            previousSetText(exercise: exercise, set: set)
        ].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  ·  ")
    }

    /// What this same set index produced in the last session that recorded one.
    ///
    /// Deliberately reuses the set's *current* unit via `UnitConversion` rather
    /// than the historical one: the number exists to be compared against what
    /// the lifter is about to type, and a comparison across units is not one.
    private func previousSetText(exercise: ExerciseEntry, set: ExerciseSet) -> String? {
        let index = setPosition(of: set, in: exercise)
        guard let previous = viewModel.previousPerformance(for: exercise)?.set(at: index) else {
            return nil
        }

        let tracking = exercise.trackingTypeSnapshot
        if tracking.usesWeight {
            let weight = UnitConversion.weight(
                previous.weight,
                from: previous.weightType,
                to: set.weightType
            )
            return String(localized: "Last \(Formatters.formatFloat(previous.repetitions)) × \(Formatters.formatFloat(weight)) \(set.weightType.rawValue)")
        }
        if tracking.usesDuration, let duration = previous.duration {
            return String(localized: "Last \(Int(duration)) sec")
        }
        if tracking.usesReps {
            return String(localized: "Last \(Formatters.formatFloat(previous.repetitions)) reps")
        }
        return nil
    }

    /// Spoken as one sentence, so the set position and the two numbers it is
    /// measured against are a single VoiceOver stop rather than three.
    private func referenceAccessibilityLabel(exercise: ExerciseEntry, set: ExerciseSet) -> String {
        let position = setPositionText(exercise: exercise, set: set)
        guard let reference = referenceText(exercise: exercise, set: set) else { return position }
        return "\(position). \(reference)"
    }

    // MARK: - Values

    /// Side by side for the usual reps-and-weight pair, stacked only when the
    /// layout genuinely cannot work.
    ///
    /// This deliberately does **not** use `ViewThatFits`. That measures the
    /// pill's ideal width, so a merely long value — "225.97 lbs" — made the
    /// whole panel jump to the stacked layout and every control moved. The
    /// value is already free to shrink; a wide number should cost a point of
    /// type size, never a change of layout mid-set.
    private func valueRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        let fields = SetInputCoordinator.inputFields(for: exercise.trackingTypeSnapshot)

        return Group {
            if usesStackedValues(fieldCount: fields.count) {
                VStack(spacing: Spacing.s) {
                    ForEach(fields, id: \.self) { field in
                        valuePill(field: field, exercise: exercise, set: set)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.s) {
                    ForEach(fields, id: \.self) { field in
                        valuePill(field: field, exercise: exercise, set: set)
                    }
                }
            }
        }
    }

    /// Two columns hold a 44-point stepper on each side of the value, so a third
    /// field leaves nothing for the number itself. Accessibility text sizes get
    /// the stacked layout for the reason `Documentation/Accessibility.md` gives:
    /// at those sizes a vertical layout beats shrinking text.
    private func usesStackedValues(fieldCount: Int) -> Bool {
        dynamicTypeSize.isAccessibilitySize || fieldCount > 2
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
                .font(AppFont.captionBold)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.gymSubduedText)
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

            // Only while weight is the field being typed into. It is a
            // 44-point row that answers a question — "how much does ± move?" —
            // which nobody is asking while they are entering reps, and it costs
            // a set row of the list to keep on screen the rest of the time. The
            // chosen step still applies to the ± buttons when the field is not
            // focused; this hides the control, not the behaviour.
            if isWeight, isActive {
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

    /// The same step the ± buttons apply, so the adjustable action and the
    /// visible controls can never disagree.
    private func adjustmentStep(
        for field: SetInputFocus.Field,
        exercise: ExerciseEntry,
        set: ExerciseSet
    ) -> Double {
        guard field == .weight else { return 1 }
        return weightStepSelection == .fine
            ? fineWeightStep(for: set)
            : coarseWeightStep(for: exercise, set: set)
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
                viewModel.flushPendingTypedInputSave()
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
            // Swipe up/down adjusts by the same step the ± buttons use. Those
            // buttons are reachable individually, but a VoiceOver user had to
            // leave the value, find the right one, and return for each press —
            // the idiom for a number is to adjust it in place.
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjust(field: field, by: adjustmentStep(for: field, exercise: exercise, set: set), set: set)
                case .decrement: adjust(field: field, by: -adjustmentStep(for: field, exercise: exercise, set: set), set: set)
                @unknown default: break
                }
            }
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
                        // Shrinks with the value beside it. "225.97" and "lbs"
                        // share one pill, and a fixed-size unit would push the
                        // number out rather than give way to it.
                        .minimumScaleFactor(0.6)
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
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        // Tight on purpose: the two 44-point steppers beside it are fixed, so
        // every point of pill padding comes straight out of the number.
        .padding(.horizontal, Spacing.xs)
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
            // Given the same capsule the other panel chips wear. As bare tinted
            // text beside a caption it read as a label, so the fact that the
            // step size could be changed at all was invisible.
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(Color.gymPrimary.opacity(0.12), in: Capsule())
            .overlay { Capsule().stroke(Color.gymPrimary.opacity(0.3), lineWidth: 1) }
            .contentShape(Capsule())
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
            viewModel.flushPendingTypedInputSave()
            coordinator.moveFocus(by: offset)
        } label: {
            Image(systemName: systemImage)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(isEnabled ? Color.gymPrimary : Color.gymSubduedText)
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
            let measurement = WorkoutDistancePolicy.displayMeasurement(
                for: set,
                system: UserDefaults.standard.unitSystem
            )
            let unit = measurement?.unit ?? WorkoutDistancePolicy.preferredDisplayUnit(
                forMeters: nil,
                system: UserDefaults.standard.unitSystem
            )
            WorkoutDistancePolicy.storeDisplayValue(
                max(0, (measurement?.value ?? 0) + Float(step)),
                displayUnit: unit,
                on: set
            )
        case .calories:
            set.calories = max(0, (set.calories ?? 0) + step)
        }
        // A stepper press ends the typing session for the field it moved.
        // Without this the pill keeps rendering the digits typed a moment ago
        // while the stored value moves underneath it, so the first ± after
        // typing looks like it did nothing at all.
        coordinator.endEntry(ifEditing: field)
        validationMessage = nil
        viewModel.persistChanges()
    }

    private func toggleWeightType(on set: ExerciseSet) {
        let target: WeightType = set.weightType == .kg ? .lbs : .kg
        set.weight = UnitConversion.weight(set.weight, from: set.weightType, to: target)
        set.weightType = target
        // The number itself changed under the conversion, so typed text is now
        // describing a value in the previous unit.
        coordinator.endEntry(ifEditing: .weight)
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
    ///
    /// Shared with the rounding applied at unit crossings, so a converted
    /// target and the ± buttons that move it can never sit on different grids.
    private func coarseWeightStep(for exercise: ExerciseEntry, set: ExerciseSet) -> Double {
        WorkoutLoadRounding.stepperIncrement(for: exercise.exercise, unit: set.weightType)
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
            guard let measurement = WorkoutDistancePolicy.displayMeasurement(
                for: set,
                system: UserDefaults.standard.unitSystem
            ), measurement.value > 0 else {
                return "—"
            }
            return Formatters.formatFloat(measurement.value)
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
            return WorkoutDistancePolicy.displayMeasurement(
                for: set,
                system: UserDefaults.standard.unitSystem
            )?.unit.symbol
                ?? WorkoutDistancePolicy.preferredDisplayUnit(
                    forMeters: nil,
                    system: UserDefaults.standard.unitSystem
                ).symbol
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

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
    @State private var weightStepSelection: WeightStepSelection = .equipment
    /// Set when the lifter asks for the digit pad on a duration field. Reset on
    /// every focus change, so the presets are always what a timed set opens
    /// with — the exception has to be asked for each time it is wanted.
    @State private var isTypingExactValue = false
    /// What the lifter actually put on the bar, in the order they put it there.
    /// `nil` means the weight arrived some other way and the stack is derived.
    @State private var plateComposition: PlateLoadComposition?
    @State private var plateCompositionSetID: PersistentIdentifier?
    /// The bar in use. Persisted across sessions because a lifter's gym has the
    /// bar it has — re-picking it on every set would be the annoyance, not the
    /// safeguard.
    @AppStorage(DefaultsKey.selectedBarKind) private var selectedBarID: String = BarKind.mensOlympic.id

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

    private func handleDuration(_ key: DurationKey, set: ExerciseSet) {
        switch key {
        case .preset(let seconds):
            setValue(seconds, field: .duration, set: set)
        case .adjust(let seconds):
            adjust(field: .duration, by: seconds, set: set)
        case .backspace:
            setValue(0, field: .duration, set: set)
        case .digits:
            isTypingExactValue = true
            // The presets write straight to the model, so any half-typed text
            // from an earlier digit session would now disagree with it.
            coordinator.endEntry(ifEditing: .duration)
        }
    }

    /// The hold this set was prescribed, in seconds.
    ///
    /// Falls back to the prescribed rep count, which is where a duration
    /// authored as a plain number lands — the same reading the target line
    /// above the keypad already takes for timed work.
    private func prescribedDuration(of set: ExerciseSet) -> TimeInterval? {
        set.prescribedDurationSecondsSnapshot
            ?? set.prescribedRepetitions.map(TimeInterval.init)
    }

    private func handle(_ key: KeypadKey, field: SetInputFocus.Field, set: ExerciseSet) {
        guard let text = coordinator.applyKey(key, decimalSeparator: decimalSeparator) else { return }
        viewModel.commitTypedValue(text, field: field, in: set)
        // Typing is the lifter answering the refusal; the message has served
        // its purpose the moment they act on it.
        coordinator.clearBlockedAttempt()
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

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        // The value block's own heading carries the tracking
                        // type where there is something to say about it — a
                        // held position, assistance, added load. It replaces
                        // "Current value" rather than joining it: the panel
                        // pays for every line out of the set list above, and
                        // two captions stacked over the same numbers is one
                        // caption too many.
                        Text(valueBlockCaption(exercise: exercise))
                            .font(AppFont.micro)
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.trameSubdued)
                            .accessibilityIdentifier("panel-value-caption")

                        valueRow(exercise: exercise, set: set)
                    }

                    if !isPlateKeypadShowing(exercise) {
                        referenceLandmarks(exercise: exercise, set: set)
                    }

                    if !isPlateKeypadShowing(exercise) {
                        quickValueRow(exercise: exercise, set: set)
                    }

                    componentReadiness(set: set)

                    validationBanner

                    // Contextual commands belong to the normal panel state.
                    // Once the first exact digit is typed, the value, keypad,
                    // reference, and value-only action are the entire task.
                    if coordinator.entryText == nil, !isPlateKeypadShowing(exercise) {
                        chipRow(exercise: exercise, set: set)
                    }

                    // The keypad is part of this panel rather than a text
                    // field's `inputView`. Nothing here is a first responder,
                    // so no system keyboard is raised and no keyboard-
                    // avoidance inset competes with the panel's own height.
                    //
                    // It yields its space when the thing blocking completion is
                    // the complex-component outcomes. At that moment the lifter
                    // is not typing a number — they are recording whether each
                    // lift was made — and a number pad is the one control that
                    // cannot help them. Swapping in place keeps the panel the
                    // same height and, more importantly, keeps the fix where
                    // they are already looking.
                    Group {
                    if isResolvingComponents(set) {
                        complexComponentResolver(set: set)
                    } else if focusedField == .weight,
                              exercise.trackingTypeSnapshot == .assistedBodyweight,
                              !isTypingExactValue {
                        AssistKeypad(
                            value: Double(set.weight),
                            unitLabel: set.weightType.rawValue,
                            maximum: assistMaximum(for: set),
                            step: assistStep(for: set),
                            onChange: { setValue($0, field: .weight, set: set) },
                            onAdjust: { adjust(field: .weight, by: $0, set: set) },
                            onDigits: {
                                isTypingExactValue = true
                                coordinator.endEntry(ifEditing: .weight)
                            }
                        )
                    } else if focusedField == .weight,
                              usesPerSidePlates(exercise),
                              !isTypingExactValue {
                        plateKeypad(exercise: exercise, set: set)
                    } else if focusedField == .duration, !isTypingExactValue {
                        DurationKeypad(
                            presets: DurationKeypad.presets(including: prescribedDuration(of: set))
                        ) { key in
                            handleDuration(key, set: set)
                        }
                    } else {
                        NumericKeypad(
                            decimalSeparator: decimalSeparator,
                            showsDecimalKey: fieldAllowsDecimals(focusedField)
                        ) { key in
                            handle(key, field: focusedField, set: set)
                        }
                    }
                    }
                    .frame(maxWidth: .infinity)

                    footer(exercise: exercise, set: set)
                        .layoutPriority(1)
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.s)
        // The fill reaches the physical bottom edge; the controls above it do
        // not. This panel is presented as a `.safeAreaInset`, which renders it
        // down into the home-indicator zone, but `Spacing.s` of bottom padding
        // is only 8pt against the ~34pt of that zone on a Face ID device. The
        // remaining ~26pt were never painted, so whatever sat under the panel
        // in the scrolling list — the next exercise card — showed through in a
        // strip along the bottom of the screen.
        //
        // `ignoresSafeArea` is on the background shape alone, not on the
        // content: the keypad and chips stay clear of the gesture area, only
        // the card's own colour extends past it.
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: Radius.card,
                topTrailingRadius: Radius.card,
                style: .continuous
            )
            .fill(Color.trameSurface)
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
        }
        .animation(reduceMotion ? nil : AppMotion.compact, value: coordinator.focus)
        // Moving to another field or another set puts the duration keypad back
        // to its presets. The digit pad is the exception, and an exception that
        // persists silently becomes the default nobody chose.
        .onChange(of: coordinator.focus) { _, _ in
            isTypingExactValue = false
        }
        // The refusal is cleared by the coordinator's own focus setter, so the
        // blocked path can set focus first and record the message second
        // without the two racing. Nothing to reset here.
        .gymFeedback(.validationBlocked, trigger: coordinator.blockedAttemptCount)
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
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Identity, position, and the three controls that act on them —
            // one line.
            //
            // This used to be two stacked rows: identity plus a dismiss
            // button, then a large centered "Set N of M" row with its own
            // prev/next controls. Collapsing them recovers the height that
            // pays for the reference chip below without growing the panel.
            HStack(spacing: Spacing.s) {
                // Identity and position read as one VoiceOver stop — a lifter
                // swiping through does not need "Bench Press" and "Set 1 of
                // 2" as two separate stops to understand either of them. The
                // three buttons that follow are deliberately siblings of this
                // element rather than children of it: combining would fold
                // them into the same spoken stop and make them untappable
                // under VoiceOver, which is the one thing a floating panel's
                // only route back to the workout list must never do.
                HStack(spacing: Spacing.xxs) {
                    Text(exercise.exercise.name)
                        .font(AppFont.captionBold)
                        .tracking(0.6)
                        .textCase(.uppercase)
                    Text("·")
                    Text(setPositionText(exercise: exercise, set: set))
                        .font(AppFont.caption)
                }
                .foregroundStyle(Color.trameSubdued)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                navigationButton(systemImage: AppIcon.chevronLeft, offset: -1)
                navigationButton(systemImage: AppIcon.chevronRight, offset: 1)

                // Kept alongside set navigation rather than dropped to match
                // the mockup literally: closing the keypad without completing
                // the set or scrolling past the panel has no other affordance
                // on screen, and the workout screen's own top chevron
                // dismisses the whole session, not just this panel.
                Button {
                    viewModel.flushPendingTypedInputSave()
                    coordinator.focus = nil
                } label: {
                    Image(systemName: AppIcon.minimize)
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(width: 26, height: 26)
                        .background(Color.trameRow, in: Circle())
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

        }
    }

    /// Target and prior performance sit immediately below the answer they
    /// qualify. This is the shared landmark position for every set instrument:
    /// the value leads, then the evidence used to choose it, then the control.
    @ViewBuilder
    private func referenceLandmarks(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        if let reference = referenceText(exercise: exercise, set: set) {
            Text(reference)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.s)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
                .accessibilityLabel(reference)
                .accessibilityIdentifier("panel-reference-landmarks")
        }
    }

    private func setPosition(of set: ExerciseSet, in exercise: ExerciseEntry) -> Int {
        exercise.orderedSets.firstIndex(where: { $0.persistentModelID == set.persistentModelID }) ?? 0
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
            Text(fieldCaption(field, exercise: exercise))
                .font(AppFont.captionBold)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.trameSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isWeight, isPlateKeypadShowing(exercise) {
                valueButton(field: field, isActive: isActive, exercise: exercise, set: set)
                    .frame(maxWidth: .infinity)
            } else {
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
            }

            if isWeight, isActive, !isPlateKeypadShowing(exercise) {
                weightUnitPicker(on: set)
            }

            // Only while weight is the field being typed into. It is a
            // 44-point row that answers a question — "how much does ± move?" —
            // which nobody is asking while they are entering reps, and it costs
            // a set row of the list to keep on screen the rest of the time. The
            // chosen step still applies to the ± buttons when the field is not
            // focused; this hides the control, not the behaviour.
            if isWeight, isActive, !isPlateKeypadShowing(exercise) {
                if abs(fine - coarse) > 0.001 {
                    weightStepMenu(fine: fine, equipment: coarse, selectedStep: selectedStep, set: set)
                } else {
                    Text("Step: \(Formatters.formatFloat(Float(selectedStep))) \(set.weightType.rawValue)")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
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

    /// The heading over the whole value block.
    ///
    /// Names the logging semantics when the tracking type has semantics worth
    /// naming, and otherwise says which numbers these are. A lifter arriving at
    /// an assisted or timed exercise reads the difference here, before the
    /// keypad underneath turns out not to be a digit pad.
    private func valueBlockCaption(exercise: ExerciseEntry) -> String {
        exercise.trackingTypeSnapshot.loggingOrientation
            ?? String(localized: "Current value")
    }

    /// The caption above a value.
    ///
    /// The weight field means three different things depending on how the
    /// exercise is resisted, and "Weight" is only correct for one of them. On an
    /// assisted movement the number is load being *taken off* the lifter, so a
    /// caption reading "Weight · 20 kg" says the opposite of what happened —
    /// more assistance looks like more work. Naming the field for what it holds
    /// is the whole fix.
    private func fieldCaption(_ field: SetInputFocus.Field, exercise: ExerciseEntry) -> String {
        switch field {
        case .repetitions: String(localized: "Reps")
        case .weight:
            switch exercise.trackingTypeSnapshot {
            case .assistedBodyweight: String(localized: "Assist")
            case .weightedBodyweight: String(localized: "Added")
            default: String(localized: "Weight")
            }
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
        let stored = displayValue(field: field, set: set)
        let input = SetInputFocus(
            exerciseID: exercise.persistentModelID,
            setID: set.persistentModelID,
            field: field
        )
        let shown = isActive
            ? coordinator.displayText(for: input, storedValue: stored)
            : stored

        return HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Button {
                viewModel.flushPendingTypedInputSave()
                coordinator.focusField(field)
            } label: {
                Text(shown.isEmpty ? "—" : shown)
                    .font(AppFont.metricLarge)
                    .foregroundStyle(Color.trameText)
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
                Text(unitLabel(field: field, exercise: exercise, set: set))
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSubdued)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                // Distance spells out its unit ("kilometers", "miles"),
                // unlike the two-letter "kg"/"sec"/"cal" this pill was sized
                // for, so it needs to shrink rather than wrap onto a second
                // line inside a fixed-width pill.
                Text(unitLabel(field: field, exercise: exercise, set: set))
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSubdued)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .padding(.horizontal, Spacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isActive ? Color.trameText : Color.trameSeparator)
                .frame(height: isActive ? 3 : 1)
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
            .foregroundStyle(Color.trameText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.trameSeparator).frame(height: 1)
            }
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
                .foregroundStyle(Color.trameText)
                .frame(width: controlSize, height: controlSize)
                .background(Color.trameRow)
                .overlay {
                    Rectangle().stroke(Color.trameSeparator, lineWidth: 1)
                }
                .contentShape(Rectangle()),
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

    // MARK: - Quick values

    /// One value a single tap can produce, and what that tap means.
    private struct QuickValue: Identifiable {
        enum Kind {
            /// Move the current value by `amount`.
            case delta(Double)
            /// Replace the current value with `amount`.
            case absolute(Double)
        }

        let label: String
        let kind: Kind
        /// Spoken instead of `label` where the shorthand would be read as
        /// nonsense — "1.25" meaning "a 1.25 plate on each side".
        let accessibilityLabel: String
        var isProminent: Bool = false

        var id: String { label }
    }

    /// The row that makes the common change a single tap.
    ///
    /// Stepping is the slowest route to the change that happens most often:
    /// 80 → 92.5 kg costs five presses of `+2.5`, and nobody thinks "five
    /// increments" — they think "a 2.5 and a 10 on each side", or "the same as
    /// last time", or "make it a minute". Each field gets the vocabulary it is
    /// actually spoken in, and the keypad stays underneath for everything these
    /// buttons cannot say.
    ///
    /// Absolute and relative are deliberately mixed, because the fields are:
    /// a plank is set *to* ninety seconds, while calories accumulate *by*
    /// twenty-five.
    @ViewBuilder
    private func quickValueRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        let values = quickValues(exercise: exercise, set: set)
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let caption = quickValueCaption(exercise: exercise, set: set) {
                    Text(caption)
                        .font(AppFont.caption2Bold)
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.trameSubdued)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.xs),
                        GridItem(.flexible(), spacing: Spacing.xs),
                        GridItem(.flexible(), spacing: Spacing.xs)
                    ],
                    spacing: Spacing.xs
                ) {
                    ForEach(values) { value in
                        quickValueButton(value, set: set)
                    }
                }
            }
            .accessibilityIdentifier("quick-value-row")
        }
    }

    private func quickValueButton(_ value: QuickValue, set: ExerciseSet) -> some View {
        Button {
            switch value.kind {
            case .delta(let amount):
                adjust(field: focusedField, by: amount, set: set)
            case .absolute(let amount):
                setValue(amount, field: focusedField, set: set)
            }
        } label: {
            Text(value.label)
                .font(AppFont.footnoteMedium)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(Color.trameText)
                .padding(.horizontal, Spacing.m)
                .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                .background(value.isProminent ? Color.trameCurrent : Color.clear)
                .overlay {
                    Rectangle().stroke(Color.trameSeparator, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(Text(value.accessibilityLabel))
        .accessibilityIdentifier("quick-value-\(value.label)")
    }

    /// The row's caption, when it has one.
    ///
    /// Always `nil` now. Both cases that used a caption — per-side plates and
    /// assistance — hand their whole vocabulary to a dedicated keypad, so the
    /// only chip left here is `Last …`, which needs no explaining. Keeping
    /// "Add per side" or "Less assistance is harder" above a single
    /// last-time shortcut would label the wrong control.
    ///
    /// Kept as a hook rather than deleted: the next field that grows a quick
    /// row needing explanation has one place to add it.
    private func quickValueCaption(exercise: ExerciseEntry, set: ExerciseSet) -> String? {
        nil
    }

    private func quickValues(exercise: ExerciseEntry, set: ExerciseSet) -> [QuickValue] {
        var values: [QuickValue] = []

        // "Same as last time" is the single most common intention in the whole
        // panel and was previously buried behind a chip. It leads the row.
        if let previous = previousValue(exercise: exercise, set: set) {
            values.append(
                QuickValue(
                    label: String(localized: "Last \(quickLabel(previous))"),
                    kind: .absolute(previous),
                    accessibilityLabel: String(localized: "Use last time's value, \(quickLabel(previous))"),
                    isProminent: true
                )
            )
        }

        switch focusedField {
        case .weight:
            // A loaded bar has no quick values: `PlateKeypad` is the input
            // surface there and its keys *are* the plates, in colour. Repeating
            // them here would put the same discs on screen twice. `Last …`
            // still applies above — it is the one shortcut the plate keys
            // cannot express.
            // Assisted work has no quick values either. `AssistKeypad` owns the
            // whole range and moves in both directions; this row could only
            // ever offer `+`, so it sat under the caption "less assistance is
            // harder" while providing no way to get less. A control that
            // contradicts its own label is worse than no control.
            if usesPerSidePlates(exercise) || exercise.trackingTypeSnapshot == .assistedBodyweight {
                break
            } else {
                let step = coarseWeightStep(for: exercise, set: set)
                for multiple in [1.0, 2.0, 4.0] {
                    let amount = step * multiple
                    values.append(
                        QuickValue(
                            label: "+\(Formatters.formatFloat(Float(amount)))",
                            kind: .delta(amount),
                            accessibilityLabel: String(localized: "Add \(Formatters.formatFloat(Float(amount))) \(set.weightType.rawValue)")
                        )
                    )
                }
            }

        case .duration:
            // Nothing. `DurationKeypad` *is* the presets for a timed set, so
            // repeating them here would put the same six values on screen
            // twice. The `Last …` chip above still applies, which is the one
            // duration shortcut the grid cannot express.
            break

        case .calories:
            for amount in [10.0, 25.0, 50.0] {
                values.append(
                    QuickValue(
                        label: "+\(Int(amount))",
                        kind: .delta(amount),
                        accessibilityLabel: String(localized: "Add \(Int(amount)) calories")
                    )
                )
            }

        case .distance:
            for amount in [100.0, 400.0, 1000.0] {
                values.append(
                    QuickValue(
                        label: "+\(Int(amount))",
                        kind: .delta(amount),
                        accessibilityLabel: String(localized: "Add \(Int(amount))")
                    )
                )
            }

        case .repetitions:
            // The ± keys already cover ±1 well. Only the jumps worth a
            // dedicated target appear here.
            for amount in [5.0, 10.0] {
                values.append(
                    QuickValue(
                        label: "+\(Int(amount))",
                        kind: .delta(amount),
                        accessibilityLabel: String(localized: "Add \(Int(amount)) reps")
                    )
                )
            }
        }

        return values
    }

    /// Whether per-side plate arithmetic is the right mental model.
    ///
    /// Reuses `supportsPlateCalculator` rather than testing for a barbell, so
    /// the quick values and the plate calculator agree about what "per side"
    /// means — a plate-loaded leg press has two ends to load and a stack does
    /// not. Per-load-unit exercises are excluded on top of that: a pair of
    /// dumbbells already logs one unit's weight, so doubling would be counted
    /// twice.
    private func usesPerSidePlates(_ exercise: ExerciseEntry) -> Bool {
        exercise.exercise.supportsPlateCalculator
            && exercise.loggingSemanticsSnapshot.weightEntryStyle != .perLoadUnit
    }

    private func isPlateKeypadShowing(_ exercise: ExerciseEntry) -> Bool {
        focusedField == .weight
            && usesPerSidePlates(exercise)
            && !isTypingExactValue
    }

    private func weightUnitPicker(on set: ExerciseSet) -> some View {
        Picker("Weight unit", selection: Binding(
            get: { set.weightType == .kg ? UnitSystem.metric : UnitSystem.imperial },
            set: { applyWeightUnit($0, to: set) }
        )) {
            Text("kg").tag(UnitSystem.metric)
            Text("lbs").tag(UnitSystem.imperial)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("panel-weight-unit-toggle")
    }

    // MARK: - Plate keypad

    private func plateEquipment(for exercise: ExerciseEntry, set: ExerciseSet) -> PlateEquipment {
        PlateEquipment(
            unitSystem: set.weightType == .kg ? .metric : .imperial,
            selectedBarID: selectedBarID,
            usesBarbell: exercise.exercise.equipmentType == .barbell
        )
    }

    /// What is on the bar right now, one side.
    ///
    /// The lifter's own loading order wins when there is one. Falling back to a
    /// solve covers every way a weight can arrive without being loaded here — a
    /// typed value, `Last 80`, a template's prescription — so the stack is
    /// always populated even though nothing was pressed.
    private func loadedPlates(equipment: PlateEquipment, set: ExerciseSet) -> [Float] {
        if let composition = plateComposition,
           plateCompositionSetID == set.persistentModelID,
           abs(composition.totalWeight(barWeight: equipment.barWeight) - set.weight) < 0.001 {
            return composition.plates
        }
        return solvedPlates(equipment: equipment, target: set.weight)
    }

    private func solvedPlates(equipment: PlateEquipment, target: Float) -> [Float] {
        PlateCalculation(
            target: target,
            barWeight: equipment.barWeight,
            plates: equipment.plates
        ).plates
    }

    private func plateKeypad(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        let equipment = plateEquipment(for: exercise, set: set)
        let loaded = loadedPlates(equipment: equipment, set: set)
        let solved = solvedPlates(equipment: equipment, target: set.weight)
        let remainder = PlateCalculation(
            target: set.weight,
            barWeight: equipment.barWeight,
            plates: equipment.plates
        ).remainingWeight

        return PlateKeypad(
            target: set.weight,
            barWeight: equipment.barWeight,
            availablePlates: equipment.plates,
            loadedPerSide: loaded,
            optimizedCount: solved.isEmpty ? nil : solved.count,
            hasRemainder: remainder > 0.001,
            unitSystem: set.weightType == .kg ? .metric : .imperial,
            unitLabel: set.weightType.rawValue,
            selectedBarID: $selectedBarID,
            onKey: { handlePlate($0, exercise: exercise, set: set) },
            onSelectUnitSystem: { applyWeightUnit($0, to: set) }
        )
    }

    private func applyWeightUnit(_ system: UnitSystem, to set: ExerciseSet) {
        let targetType: WeightType = system == .metric ? .kg : .lbs
        guard set.weightType != targetType else { return }

        let converted = UnitConversion.weight(set.weight, from: set.weightType, to: targetType)
        let increment = Constants.Progression.increment(for: targetType)
        let rounded = (converted / increment).rounded() * increment

        set.weight = rounded
        set.weightType = targetType
        set.usedMetric = system
        plateComposition = nil
        plateCompositionSetID = nil
        coordinator.endEntry(ifEditing: .weight)
        UserDefaults.standard.setUnitSystem(system)
        viewModel.persistChanges()
    }

    /// Writes a composition and the total it produces, together, so the number
    /// above the stack can never disagree with the discs under it.
    private func commitComposition(
        _ composition: PlateLoadComposition,
        equipment: PlateEquipment,
        set: ExerciseSet
    ) {
        plateComposition = composition
        plateCompositionSetID = set.persistentModelID
        setValue(Double(composition.totalWeight(barWeight: equipment.barWeight)), field: .weight, set: set)
    }

    private func handlePlate(_ key: PlateKey, exercise: ExerciseEntry, set: ExerciseSet) {
        let equipment = plateEquipment(for: exercise, set: set)

        // Start from what is on the bar, whether the lifter loaded it here or it
        // arrived as a number and was solved for display.
        var composition = PlateLoadComposition(
            plates: loadedPlates(equipment: equipment, set: set)
        )

        switch key {
        case .plate(let plate):
            composition.add(plate)
            commitComposition(composition, equipment: equipment, set: set)

        case .bareBar:
            commitComposition(PlateLoadComposition(), equipment: equipment, set: set)

        case .removeLast:
            // The *last one on*, not the largest. With loading order preserved
            // this is a true undo: press 10, press 25, remove — and the 10 is
            // still there, because that is what would happen at the rack.
            guard let last = composition.plates.last else {
                commitComposition(PlateLoadComposition(), equipment: equipment, set: set)
                return
            }
            composition.remove(last)
            commitComposition(composition, equipment: equipment, set: set)

        case .optimize:
            // Same total, fewest discs. Only ever reachable from a button that
            // has already said how many it would save.
            let solved = solvedPlates(equipment: equipment, target: set.weight)
            commitComposition(PlateLoadComposition(plates: solved), equipment: equipment, set: set)

        case .digits:
            // A typed weight is no longer described by these discs, so the
            // stack goes back to being derived rather than remembered.
            plateComposition = nil
            plateCompositionSetID = nil
            isTypingExactValue = true
            coordinator.endEntry(ifEditing: .weight)
        }
    }

    /// How far one press of the assistance slider moves.
    ///
    /// Not `fineWeightStep`: that is a microplate, and an assistance stack does
    /// not have microplates. It also made the slider draw a tick per kilogram —
    /// a hundred of them across the track, which rendered as a dotted grey line
    /// under the thumb and made the quick keys read `−1 / +1` on a machine whose
    /// smallest real change is five.
    private func assistStep(for set: ExerciseSet) -> Double {
        set.weightType == .kg ? 5 : 10
    }

    /// The most assistance the slider will offer.
    ///
    /// Capped at body weight when it is known, because nothing can take more
    /// than all of you off the bar — a pull-up assisted by more than you weigh
    /// is not a rep. Without a recorded body weight it falls back to a machine-
    /// sized range, which is generous rather than wrong: the digit pad is one
    /// tap away for anything beyond it.
    private func assistMaximum(for set: ExerciseSet) -> Double {
        if let bodyWeight = viewModel.latestBodyWeight(in: set.weightType), bodyWeight > 0 {
            return Double(bodyWeight)
        }
        return set.weightType == .kg ? 100 : 220
    }



    private func quickLabel(_ value: Double) -> String {
        focusedField == .duration
            ? ClockEntry.clockText(seconds: value)
            : Formatters.formatFloat(Float(value))
    }

    /// Last session's value for *this* set position, in the units this set is
    /// being logged in.
    private func previousValue(exercise: ExerciseEntry, set: ExerciseSet) -> Double? {
        let index = setPosition(of: set, in: exercise)
        guard let previous = viewModel.previousPerformance(for: exercise)?.set(at: index) else {
            return nil
        }

        switch focusedField {
        case .repetitions:
            return previous.repetitions > 0 ? Double(previous.repetitions) : nil
        case .weight:
            let converted = UnitConversion.weight(
                previous.weight,
                from: previous.weightType,
                to: set.weightType
            )
            return converted > 0 ? Double(converted) : nil
        case .duration:
            return previous.duration.flatMap { $0 > 0 ? $0 : nil }
        case .calories:
            return previous.calories.flatMap { $0 > 0 ? $0 : nil }
        case .distance:
            // The snapshot stores distance in its own `distanceType`, and the
            // display unit here may differ. Offering an unconverted number
            // would be confidently wrong, which is worse than offering none.
            return nil
        }
    }

    /// Writes an absolute value through the same bookkeeping ``adjust`` uses, so
    /// a quick value and a stepper press are indistinguishable to everything
    /// downstream — the typed-text session, the override flag, the save.
    private func setValue(_ value: Double, field: SetInputFocus.Field, set: ExerciseSet) {
        switch field {
        case .repetitions: set.repetitions = Float(max(0, value))
        case .weight: set.weight = Float(max(0, value))
        case .duration: set.duration = max(0, value)
        case .calories: set.calories = max(0, value)
        case .distance:
            let displayUnit = WorkoutDistancePolicy.preferredDisplayUnit(
                forMeters: WorkoutDistancePolicy.meters(of: set),
                system: UserDefaults.standard.unitSystem
            )
            WorkoutDistancePolicy.storeDisplayValue(
                Float(max(0, value)),
                displayUnit: displayUnit,
                on: set
            )
        }

        // Mirrors `adjust(field:by:set:)` exactly: a quick value and a stepper
        // press must be indistinguishable to everything downstream.
        coordinator.endEntry(ifEditing: field)
        coordinator.clearBlockedAttempt()
        viewModel.persistChanges()
    }

    // MARK: - Validation

    /// Why the set was refused, and — when the fix is not on this panel — the
    /// way to get to it.
    ///
    /// This was a caption in `gymAccent` with no icon, no fill, and no route to
    /// the thing it was describing. For a missing rep count that was survivable,
    /// because `confirm` also moves focus to the offending field and the field
    /// is six points away. For an unresolved complex component it was not: the
    /// outcome controls are on the set row, the keypad is covering the set row,
    /// and the sentence "record an outcome for every complex component" names a
    /// control that is not on screen. The lifter is told they are wrong and left
    /// to find out where.
    @ViewBuilder
    private var validationBanner: some View {
        if let validationMessage = coordinator.blockedMessage {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: AppIcon.warningCircle)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameAttention)
                    .accessibilityHidden(true)

                Text(validationMessage)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.trameRow,
                in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .stroke(Color.trameAttention, lineWidth: 1)
            }
            .gymShake(trigger: coordinator.blockedAttemptCount)
            .accessibilityElement(children: .contain)
            // Spoken the moment it appears, rather than waiting for the lifter
            // to swipe back to it.
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("panel-validation-message")
        }
    }

    // MARK: - Complex components

    /// True while the panel is standing in for the set row's component controls.
    ///
    /// Derived from live state rather than latched in `@State`. A latch set
    /// inside `confirm` would be wiped by this view's own focus observer on the
    /// very next update — `confirm` moves focus, so the observer always runs
    /// after it. Deriving also means the keypad returns on its own the moment
    /// the last component is recorded: the lifter never dismisses anything.
    private func isResolvingComponents(_ set: ExerciseSet) -> Bool {
        coordinator.blockedMessage != nil && hasUnresolvedComponents(set)
    }

    private func hasUnresolvedComponents(_ set: ExerciseSet) -> Bool {
        set.complexComponents.contains { $0.outcome == .notStarted }
    }

    private func complexComponentResolver(set: ExerciseSet) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ComplexComponentResultsView(
                components: set.orderedComplexComponents,
                onChange: {
                    set.liftQuality = set.orderedComplexComponents
                        .contains { $0.outcome == .missed } ? .missed : nil
                    viewModel.persistChanges()
                    // The refusal has been answered. Retiring it here stops the
                    // banner from still demanding outcomes that now all exist.
                    if !hasUnresolvedComponents(set) {
                        coordinator.clearBlockedAttempt()
                    }
                }
            )

            // An escape hatch back to the numbers, for a lifter who tapped
            // Complete early and actually wanted to fix a rep count first.
            Button("Back to keypad") {
                coordinator.clearBlockedAttempt()
            }
            .font(AppFont.footnoteMedium)
            .foregroundStyle(Color.trameText)
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
            .accessibilityIdentifier("panel-back-to-keypad")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("panel-complex-components")
    }

    /// Standing readiness, shown before the lifter taps anything.
    ///
    /// The shake and the message are a *reaction*; this is the part that stops
    /// the reaction from being needed. A complex set carries evidence the value
    /// fields do not show, so the panel states how much of it is recorded while
    /// there is still time to act on it — the same reason the target line above
    /// exists.
    @ViewBuilder
    private func componentReadiness(set: ExerciseSet) -> some View {
        let components = set.orderedComplexComponents
        if !components.isEmpty {
            let recorded = components.filter { $0.outcome != .notStarted }.count
            let isComplete = recorded == components.count

            Label(
                "Complex outcomes \(recorded)/\(components.count)",
                systemImage: isComplete ? AppIcon.checkmarkCircle : AppIcon.circleDashed
            )
            .font(AppFont.caption)
            .foregroundStyle(isComplete ? Color.trameCompleted : Color.trameAttention)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(
                isComplete
                    ? String(localized: "All complex component outcomes recorded")
                    : String(localized: "\(recorded) of \(components.count) complex component outcomes recorded")
            )
            .accessibilityIdentifier("panel-component-readiness")
        }
    }

    // MARK: - Footer

    private func footer(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        Group {
            // While the panel is standing in for the component controls, a
            // full-strength "Complete set" contradicts the amber refusal
            // directly above it: the dominant control on screen offers an
            // action the screen has already refused, and tapping it can only
            // shake. The button states the outstanding work instead and stays
            // inert until the outcomes exist — the resolver above it is the
            // only thing left to do, and it re-enables this on its own.
            if isResolvingComponents(set) {
                Button {} label: {
                    Label("Record every outcome", systemImage: AppIcon.circleDashed)
                }
                .buttonStyle(.tramePrimaryAction)
                .disabled(true)
                .accessibilityLabel("Record every outcome")
                .accessibilityHint("Record each complex component outcome above to complete this set.")
                .accessibilityIdentifier("panel-complete-set")
            } else if coordinator.entryText != nil {
                Button {
                    viewModel.flushPendingTypedInputSave()
                    coordinator.endEntry()
                    coordinator.focus = nil
                } label: {
                    HStack(spacing: Spacing.m) {
                        Text(exactCommitTitle(exercise: exercise, set: set))

                        Spacer(minLength: Spacing.s)

                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.subheadlineSemibold)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.tramePrimaryAction)
                .accessibilityHint("Keeps this value without completing the set.")
                .accessibilityIdentifier("panel-use-value")
            } else {
                Button {
                    confirm(exercise: exercise, set: set)
                } label: {
                    Label("Complete set", systemImage: AppIcon.checkmark)
                }
                .buttonStyle(.tramePrimaryAction)
                .gymShake(trigger: coordinator.blockedAttemptCount)
                .accessibilityLabel("Complete set")
                .accessibilityHint("Marks this set done, starts rest, and moves to the next set.")
                .accessibilityIdentifier("panel-complete-set")
            }
        }
    }

    private func exactCommitTitle(exercise: ExerciseEntry, set: ExerciseSet) -> String {
        let value = displayValue(field: focusedField, set: set)
        let unit = unitLabel(field: focusedField, exercise: exercise, set: set)
        return unit.isEmpty
            ? String(localized: "Use \(value)")
            : String(localized: "Use \(value) \(unit)")
    }

    private func navigationButton(systemImage: String, offset: Int) -> some View {
        let isEnabled = offset < 0 ? coordinator.previousInput != nil : coordinator.nextInput != nil

        return Button {
            viewModel.flushPendingTypedInputSave()
            coordinator.moveFocus(by: offset)
        } label: {
            // The visual chip is 26pt, matched to the compact header it now
            // sits in alongside the identity/position text; the tap target
            // stays at the 44pt minimum regardless, the same split the
            // dismiss button and the exercise card's overflow menu already
            // use.
            Image(systemName: systemImage)
                .font(AppFont.captionBold)
                .foregroundStyle(isEnabled ? Color.trameText : Color.trameSubdued)
                .frame(width: 26, height: 26)
                .background(isEnabled ? Color.trameCurrent : Color.trameRow, in: Circle())
                .frame(
                    width: ComponentSize.minimumTouchTarget,
                    height: ComponentSize.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .disabled(!isEnabled)
        .accessibilityLabel(offset < 0 ? "Previous field" : "Next field")
    }

    // MARK: - Actions

    private func confirm(exercise: ExerciseEntry, set: ExerciseSet) {
        switch viewModel.completeSet(set, in: exercise) {
        case .blocked(let message, let focus):
            // Focus first, message second: the coordinator's focus setter
            // clears the message, so recording before moving would erase it.
            coordinator.focus = focus
            coordinator.recordBlockedAttempt(message)
            GymAnnouncement.post(message)
        case .completed(let nextFocus):
            coordinator.clearBlockedAttempt()
            onSetCompleted(exercise)
            coordinator.refreshOrder(in: viewModel.activeWorkout)
            // A rest that starts behind the keypad is a rest the lifter never
            // sees. `ActiveWorkoutView.isShowingRestTakeover` is gated on
            // `focus == nil`, so holding focus here silently downgrades the
            // full-screen takeover to the collapsed pill — and completing a set
            // from the keypad ends up meaning something different from
            // completing it from the command bar.
            //
            // Only yield the keypad when a rest is actually going to run.
            // A superset mid-round and the final set of the workout both
            // suppress rest, and there the fast path — straight to the next
            // field — is still the right one.
            if viewModel.isTimerVisible, viewModel.hasIncompleteSet {
                coordinator.focus = nil
            } else {
                coordinator.focus = nextFocus
            }
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
        coordinator.clearBlockedAttempt()
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
            // Read back as a clock, matching how it is now typed. `90` would
            // otherwise be entered as 1:30 and echoed as "90", so the field
            // would disagree with the keypad that filled it.
            let seconds = set.duration ?? 0
            return seconds == 0 ? "—" : ClockEntry.clockText(seconds: seconds)
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
            // Per-side counting rides on the unit rather than the caption, the
            // same place per-load-unit weight states itself: it belongs to the
            // number, and putting it there is also what gets it spoken — the
            // pill's accessibility label is built from this string. It used to
            // sit beside the exercise name in the header, where a long name
            // truncated it away.
            let semantics = exercise.loggingSemanticsSnapshot
            if semantics.laterality == .unilateral && semantics.repCountingStyle == .perSide {
                return String(localized: "rep / side")
            }
            return "rep"
        case .weight:
            // Per-load-unit exercises (a pair of dumbbells, one per hand) log
            // the weight of each unit, so the unit label carries that meaning.
            if exercise.loggingSemanticsSnapshot.weightEntryStyle == .perLoadUnit {
                return String(localized: "\(set.weightType.rawValue) each")
            }
            return set.weightType.rawValue
        case .duration:
            // The colon in "1:30" already says what the unit is; appending
            // "sec" to a clock reads as a contradiction.
            return ""
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

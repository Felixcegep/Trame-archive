import SwiftUI

/// The answer control for one step.
///
/// One view rather than thirteen files: every question is a selection over a
/// list, and the differences between them are the list, the arity, and one or
/// two special controls. Splitting that into a file per question would produce
/// thirteen near-identical layouts that drift apart the first time one of them
/// is touched.
struct OnboardingQuestionView: View {
    @Bindable var coordinator: OnboardingCoordinator
    let step: OnboardingStep

    var body: some View {
        OnboardingScaffold(
            step: step,
            progressDescription: coordinator.progressDescription,
            progressFraction: coordinator.progressFraction,
            stepIndex: coordinator.currentStepIndex ?? 0,
            stepCount: coordinator.steps.count,
            direction: coordinator.direction,
            canGoBack: coordinator.canGoBack,
            validationMessage: coordinator.validationMessage,
            primaryAction: primaryAction,
            onBack: coordinator.goBack,
            onSkip: skipAction
        ) {
            content
        }
        // The one haptic in the question flow.
        //
        // `Feedback.swift` is explicit that feedback fires from a committed
        // domain event and never from a view appearing, a button being pressed,
        // or a navigation transition — so answering a question deliberately
        // stays silent, however tempting a tick per tap is. A *refused* commit
        // is the exception: it is a real event, the lifter has been stopped,
        // and `.validationBlocked` exists for precisely this.
        .gymFeedback(.validationBlocked, trigger: coordinator.validationAttemptCount)
    }

    /// Explicitly typed rather than a ternary on a method reference, which the
    /// type checker cannot reconcile against an optional closure parameter.
    private var skipAction: (() -> Void)? {
        guard step.isSkippable else { return nil }
        return { coordinator.skip() }
    }

    /// Present on every step that does not commit itself, and on any
    /// self-advancing step the lifter has already answered.
    private var primaryAction: (title: String, isEnabled: Bool, perform: () -> Void)? {
        guard !step.advancesOnSelection || coordinator.isRevisiting(step) else { return nil }
        return (
            title: step.continueTitle,
            isEnabled: true,
            perform: coordinator.advance
        )
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .discipline: disciplineContent
        case .goal: goalContent
        case .experience: experienceContent
        case .frequency: frequencyContent
        case .weekdays: weekdaysContent
        case .cadence: cadenceContent
        case .sessionDuration: sessionDurationContent
        case .location: locationContent
        case .equipment: equipmentContent
        case .specializedEquipment: specializedEquipmentContent
        case .units: unitsContent
        case .focusAreas: focusAreasContent
        case .competition: competitionContent
        }
    }

    /// Records a single answer and lets the step carry the lifter forward.
    /// Every self-advancing question routes through here so the commit rule
    /// lives in one place.
    private func choose(_ mutate: @escaping (inout OnboardingDraft) -> Void) {
        coordinator.update(mutate)
        coordinator.scheduleAutoAdvanceIfNeeded(from: step)
    }

    // MARK: Discipline

    private var disciplineContent: some View {
        VStack(spacing: Spacing.s) {
            ForEach(TrainingDisciplinePreference.allCases, id: \.self) { discipline in
                OnboardingChoiceCard(
                    title: discipline.title,
                    icon: discipline.icon,
                    isSelected: coordinator.draft.discipline == discipline
                ) {
                    choose { $0.discipline = discipline }
                }
                .accessibilityIdentifier("onboarding-discipline-\(discipline.rawValue)")
            }
        }
    }

    // MARK: Goal

    private var goalContent: some View {
        VStack(spacing: Spacing.s) {
            ForEach(TrainingGoalPreference.allCases, id: \.self) { goal in
                OnboardingChoiceCard(
                    title: goal.title,
                    isSelected: coordinator.draft.goal == goal
                ) {
                    choose { $0.goal = goal }
                }
                .accessibilityIdentifier("onboarding-goal-\(goal.rawValue)")
            }
        }
    }

    // MARK: Experience

    private var experienceContent: some View {
        VStack(spacing: Spacing.s) {
            ForEach(ProfileExperienceLevel.allCases, id: \.self) { level in
                OnboardingChoiceCard(
                    title: level.title,
                    detail: level.detail,
                    isSelected: coordinator.draft.experience == level
                ) {
                    choose { $0.experience = level }
                }
                .accessibilityIdentifier("onboarding-experience-\(level.rawValue)")
            }

            // Stated rather than hidden behind the "Advanced" card, because the
            // lifter deciding between two levels is exactly the person who
            // needs to know the answer is not load-bearing.
            Text("Experience ranks plans. It never hides one from you.")
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.xs)
        }
    }

    // MARK: Frequency

    private var frequencyContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Seven chips do not fit one line once the chips grow with the type
            // size; a fixed row either clips the last days or squeezes every
            // chip below the 44-point target. Flowing onto a second line keeps
            // all seven tappable.
            ChipFlowLayout(spacing: Spacing.s) {
                ForEach(1...7, id: \.self) { days in
                    OnboardingChip(
                        title: "\(days)",
                        accessibilityTitle: CountPhrase.daysPerWeek(days),
                        isSelected: coordinator.draft.preferredDaysPerWeek == days
                    ) {
                        choose {
                            $0.preferredDaysPerWeek = days
                            $0.scheduleFlexibility = .fixedWeekdays
                        }
                    }
                    .accessibilityIdentifier("onboarding-frequency-\(days)")
                }
            }

            OnboardingChoiceCard(
                title: ScheduleFlexibility.variable.title,
                detail: String(localized: "Sessions are placed in order instead of on fixed weekdays."),
                isSelected: coordinator.draft.scheduleFlexibility == .variable
            ) {
                choose {
                    $0.scheduleFlexibility = .variable
                    $0.preferredDaysPerWeek = nil
                    $0.preferredWeekdays = []
                }
            }
            .accessibilityIdentifier("onboarding-frequency-variable")
        }
    }

    // MARK: Weekdays

    private var weekdaysContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Wraps for the same reason the frequency row does. The layout
            // places subviews in the order it receives them, so `orderedWeekdays`
            // — which starts at the locale's first weekday — still reads left to
            // right, top to bottom.
            ChipFlowLayout(spacing: Spacing.xs) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    OnboardingChip(
                        title: shortWeekdaySymbol(weekday),
                        accessibilityTitle: weekdaySymbol(weekday),
                        isSelected: coordinator.draft.weekdays.contains(weekday)
                    ) {
                        // Only the tapped day changes state. The row never
                        // reorders itself to put chosen days first — a control
                        // that rearranges under the finger costs more than the
                        // grouping it buys.
                        coordinator.update { draft in
                            var days = draft.weekdays
                            if days.contains(weekday) {
                                days.remove(weekday)
                            } else {
                                days.insert(weekday)
                            }
                            draft.weekdays = days
                        }
                    }
                    .accessibilityIdentifier("onboarding-weekday-\(weekday)")
                }
            }

            if let target = coordinator.draft.preferredDaysPerWeek {
                Text(weekdaySelectionSummary(target: target))
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityIdentifier("onboarding-weekday-summary")
            }
        }
    }

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func shortWeekdaySymbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    private func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    /// Reports the gap without refusing to move on. The lifter said four days;
    /// if they pick three, the plan simply schedules three and says so.
    private func weekdaySelectionSummary(target: Int) -> String {
        let chosen = coordinator.draft.preferredWeekdays.count
        if chosen == target {
            return String(localized: "\(CountPhrase.days(chosen)) selected.")
        }
        if chosen < target {
            return String(localized: "\(chosen) of \(target) selected. You can continue with fewer.")
        }
        return String(localized: "\(chosen) selected — more than the \(target) you named. That’s fine.")
    }

    // MARK: Cadence

    private var cadenceContent: some View {
        VStack(spacing: Spacing.s) {
            ForEach(RotationCadencePreference.allCases, id: \.self) { cadence in
                OnboardingChoiceCard(
                    title: cadence.title,
                    isSelected: coordinator.draft.rotationCadence == cadence
                ) {
                    choose { $0.rotationCadence = cadence }
                }
                .accessibilityIdentifier("onboarding-cadence-\(cadence.rawValue)")
            }
        }
    }

    // MARK: Session duration

    private var sessionDurationContent: some View {
        VStack(spacing: Spacing.s) {
            ForEach(SessionDurationPreference.allCases, id: \.self) { duration in
                OnboardingChoiceCard(
                    title: duration.title,
                    isSelected: coordinator.draft.sessionDuration == duration
                ) {
                    choose { $0.sessionDuration = duration }
                }
                .accessibilityIdentifier("onboarding-duration-\(duration.rawValue)")
            }
        }
    }

    // MARK: Location

    private var locationContent: some View {
        VStack(spacing: Spacing.s) {
            ForEach(TrainingLocationPreference.allCases, id: \.self) { location in
                OnboardingChoiceCard(
                    title: location.title,
                    detail: location.detail,
                    icon: location.icon,
                    isSelected: coordinator.draft.location == location
                ) {
                    choose { draft in
                        let isChange = draft.location != location
                        draft.location = location
                        // Replaces the list only when the location actually
                        // changed, so a preset can overwrite an earlier preset
                        // but never a lifter's own edits made after this screen.
                        draft.applyLocationSuggestion(replacingExisting: isChange && !draft.completedStepIDs.contains(OnboardingStep.equipment.rawValue))
                    }
                }
                .accessibilityIdentifier("onboarding-location-\(location.rawValue)")
            }
        }
    }

    // MARK: Equipment

    private var equipmentContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let location = coordinator.draft.location, !location.suggestedEquipment.isEmpty {
                Text("We ticked what’s common for a \(location.title.lowercased()). Change anything that’s different.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            OnboardingTileGrid {
                ForEach(EquipmentType.onboardingOrder, id: \.self) { equipment in
                    OnboardingMultiChoiceTile(
                        title: equipment.onboardingTitle,
                        icon: equipment.onboardingIcon,
                        isSelected: coordinator.draft.equipment.contains(equipment)
                    ) {
                        coordinator.update { draft in
                            var selection = draft.equipment
                            if selection.contains(equipment) {
                                selection.remove(equipment)
                            } else {
                                selection.insert(equipment)
                            }
                            draft.equipment = selection
                        }
                    }
                    .accessibilityIdentifier("onboarding-equipment-\(equipment.identifierSlug)")
                }
            }

            Button("Clear all") {
                coordinator.update { $0.equipmentIDs = [] }
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymSubduedText)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("onboarding-equipment-clear")
        }
    }

    // MARK: Specialized equipment

    @ViewBuilder
    private var specializedEquipmentContent: some View {
        if let group = coordinator.draft.discipline?.specializedEquipmentGroup {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(group.question)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)

                OnboardingTileGrid {
                    ForEach(group.capabilities) { capability in
                        OnboardingMultiChoiceTile(
                            title: capability.title,
                            isSelected: coordinator.draft.specializedEquipment.contains(capability.id)
                        ) {
                            coordinator.update { draft in
                                var selection = draft.specializedEquipment
                                if selection.contains(capability.id) {
                                    selection.remove(capability.id)
                                } else {
                                    selection.insert(capability.id)
                                }
                                draft.specializedEquipment = selection
                            }
                        }
                        .accessibilityIdentifier("onboarding-specialized-\(capability.id)")
                    }
                }
            }
        }
    }

    // MARK: Units

    private var unitsContent: some View {
        VStack(spacing: Spacing.s) {
            OnboardingChoiceCard(
                title: String(localized: "Metric"),
                detail: String(localized: "Kilograms, metres and kilometres"),
                isSelected: coordinator.draft.unitSystem == .metric
            ) {
                coordinator.update { $0.unitSystem = .metric }
            }
            .accessibilityIdentifier("onboarding-units-metric")

            OnboardingChoiceCard(
                title: String(localized: "Imperial"),
                detail: String(localized: "Pounds, feet and miles"),
                isSelected: coordinator.draft.unitSystem == .imperial
            ) {
                coordinator.update { $0.unitSystem = .imperial }
            }
            .accessibilityIdentifier("onboarding-units-imperial")
        }
        // The locale's system is offered as a starting point the moment the
        // screen appears, so the common case is one confirming tap — but it is
        // shown, never applied behind the lifter's back.
        .onAppear {
            guard coordinator.draft.unitSystem == nil else { return }
            coordinator.update { $0.unitSystem = UnitSystemDefault.suggested }
        }
    }

    // MARK: Focus areas

    private var focusAreasContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            OnboardingTileGrid {
                ForEach(FocusArea.allCases, id: \.self) { area in
                    OnboardingMultiChoiceTile(
                        title: area.title,
                        isSelected: coordinator.draft.focusAreas.contains(area)
                    ) {
                        toggleFocusArea(area)
                    }
                    .accessibilityIdentifier("onboarding-focus-\(area.rawValue)")
                    .disabled(isFocusAreaDisabled(area))
                    .opacity(isFocusAreaDisabled(area) ? 0.4 : 1)
                }
            }

            Text("Choose up to two. Emphasis ranks plans and suggests accessories — it never adds sets to a plan on its own.")
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// `balanced` is exclusive with everything else. "Balanced, but mostly
    /// arms" is not a preference the ranking can honour, so the UI refuses to
    /// let it be expressed rather than silently ignoring half of it.
    private func toggleFocusArea(_ area: FocusArea) {
        coordinator.update { draft in
            var selection = draft.focusAreas
            if selection.contains(area) {
                selection.removeAll { $0 == area }
            } else if area == .balanced {
                selection = [.balanced]
            } else {
                selection.removeAll { $0 == .balanced }
                if selection.count >= FocusArea.maximumSelections {
                    selection.removeFirst()
                }
                selection.append(area)
            }
            draft.focusAreas = selection
        }
    }

    private func isFocusAreaDisabled(_ area: FocusArea) -> Bool {
        // Nothing is ever disabled: reaching the limit replaces the oldest
        // choice instead of blocking the new one, which is the behaviour that
        // does not require the lifter to work out what to untick first.
        _ = area
        return false
    }

    // MARK: Competition

    /// Three questions on one screen, against the one-concept-per-screen rule.
    ///
    /// They are one concept — the event — and each is a single short control.
    /// Three separate screens carrying one picker each would be a longer flow
    /// that tells the lifter less about what is being asked and why.
    private var competitionContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            competitionSection(String(localized: "What are you preparing for?")) {
                VStack(spacing: Spacing.s) {
                    ForEach(CompetitionDiscipline.allCases, id: \.self) { discipline in
                        OnboardingChoiceCard(
                            title: discipline.title,
                            isSelected: coordinator.draft.competition?.discipline == discipline
                        ) {
                            coordinator.update { draft in
                                var competition = draft.competition ?? CompetitionProfileDraft()
                                competition.discipline = discipline
                                draft.competition = competition
                            }
                        }
                        .accessibilityIdentifier("onboarding-competition-\(discipline.rawValue)")
                    }
                }
            }

            competitionSection(String(localized: "When is the event?")) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    DatePicker(
                        "Event date",
                        selection: eventDateBinding,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .disabled(coordinator.draft.competition?.eventDate == nil)
                    .accessibilityIdentifier("onboarding-competition-date")

                    Toggle("I don’t know yet", isOn: eventDateUnknownBinding)
                        .font(AppFont.subheadline)
                        .accessibilityIdentifier("onboarding-competition-date-unknown")
                }
            }

            competitionSection(String(localized: "Which standards should Trame use?")) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Federations publish different loads, divisions and weight classes. This selects a rulebook, not an identity.")
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(CompetitionStandards.allCases, id: \.self) { standards in
                        OnboardingChoiceCard(
                            title: standards.title,
                            isSelected: coordinator.draft.competition?.standards == standards
                        ) {
                            coordinator.update { draft in
                                var competition = draft.competition ?? CompetitionProfileDraft()
                                competition.standards = standards
                                draft.competition = competition
                            }
                        }
                        .accessibilityIdentifier("onboarding-standards-\(standards.rawValue)")
                    }
                }
            }
        }
    }

    private func competitionSection<SectionContent: View>(
        _ title: String,
        @ViewBuilder content: () -> SectionContent
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var eventDateBinding: Binding<Date> {
        Binding(
            get: { coordinator.draft.competition?.eventDate ?? Date() },
            set: { newValue in
                coordinator.update { draft in
                    var competition = draft.competition ?? CompetitionProfileDraft()
                    competition.eventDate = newValue
                    draft.competition = competition
                }
            }
        )
    }

    private var eventDateUnknownBinding: Binding<Bool> {
        Binding(
            get: { coordinator.draft.competition?.eventDate == nil },
            set: { isUnknown in
                coordinator.update { draft in
                    var competition = draft.competition ?? CompetitionProfileDraft()
                    competition.eventDate = isUnknown ? nil : Date()
                    draft.competition = competition
                }
            }
        )
    }
}

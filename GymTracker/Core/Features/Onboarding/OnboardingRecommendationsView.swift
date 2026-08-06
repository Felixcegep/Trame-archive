import SwiftData
import SwiftUI

/// The payoff screen: what the answers actually bought.
///
/// There is no analysis animation here, and that is deliberate. Ranking the
/// catalogue is a synchronous pass over a few dozen records; staging a
/// three-second "building your plan" sequence over it would be theatre, and the
/// kind that costs trust the first time a lifter notices the same wait appears
/// no matter what they answered. What the screen does instead is show the
/// answers it used, then the results.
struct OnboardingRecommendationsView: View {
    @Bindable var coordinator: OnboardingCoordinator
    let onOpenProgram: (UUID) -> Void
    let onOpenMobilityProgram: (UUID) -> Void
    let onBrowseAll: () -> Void
    let onStartFreeWorkout: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var results: [ProgramMatchResult] = []
    @State private var mobilityResults: [MobilityMatchResult] = []
    @State private var hasLoaded = false
    /// The refinement currently open. One at a time: these are adjustments to a
    /// list, and a stack of them would be the questionnaire again.
    @State private var activeRefinement: OnboardingStep?
    @State private var isShowingMobilityIntake = false
    @AccessibilityFocusState private var isHeadingFocused: Bool

    /// Mobility plans are a separate, independent recommendation track (see
    /// `MobilityMatchService`), shown only when they are actually reachable —
    /// asking about or recommending a mobility plan a beta build cannot open
    /// would be worse than not asking.
    private var isMobilityMatchingEnabled: Bool {
        FeatureFlags.current.isEnabled(.mobilityProgram)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    profileSummary

                    refinements

                    if results.isEmpty {
                        emptyState
                    } else {
                        resultsList
                    }

                    mobilitySection

                    alternatives
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.gymBackground)
        // One action, always reachable.
        //
        // The best match used to carry a filled button on its card, which is
        // the right place for it only while that card is on screen — by the
        // third result it has scrolled away, and the only remaining prominent
        // action was "Browse all plans" at the foot of thirty cards. A lifter
        // who scrolled to compare and then decided on the top plan had to
        // scroll all the way back to act on that decision.
        .safeAreaInset(edge: .bottom) { primaryActionBar }
        .accessibilityIdentifier("onboarding-recommendations")
        // Re-ranked on dismissal rather than on every tick inside the sheet:
        // a list reshuffling under a half-finished equipment selection is the
        // screen arguing with someone mid-sentence.
        .sheet(item: $activeRefinement, onDismiss: rank) { step in
            OnboardingRefinementSheet(coordinator: coordinator, step: step)
        }
        .sheet(isPresented: $isShowingMobilityIntake, onDismiss: rank) {
            OnboardingMobilityIntakeSheet(coordinator: coordinator)
        }
        .task {
            // Guarded so returning from a pushed plan detail does not re-rank
            // and reshuffle the list the lifter was reading.
            guard !hasLoaded else { return }
            hasLoaded = true
            rank()
            // The locale's system is offered the moment the screen appears, in
            // a control the lifter can see and change before they act on
            // anything — shown, never applied behind their back. This is the
            // same bargain the old units *screen* struck, minus the screen.
            if coordinator.draft.unitSystem == nil {
                coordinator.update { $0.unitSystem = UnitSystemDefault.suggested }
            }
            if UIAccessibility.isVoiceOverRunning {
                isHeadingFocused = true
            }
        }
    }

    /// Ranks the catalogue against the draft as it currently stands.
    ///
    /// Cheap enough to call on every refinement: `ProgramMatchService` is a
    /// synchronous pass over a few dozen value types with no store access, and
    /// its own documentation is explicit that pretending otherwise — staging a
    /// "building your plan" animation over microseconds of work — is a lie that
    /// costs trust the first time the wait looks identical whatever you answer.
    private func rank() {
        results = ProgramMatchService.rank(
            programs: ProgramMatchCandidate.candidates(using: modelContext),
            criteria: ProgramMatchCriteria(draft: coordinator.draft)
        )
        if isMobilityMatchingEnabled {
            mobilityResults = MobilityMatchService.rank(
                programs: MobilityMatchCandidate.candidates(using: modelContext),
                criteria: MobilityMatchCriteria(draft: coordinator.draft)
            )
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                Button(action: coordinator.goBack) {
                    Image(systemName: AppIcon.chevronLeft)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityLabel("Change answers")
                .accessibilityIdentifier("onboarding-recommendations-back")

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Plans that fit your training")
                    .font(AppFont.displayMedium)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isHeadingFocused)

                // The subtitle has to survive the case where there was nothing
                // to rank on. Claiming "ranked from your answers" to someone
                // who skipped every question — and who is looking at an
                // alphabetical list — is the screen lying about its own output.
                Text(headerSubtitle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        if results.isEmpty {
            return String(localized: "No ready-made plans are installed. Your answers are saved and will be used as soon as one is.")
        }
        if !hasRankingSignal {
            return String(localized: "You skipped the questions, so this is every plan in its default order. Refine anything below and the list re-ranks.")
        }
        return String(localized: "Ranked from your answers. Refine anything below and the list re-ranks — every plan stays available either way.")
    }

    /// The answers the ranking used, restated.
    ///
    /// Not decoration: it is the difference between "the app picked this" and
    /// "the app picked this *because you said that*", and it is also where a
    /// lifter notices they mis-tapped an answer three screens ago.
    @ViewBuilder
    private var profileSummary: some View {
        let chips = summaryChips
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Based on")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)

                ChipFlowLayout {
                    ForEach(chips, id: \.self) { chip in
                        GymTagChip(title: chip, style: .outlined)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding-profile-summary")
        }
    }

    private var summaryChips: [String] {
        let draft = coordinator.draft
        var chips: [String] = []
        if let discipline = draft.discipline, discipline != .unspecified { chips.append(discipline.title) }
        if let goal = draft.goal { chips.append(goal.title) }
        if let experience = draft.experience, experience != .unsure { chips.append(experience.title) }
        if let days = draft.preferredDaysPerWeek {
            chips.append(CountPhrase.daysPerWeekAbbreviated(days))
        } else if let cadence = draft.rotationCadence {
            chips.append(cadence.title)
        }
        if let duration = draft.sessionDuration { chips.append(duration.summaryTitle) }
        // Location is deliberately absent. It is not a field on
        // `ProgramMatchCriteria` and never reaches the ranking — its only job is
        // pre-ticking the equipment screen. Listing it under "Based on" told the
        // lifter it had shaped the order, which is the one claim this section
        // exists to make honestly.
        return chips
    }

    // MARK: Refinements

    /// The questions that used to be asked before any of this was visible.
    ///
    /// Each chip carries its own current answer, so the row doubles as the
    /// audit of what the ranking used — a lifter can see that they never said
    /// how long they train without opening anything. Tapping one opens the same
    /// control the old flow used, over the list it is about to reorder.
    ///
    /// Deliberately below "Based on" and above the results: it explains the
    /// order of what follows, and reads as a filter bar rather than as another
    /// round of questions.
    @ViewBuilder
    private var refinements: some View {
        let steps = OnboardingStep.refinements(for: coordinator.draft)
        if !results.isEmpty, !steps.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Refine")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)

                ChipFlowLayout(spacing: Spacing.s) {
                    ForEach(steps) { step in
                        refinementChip(step)
                    }
                }

                unitsControl
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding-refinements")
        }
    }

    private func refinementChip(_ step: OnboardingStep) -> some View {
        let answer = step.refinementSummary(for: coordinator.draft)
        let isAnswered = answer != nil

        return Button {
            activeRefinement = step
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(step.refinementTitle)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                if let answer {
                    Text(answer)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymPrimary)
                        .lineLimit(1)
                }

                // Points down rather than trailing: this opens a sheet from the
                // bottom, and the glyph should agree with where the thing comes
                // from. A chevron pointing right would promise a push.
                Image(systemName: AppIcon.chevronDown)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(
                isAnswered ? Color.gymPrimarySurface : Color.gymCard,
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isAnswered ? Color.gymPrimary : Color.gymBorder, lineWidth: 1)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.gymPress)
        .accessibilityElement(children: .combine)
        // Spoken as the question it answers, not as the four-word chip label —
        // "Session length" alone does not tell a VoiceOver user whether this
        // reports an answer or asks for one.
        .accessibilityLabel(
            answer.map { String(localized: "\(step.refinementTitle): \($0)") }
                ?? String(localized: "\(step.refinementTitle): not set")
        )
        .accessibilityHint("Opens this answer. The list re-ranks when you close it.")
        .accessibilityIdentifier("onboarding-refine-\(step.rawValue)")
    }

    /// Units, inline.
    ///
    /// This had a full screen of its own, which bought nothing: it changes no
    /// ranking and no plan, only how every number is drawn from here on. Both
    /// options are visible with the locale's suggestion already chosen, so the
    /// suggestion is one the lifter can see and reject before it means
    /// anything — which was the entire reason the question existed.
    private var unitsControl: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // The segmented style hides the picker's own label, and two
            // unlabelled segments reading "Kilograms | Pounds" in a row of
            // ranking filters look like one more thing that reorders the list.
            // Stated, so it is obvious this changes how numbers are drawn and
            // nothing else.
            Text("Weights shown in")
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)

            Picker("Weights shown in", selection: unitSystemBinding) {
                Text("Kilograms").tag(UnitSystem.metric)
                Text("Pounds").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("onboarding-units")
        }
        .padding(.top, Spacing.xs)
    }

    private var unitSystemBinding: Binding<UnitSystem> {
        Binding(
            get: { coordinator.draft.unitSystem ?? UnitSystemDefault.suggested },
            set: { newValue in coordinator.update { $0.unitSystem = newValue } }
        )
    }

    // MARK: Results

    /// One ranked list, plus a separate tier only for plans this build cannot
    /// run at all.
    ///
    /// There used to be a "Recommended" and a "Works with changes" section, and
    /// the split did real damage: "recommended" meant nothing more than "we
    /// produced no warning text", so a plan written for the lifter's exact
    /// discipline dropped below a weaker one because it honestly mentioned an
    /// experience gap. Warnings now travel on the card, where they inform the
    /// decision, instead of in a header that overrules the ranking.
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            resultSection(
                title: hasRankingSignal
                    ? String(localized: "Ranked for you")
                    : String(localized: "All plans"),
                results: results.filter(\.isRunnable)
            )
            resultSection(
                title: String(localized: "Not supported by this version"),
                results: results.filter { !$0.isRunnable }
            )
        }
    }

    /// Whether the lifter actually gave us anything to rank on. Drives every
    /// claim the screen makes about personalisation.
    private var hasRankingSignal: Bool {
        results.contains { !$0.reasons.isEmpty }
    }

    @ViewBuilder
    private func resultSection(title: String, results: [ProgramMatchResult]) -> some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(title.uppercased())
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityAddTraits(.isHeader)

                ForEach(Array(results.enumerated()), id: \.element.id) { _, result in
                    OnboardingRecommendationCard(
                        result: result,
                        // No card carries the filled action any more; the bar
                        // pinned to the bottom does, and it names the same plan
                        // this used to promote. One prominent action per screen,
                        // and one that cannot scroll out of reach.
                        //
                        // The rule it enforced still holds, and now holds
                        // everywhere: the prominent action only exists when the
                        // leading result can say why it leads. See
                        // `leadingResult`.
                        isLeading: false,
                        action: { onOpenProgram(result.programID) }
                    )
                }
            }
        }
    }

    // MARK: Mobility
    //
    // A wholly separate track from the workout results above: a lifter can
    // want either, both, or neither, and this section never implies the other
    // one's answers. Shown only when there is something to show — no bundled
    // mobility plans installed yet is not worth a second empty state on a
    // screen that already has one.
    @ViewBuilder
    private var mobilitySection: some View {
        if isMobilityMatchingEnabled, !mobilityResults.isEmpty {
            // Three questions about a second plan track used to be charged to
            // every lifter who reached this screen, including the ones who came
            // for a squat program and said nothing about mobility at any point.
            // They are now behind a single card that states what it costs, and
            // are asked only of someone who taps it.
            if coordinator.draft.mobilityGoal == nil {
                mobilityInvitation
            } else {
                mobilityResultsList
            }
        }
    }

    private var mobilityInvitation: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Want a mobility plan too?")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Mobility plans run alongside your training, not instead of it. Three quick questions and we’ll rank them.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)

            Button("Find a mobility plan") { isShowingMobilityIntake = true }
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("onboarding-mobility-invitation-open")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-mobility-invitation")
    }

    private var mobilityResultsList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Mobility plans")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityAddTraits(.isHeader)

            Text(mobilitySectionSubtitle)
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(mobilityResults.enumerated()), id: \.element.id) { index, result in
                MobilityRecommendationCard(
                    result: result,
                    isLeading: index == 0 && result.isRunnable && !result.reasons.isEmpty && hasMobilityRankingSignal,
                    action: { onOpenMobilityProgram(result.programID) }
                )
            }

            Button("Change mobility answers") { isShowingMobilityIntake = true }
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymSubduedText)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("onboarding-mobility-change-answers")
        }
        .accessibilityIdentifier("onboarding-mobility-recommendations")
    }

    private var hasMobilityRankingSignal: Bool {
        mobilityResults.contains { !$0.reasons.isEmpty }
    }

    private var mobilitySectionSubtitle: String {
        guard hasMobilityRankingSignal else {
            return String(localized: "You skipped the mobility questions, so this is every mobility plan in its default order.")
        }
        return String(localized: "Ranked from your mobility answers. Every mobility plan is still available to browse.")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("No ready-made plans are installed yet.")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)
            Text("You can still build your own plan, or start training now and set one up later.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("onboarding-recommendations-empty")
    }

    // MARK: Primary action

    /// The one plan the screen is prepared to put its name to, or `nil`.
    ///
    /// `nil` is the honest answer more often than it looks: a lifter who
    /// skipped every question is looking at the catalogue in its default order,
    /// and the top row of an unranked list has done nothing to earn a filled
    /// button. The reasons list is the test, because a result with no stated
    /// reason is precisely one the screen cannot justify.
    private var leadingResult: ProgramMatchResult? {
        guard let first = results.first, first.isRunnable, !first.reasons.isEmpty else { return nil }
        return first
    }

    @ViewBuilder
    private var primaryActionBar: some View {
        if let leadingResult {
            VStack(spacing: 0) {
                // A hairline rather than a shadow or a blur: the bar sits on
                // the same cream as the list, and without an edge the top card
                // scrolling under it reads as the card being clipped.
                Rectangle()
                    .fill(Color.gymBorder)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                Button {
                    onOpenProgram(leadingResult.programID)
                } label: {
                    Text("Set up \(leadingResult.name)")
                        .lineLimit(2)
                }
                .buttonStyle(.gymPrimaryProminent)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.s)
                // Named rather than "Set up plan", so the button is still
                // self-describing once the card it refers to has scrolled away
                // — which is the whole reason it is pinned here.
                .accessibilityLabel("Set up \(leadingResult.name), your best match")
                .accessibilityIdentifier("onboarding-setup-leading-plan")
            }
            .background(Color.gymBackground)
        }
    }

    // MARK: Ways out
    //
    // Three of them, always. A recommendation screen the lifter cannot leave
    // except by accepting a recommendation is not a recommendation screen.

    private var alternatives: some View {
        VStack(spacing: Spacing.s) {
            // With no plans installed, "Browse all plans" led straight back
            // into the catalogue that had just reported itself empty — as the
            // one filled, full-width action on the screen. Training is the
            // thing still available, so it takes the prominent slot instead.
            //
            // When the pinned bar is present it owns the only filled action on
            // the screen, and this one steps down to match: two filled buttons
            // competing at the foot of a list is the hierarchy problem the bar
            // was added to fix, not a second copy of it.
            if results.isEmpty {
                Button("Start a free workout", action: onStartFreeWorkout)
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("onboarding-start-free-workout")
            } else if leadingResult == nil {
                Button("Browse all plans", action: onBrowseAll)
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("onboarding-browse-all")
            } else {
                Button("Browse all plans", action: onBrowseAll)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("onboarding-browse-all")
            }

            Button("Change my answers", action: coordinator.goBack)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymSubduedText)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("onboarding-change-answers")

            // Omitted when it is already the prominent action above, so the
            // identifier stays unique and the screen does not offer the same
            // route twice.
            if !results.isEmpty {
                Button("Start a free workout instead", action: onStartFreeWorkout)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("onboarding-start-free-workout")
            } else {
                Button("Browse all plans", action: onBrowseAll)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("onboarding-browse-all")
            }
        }
        .padding(.top, Spacing.s)
    }
}

/// One ranked plan.
///
/// The reasons are the point. A card that says "Best for you" and nothing else
/// is asking to be trusted; a card that says "supports four sessions a week,
/// uses equipment you selected" is showing its work, and a lifter who disagrees
/// with the reason knows exactly which answer to go back and change.
struct OnboardingRecommendationCard: View {
    let result: ProgramMatchResult
    let isLeading: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // The heading trait lets VoiceOver's rotor jump card to card.
                // Without it the only way through fourteen results was to swipe
                // past every reason and warning on each one.
                Text(result.name)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                // Carried on the card rather than only in a section header,
                // which has scrolled away by the third result.
                //
                // `.gymDestructive` is reserved for `.unsupported` — a build
                // that genuinely cannot run the plan. `.worksWithChanges`
                // means the app compared an answer against a declaration and
                // found a mismatch worth reading first, which is an attention
                // fact, not a hazard; `.gymAccent` is the token this design
                // system already carries for exactly that distinction.
                if let compatibilityTitle = result.compatibilityTitle {
                    GymTagChip(
                        title: compatibilityTitle,
                        systemImage: AppIcon.warningCircle,
                        tint: result.compatibility == .unsupported ? .gymDestructive : .gymAccent
                    )
                    .padding(.top, Spacing.xxs)
                }

                metaLine

                if let summary = result.summary {
                    Text(summary)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xxs)
                }
            }

            if !result.reasons.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Why it matches")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(result.reasons) { reason in
                        Label {
                            Text(reason.text)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.checkmark)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymSecondary)
                        }
                    }
                }
                // One VoiceOver stop for the whole block instead of one per
                // bullet. Four reasons and six warnings turned a single card
                // into twelve swipes with the action at the far end.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(reasonsAccessibilityLabel)
            }

            // Renamed from "Before you start" — that heading now belongs to
            // the prerequisites block below. A mismatch the app found by
            // comparing an answer against a declaration reads differently
            // from a condition the author states and the app cannot check,
            // and reusing one heading for both erased that difference for
            // anyone not distinguishing the two blocks by icon color alone.
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("What doesn’t match")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(result.warnings) { warning in
                        Label {
                            Text(warning.text)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.warningCircle)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymDestructive)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(warningsAccessibilityLabel)
            }

            // A prerequisite is the author disclosing a condition the intake
            // never asked about, not the app reporting a mismatch it found —
            // see `ProgramMatchService`'s prerequisites comment. Rendering it
            // as its own neutral block, with a plain glyph rather than
            // `warningCircle` and body text no darker than the caption above
            // it, is what keeps "can perform the five basic barbell lifts
            // with an empty bar" from reading as a danger next to an actual
            // frequency or equipment mismatch in the block above.
            if !result.prerequisites.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Before you start")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(result.prerequisites) { prerequisite in
                        Label {
                            Text(prerequisite.text)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymSubduedText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.info)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(prerequisitesAccessibilityLabel)
                .accessibilityIdentifier("onboarding-recommendation-prerequisites-\(result.programID.uuidString)")
            }

            planAction
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isLeading ? Color.gymPrimarySurface : Color.gymCard,
            in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(isLeading ? Color.gymPrimary : Color.gymBorder, lineWidth: isLeading ? 1.5 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-recommendation-\(result.programID.uuidString)")
    }

    /// Filled on the one leading result, outlined everywhere else. Both open
    /// the same screen — the plan's own detail, where activation already lives
    /// — so the difference in weight is about ranking, not about two different
    /// destinations.
    @ViewBuilder
    private var planAction: some View {
        if result.compatibility == .unsupported {
            // A statement, not a dimmed button. A control that cannot be
            // activated is worse than no control: it invites the tap, absorbs
            // it silently, and announces itself to VoiceOver as "View plan,
            // dimmed" with nothing nearby explaining why.
            Text("Update Trame to use this plan")
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(actionIdentifier)
        } else if isLeading {
            Button("Set up this plan", action: action)
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier(actionIdentifier)
        } else {
            Button(action: action) {
                Text("View plan")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .stroke(Color.gymBorder, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .opacity(result.compatibility == .unsupported ? 0.5 : 1)
            .disabled(result.compatibility == .unsupported)
            .accessibilityIdentifier(actionIdentifier)
        }
    }

    /// The bullets, spoken as one sentence. Built outside the string literal
    /// so the joining separator is not fighting Swift's interpolation escaping.
    private var reasonsAccessibilityLabel: String {
        let joined = result.reasons.map(\.text).joined(separator: ", ")
        return String(localized: "Why it matches: \(joined)")
    }

    private var warningsAccessibilityLabel: String {
        let joined = result.warnings.map(\.text).joined(separator: ", ")
        return String(localized: "What doesn’t match: \(joined)")
    }

    private var prerequisitesAccessibilityLabel: String {
        let joined = result.prerequisites.map(\.text).joined(separator: ", ")
        return String(localized: "Before you start: \(joined)")
    }

    private var actionIdentifier: String {
        "onboarding-open-plan-\(result.programID.uuidString)"
    }

    /// Three facts on one line normally, one per line at accessibility sizes.
    ///
    /// The middot separators only read as separators while the line holds. Once
    /// each fact wraps, "Intermediate · 3/4 days/week · 12 weeks" becomes a
    /// four-line run-on whose breaks land mid-fact, and the middots turn into
    /// punctuation the lifter has to parse around.
    @ViewBuilder
    private var metaLine: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(metaComponents, id: \.self) { component in
                    Text(component)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(AppFont.footnote)
            .foregroundStyle(Color.gymSubduedText)
            // Still one VoiceOver stop, so stacking does not turn one line of
            // supporting detail into three swipes on every card.
            .accessibilityElement(children: .combine)
        } else {
            Text(metaComponents.joined(separator: " · "))
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private var metaComponents: [String] {
        let days = result.supportedDaysPerWeek.map(String.init).joined(separator: "/")
        return [
            result.experienceLevel.onboardingTitle,
            String(localized: "\(days) days/week"),
            String(localized: "\(result.durationWeeks) weeks")
        ]
    }
}

/// One ranked mobility plan. Deliberately a near-twin of
/// `OnboardingRecommendationCard` rather than a shared generic: the two
/// result types come from independent matching services with different
/// vocabularies (`PlanExperienceLevel` vs. `MobilityMatchExperienceLevel`,
/// `compatibility` vs. a plain `isRunnable`), and forcing them through one
/// generic view would either leak one domain's types into the other's card or
/// erase the "why it matches" wording that is this whole screen's point.
struct MobilityRecommendationCard: View {
    let result: MobilityMatchResult
    let isLeading: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(result.name)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                // Mirrors `OnboardingRecommendationCard`'s badge tint choice:
                // `.gymDestructive` is reserved for a plan this build cannot
                // run at all, not for an attention fact the app derived by
                // comparing an answer against a declaration.
                if let compatibilityTitle = result.compatibilityTitle {
                    GymTagChip(
                        title: compatibilityTitle,
                        systemImage: AppIcon.warningCircle,
                        tint: result.isRunnable ? .gymAccent : .gymDestructive
                    )
                    .padding(.top, Spacing.xxs)
                }

                metaLine

                if let summary = result.summary {
                    Text(summary)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xxs)
                }
            }

            if !result.reasons.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Why it matches")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(result.reasons) { reason in
                        Label {
                            Text(reason.text)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.checkmark)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(reasonsAccessibilityLabel)
            }

            // Renamed from "Before you start" for the same reason as the
            // workout card: that heading now belongs to the prerequisites
            // block below, and a mismatch the app found needs to read
            // differently from a condition the author states unverified.
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("What doesn’t match")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(result.warnings) { warning in
                        Label {
                            Text(warning.text)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.warningCircle)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymDestructive)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(warningsAccessibilityLabel)
            }

            // Mirrors the workout card's prerequisites block: author-stated,
            // intake-unverifiable conditions, disclosed on their own neutral
            // block rather than folded into `warnings` — see
            // `MobilityMatchService`'s prerequisites comment.
            if !result.prerequisites.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Before you start")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(result.prerequisites) { prerequisite in
                        Label {
                            Text(prerequisite.text)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymSubduedText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.info)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(prerequisitesAccessibilityLabel)
                .accessibilityIdentifier("onboarding-mobility-recommendation-prerequisites-\(result.programID.uuidString)")
            }

            planAction
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isLeading ? Color.gymPrimarySurface : Color.gymCard,
            in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(isLeading ? Color.gymPrimary : Color.gymBorder, lineWidth: isLeading ? 1.5 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-mobility-recommendation-\(result.programID.uuidString)")
    }

    @ViewBuilder
    private var planAction: some View {
        if !result.isRunnable {
            Text("Update Trame to use this plan")
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(actionIdentifier)
        } else if isLeading {
            Button("Set up this plan", action: action)
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier(actionIdentifier)
        } else {
            Button(action: action) {
                Text("View plan")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .stroke(Color.gymBorder, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier(actionIdentifier)
        }
    }

    private var reasonsAccessibilityLabel: String {
        let joined = result.reasons.map(\.text).joined(separator: ", ")
        return String(localized: "Why it matches: \(joined)")
    }

    private var warningsAccessibilityLabel: String {
        let joined = result.warnings.map(\.text).joined(separator: ", ")
        return String(localized: "What doesn’t match: \(joined)")
    }

    private var prerequisitesAccessibilityLabel: String {
        let joined = result.prerequisites.map(\.text).joined(separator: ", ")
        return String(localized: "Before you start: \(joined)")
    }

    private var actionIdentifier: String {
        "onboarding-open-mobility-plan-\(result.programID.uuidString)"
    }

    @ViewBuilder
    private var metaLine: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(metaComponents, id: \.self) { component in
                    Text(component)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(AppFont.footnote)
            .foregroundStyle(Color.gymSubduedText)
            .accessibilityElement(children: .combine)
        } else {
            Text(metaComponents.joined(separator: " · "))
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private var metaComponents: [String] {
        let days = result.supportedDaysPerWeek.map(String.init).joined(separator: "/")
        return [
            result.experienceLevel.title,
            String(localized: "\(days) days/week"),
            String(localized: "\(result.durationWeeks) weeks")
        ]
    }
}

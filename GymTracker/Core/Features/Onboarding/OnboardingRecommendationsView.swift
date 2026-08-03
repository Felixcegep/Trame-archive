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
        .accessibilityIdentifier("onboarding-recommendations")
        .task {
            // Guarded so returning from a pushed plan detail does not re-rank
            // and reshuffle the list the lifter was reading.
            guard !hasLoaded else { return }
            hasLoaded = true
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
            if UIAccessibility.isVoiceOverRunning {
                isHeadingFocused = true
            }
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
            return String(localized: "You skipped the questions, so this is every plan in its default order. Answer a few and we’ll rank them.")
        }
        return String(localized: "Ranked from your answers. Every plan in the app is still available to browse.")
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

                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    OnboardingRecommendationCard(
                        result: result,
                        // Only the single best match gets a filled action, and
                        // only when it can say why it is the best match. A
                        // prominent "Set up this plan" on a card with no stated
                        // reason is the "trust me" recommendation this screen
                        // exists to avoid — which is exactly what a lifter who
                        // skipped every question used to be handed.
                        isLeading: index == 0 && result.isRunnable && !result.reasons.isEmpty,
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
            }
            .accessibilityIdentifier("onboarding-mobility-recommendations")
        }
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
            if results.isEmpty {
                Button("Start a free workout", action: onStartFreeWorkout)
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("onboarding-start-free-workout")
            } else {
                Button("Browse all plans", action: onBrowseAll)
                    .buttonStyle(.gymPrimary)
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
                if let compatibilityTitle = result.compatibilityTitle {
                    GymTagChip(
                        title: compatibilityTitle,
                        systemImage: AppIcon.warningCircle,
                        tint: .gymDestructive
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
                                .font(AppFont.caption2Bold)
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

            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Before you start")
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
                                .font(AppFont.caption2Bold)
                                .foregroundStyle(Color.gymDestructive)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(warningsAccessibilityLabel)
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

                if let compatibilityTitle = result.compatibilityTitle {
                    GymTagChip(
                        title: compatibilityTitle,
                        systemImage: AppIcon.warningCircle,
                        tint: .gymDestructive
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
                                .font(AppFont.caption2Bold)
                                .foregroundStyle(Color.gymSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(reasonsAccessibilityLabel)
            }

            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Before you start")
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
                                .font(AppFont.caption2Bold)
                                .foregroundStyle(Color.gymDestructive)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(warningsAccessibilityLabel)
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

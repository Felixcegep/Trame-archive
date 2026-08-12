import SwiftData
import SwiftUI

/// The evidence-first landing content for the Progress tab.
///
/// Progress used to open on a list of destinations, which asked the lifter to
/// guess which screen answered their question. This answers the common ones in
/// place — how much did I train, what did I just hit, is anything moving — and
/// every card is a link into the screen that holds the full evidence. Nothing
/// here recomputes domain truth: the numbers come from the analytics services,
/// which own the date bounds, unit normalisation and historical identity.
struct ProgressOverviewSection: View {
    let range: AnalyticsDateRange
    let state: ProgressOverviewState
    var onOpenPlan: ((UUID) -> Void)? = nil

    var body: some View {
        switch state {
        case .loading:
            loadingCard
        case .failed:
            failedCard
        case .empty:
            emptyCard
        case let .loaded(summary):
            loadedCards(summary)
        }
    }

    /// Figures first, doors second.
    ///
    /// Every one of these was previously an icon chip + title + subtitle +
    /// chevron — the *same component* the eleven navigation rows below use. An
    /// insight drawn as a link is a link, so the section that was supposed to
    /// answer "how am I doing" read as another directory to choose from. The
    /// two answers a lifter actually opens Progress for — how much did I train,
    /// what did I just hit — are now figures on a card, sized to be read from
    /// across a gym rather than tapped.
    ///
    /// The rows that remain are the ones that genuinely are navigation: a plan
    /// lives in another tab, and mobility and the journey are narratives rather
    /// than numbers.
    @ViewBuilder
    private func loadedCards(_ summary: ProgressOverviewSummary) -> some View {
        weekHeroCard(summary)
        highlightTiles(summary)
        if summary.currentPlanID != nil {
            currentPlanCard(summary)
        }
        mobilityCard(summary)
        journeyCard(summary)
    }

    // MARK: - Hero

    /// The week as a figure, not a sentence.
    private func weekHeroCard(_ summary: ProgressOverviewSummary) -> some View {
        NavigationLink(value: ProgressRoute.workoutHistory) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                eyebrow("This week")

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                    figure(
                        "\(summary.workoutsThisWeek)",
                        caption: CountPhrase.completedWorkouts(summary.workoutsThisWeek)
                    )

                    if let time = summary.trainingTimeThisWeekText {
                        figure(time, caption: String(localized: "trained"))
                    }

                    Spacer(minLength: 0)
                }

                if let takeaway = summary.consistencyTakeaway {
                    Divider().overlay(Color.gymBorder)

                    Text(takeaway)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(overviewSurface)
        }
        .buttonStyle(.plain)
        .overviewRowChrome(identifier: "current-period")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weekAccessibilityLabel(summary))
        .accessibilityAddTraits(.isButton)
    }

    /// A value and what it counts, stacked. Monospaced so two of them sitting
    /// side by side share a baseline grid instead of drifting as digits change.
    private func figure(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(AppFont.displayMedium)
                .monospacedDigit()
                .foregroundStyle(Color.gymText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .lineLimit(1)
        }
    }

    private func weekAccessibilityLabel(_ summary: ProgressOverviewSummary) -> String {
        var parts = [
            String(localized: "This week."),
            CountPhrase.completedWorkouts(summary.workoutsThisWeek) + "."
        ]
        if let time = summary.trainingTimeThisWeekText {
            parts.append(String(localized: "\(time) trained."))
        }
        if let takeaway = summary.consistencyTakeaway {
            parts.append(takeaway)
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Highlight tiles

    /// Latest record and most-logged exercise, side by side.
    ///
    /// Two tiles or one full-width tile — never a tile beside a gap. A lifter
    /// with no records yet gets the trend at full width rather than a lonely
    /// card with an empty neighbour.
    @ViewBuilder
    private func highlightTiles(_ summary: ProgressOverviewSummary) -> some View {
        let hasRecord = summary.latestRecord != nil
        let hasSeries = summary.featuredSeries != nil

        if hasRecord || hasSeries {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.m) {
                    tileContent(summary)
                }
                VStack(spacing: Spacing.m) {
                    tileContent(summary)
                }
            }
            // Deliberately unnamed — the two tiles inside publish their own
            // identifiers, and a container identifier would replace them.
            .overviewRowChrome(identifier: nil)
        }
    }

    @ViewBuilder
    private func tileContent(_ summary: ProgressOverviewSummary) -> some View {
        if let record = summary.latestRecord {
            tile(
                route: .records,
                identifier: "latest-record",
                label: String(localized: "Latest record"),
                value: record.displayValue,
                caption: "\(record.exerciseName) · \(record.kind)"
            )
        }
        if let series = summary.featuredSeries {
            tile(
                route: .trainingTrends,
                identifier: "exercise-trend",
                label: String(localized: "Most logged"),
                value: series.name,
                caption: series.quality == .sparse
                    ? String(localized: "Not enough sessions yet to read as a trend")
                    : sessionCountText(series)
            )
        }
    }

    private func tile(
        route: ProgressRoute,
        identifier: String,
        label: String,
        value: String,
        caption: String
    ) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                eyebrow(label)

                Text(value)
                    .font(AppFont.titleSmallSemibold)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text(caption)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(overviewSurface)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(value). \(caption)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("progress-overview-\(identifier)")
    }

    // MARK: - Shared chrome

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(AppFont.captionBold)
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.gymSubduedText)
    }

    /// Card fill plus the hairline the dark scheme depends on — `gymCard` sits
    /// close enough to `gymBackground` in both schemes that the stroke, not the
    /// fill, is what separates a tile from the page.
    private var overviewSurface: some View {
        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
            .fill(Color.gymCard)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
    }

    /// Last card by intent. The cards above answer "how am I doing now"; this
    /// one opens the long view, which is a different question and should not
    /// compete with the immediate ones for attention.
    // MARK: - Journey preview

    private func journeyCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewRow(
            route: .trainingJourney,
            identifier: "journey",
            title: "Journey"
        ) {
            if let latest = summary.latestChapterTitle {
                Text(latest)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymText)
            }
            Text(summary.journeySummaryText)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Current plan

    private func currentPlanCard(_ summary: ProgressOverviewSummary) -> some View {
        guard let planID = summary.currentPlanID, let name = summary.currentPlanName else {
            return AnyView(EmptyView())
        }
        return AnyView(
            Button {
                onOpenPlan?(planID)
            } label: {
                HStack(spacing: Spacing.m) {
                    GymIconChip(systemImage: AppIcon.plan, tint: .gymPrimary)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Current plan")
                            .font(AppFont.captionBold)
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.gymSubduedText)
                        Text(name)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        if let phase = summary.currentPlanPhaseText {
                            Text(phase)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: 0, bottom: Spacing.xs, trailing: 0))
            .accessibilityIdentifier("progress-overview-current-plan")
        )
    }

    private func sessionCountText(_ series: ExerciseProgressSeries) -> String {
        let count = max(series.loadPoints.count, max(series.volumePoints.count, series.repsPoints.count))
        return CountPhrase.recordedSessions(count)
    }

    // MARK: - Mobility

    private func mobilityCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewRow(
            route: .supportingHistory(.mobility),
            identifier: "mobility",
            title: "Mobility"
        ) {
            let sessionText = CountPhrase.sessions(summary.mobilitySessionsInRange)
            Text(verbatim: "\(sessionText) · \(summary.assessmentRecencyText)")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - States

    private var loadingCard: some View {
        HStack(spacing: Spacing.m) {
            ProgressView()
            Text("Reading your history…")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityIdentifier("progress-overview-loading")
    }

    private var failedCard: some View {
        HStack(spacing: Spacing.m) {
            GymIconChip(systemImage: AppIcon.warning, tint: .gymAccent)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Summary unavailable")
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text("Your history could not be read just now. The screens below still open your full records.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityIdentifier("progress-overview-failed")
    }

    private var emptyCard: some View {
        HStack(spacing: Spacing.m) {
            GymIconChip(systemImage: AppIcon.history, tint: .gymPrimary)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("No completed workouts yet")
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text("Finish a workout and this is where its records, trends and weekly totals appear.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityIdentifier("progress-overview-empty")
    }

    // MARK: - Building blocks

    /// Icon and tint come from the route, never from the call site.
    ///
    /// They used to be arguments, and the two screens that draw the same routes
    /// disagreed about them: "Latest record" wore a green trophy here while
    /// "Records" wore a blue one in the hub below, for the same destination.
    /// Colour is supposed to carry meaning in this app, so a destination gets
    /// exactly one.
    private func overviewRow<Content: View>(
        route: ProgressRoute,
        identifier: String,
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Spacing.m) {
                GymIconChip(systemImage: route.icon, tint: route.tint)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    content()
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .overviewRowChrome(identifier: identifier)
    }
}

private extension View {
    /// The list-row reset every overview item needs so a card can draw its own
    /// surface instead of inheriting the grouped one.
    ///
    /// - Parameter identifier: `nil` for a container holding its own
    ///   individually identified children. An identifier applied to a container
    ///   replaces the ones its children publish, so naming the tile row would
    ///   make both tiles unaddressable from a UI test.
    @ViewBuilder
    func overviewRowChrome(identifier: String?) -> some View {
        let reset = listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: 0, bottom: Spacing.xs, trailing: 0))

        if let identifier {
            reset.accessibilityIdentifier("progress-overview-\(identifier)")
        } else {
            reset
        }
    }
}

// MARK: - State

enum ProgressOverviewState: Equatable {
    case loading
    case failed
    /// No completed workouts in range — distinct from `failed`, which means the
    /// store could not be read at all.
    case empty
    case loaded(ProgressOverviewSummary)
}

struct ProgressOverviewSummary: Equatable {
    var workoutsThisWeek: Int
    var trainingTimeThisWeekText: String?
    var consistencyTakeaway: String?
    var currentPlanID: UUID?
    var currentPlanName: String?
    var currentPlanPhaseText: String?
    var latestRecord: PersonalRecordItem?
    var featuredSeries: ExerciseProgressSeries?
    var mobilitySessionsInRange: Int
    var assessmentRecencyText: String
    /// The most recent chapter's name, nil when nothing has been recorded yet.
    var latestChapterTitle: String?
    var journeySummaryText: String
}

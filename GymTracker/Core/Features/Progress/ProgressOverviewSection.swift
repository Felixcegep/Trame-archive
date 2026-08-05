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

    @ViewBuilder
    private func loadedCards(_ summary: ProgressOverviewSummary) -> some View {
        currentPeriodCard(summary)
        if summary.currentPlanID != nil {
            currentPlanCard(summary)
        }
        if let record = summary.latestRecord {
            recordCard(record)
        }
        if let series = summary.featuredSeries {
            trendCard(series)
        }
        mobilityCard(summary)
        journeyCard(summary)
    }

    // MARK: - Journey preview

    /// Last card by intent. The cards above answer "how am I doing now"; this
    /// one opens the long view, which is a different question and should not
    /// compete with the immediate ones for attention.
    private func journeyCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewCard(
            route: .trainingJourney,
            identifier: "journey",
            icon: AppIcon.journey,
            tint: .gymAccent,
            title: "Journey"
        ) {
            if let latest = summary.latestChapterTitle {
                Text(latest)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
            }
            Text(summary.journeySummaryText)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Current period

    private func currentPeriodCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewCard(
            route: .workoutHistory,
            identifier: "current-period",
            icon: AppIcon.history,
            tint: .gymPrimary,
            title: "This week"
        ) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                metric(
                    value: "\(summary.workoutsThisWeek)",
                    unit: summary.workoutsThisWeek == 1 ? "workout" : "workouts"
                )
                if let duration = summary.trainingTimeThisWeekText {
                    metric(value: duration, unit: "training time")
                }
            }

            // Comparison is stated only when there is enough history to make
            // one meaningful. `AnalyticsDataQuality` decides that, not a
            // count threshold invented here.
            if let takeaway = summary.consistencyTakeaway {
                Text(takeaway)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                GymCard {
                    HStack(spacing: Spacing.m) {
                        GymIconChip(systemImage: AppIcon.plan, tint: .gymPrimary)
                        Text("Current Plan")
                            .font(AppFont.captionBold)
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.gymSubduedText)
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(name)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        if let phase = summary.currentPlanPhaseText {
                            Text(phase)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress-overview-current-plan")
        )
    }

    // MARK: - Latest record

    private func recordCard(_ record: PersonalRecordItem) -> some View {
        overviewCard(
            route: .records,
            identifier: "latest-record",
            icon: AppIcon.trophy,
            tint: .gymSecondary,
            title: "Latest record"
        ) {
            Text(record.exerciseName)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            // `displayValue` is already unit-qualified ("50.0 kg"). Passing
            // `record.unit` as well rendered "50.0 kg kg".
            GymMetricValue(value: record.displayValue, unit: "")
            Text("\(record.kind) · \(record.date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    // MARK: - Exercise trend

    private func trendCard(_ series: ExerciseProgressSeries) -> some View {
        overviewCard(
            route: .trainingTrends,
            identifier: "exercise-trend",
            icon: AppIcon.progression,
            tint: .gymAccent,
            title: "Most logged"
        ) {
            Text(series.name)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)

            // Deliberately not a chart. This card routes to the trends screen,
            // which draws the series properly with axes and selection; a
            // thumbnail chart here would be unreadable and duplicate it.
            Text(sessionCountText(series))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)

            if series.quality == .sparse {
                Text("Not enough sessions yet to read this as a trend.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sessionCountText(_ series: ExerciseProgressSeries) -> String {
        let count = max(series.loadPoints.count, max(series.volumePoints.count, series.repsPoints.count))
        return count == 1 ? "1 recorded session" : "\(count) recorded sessions"
    }

    // MARK: - Mobility

    private func mobilityCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewCard(
            route: .mobilityHistory,
            identifier: "mobility",
            icon: AppIcon.mobility,
            tint: .gymSecondary,
            title: "Mobility"
        ) {
            metric(
                value: "\(summary.mobilitySessionsInRange)",
                unit: summary.mobilitySessionsInRange == 1 ? "session" : "sessions"
            )
            Text(summary.assessmentRecencyText)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - States

    private var loadingCard: some View {
        GymCard {
            HStack(spacing: Spacing.m) {
                ProgressView()
                Text("Reading your history…")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .accessibilityIdentifier("progress-overview-loading")
    }

    /// A read failure is stated rather than rendered as zeroes. Showing "0
    /// workouts" when the fetch failed would be a lie the lifter cannot detect.
    private var failedCard: some View {
        GymCard {
            GymSectionHeader(
                title: "Summary unavailable",
                detail: "Your history could not be read just now. The screens below still open your full records.",
                systemImage: AppIcon.warning
            )
        }
        .accessibilityIdentifier("progress-overview-failed")
    }

    private var emptyCard: some View {
        GymCard {
            GymSectionHeader(
                title: "No completed workouts yet",
                detail: "Finish a workout and this is where its records, trends and weekly totals appear.",
                systemImage: AppIcon.history
            )
        }
        .accessibilityIdentifier("progress-overview-empty")
    }

    // MARK: - Building blocks

    private func metric(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.gymText)
            Text(unit)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(unit)")
    }

    /// Every overview card is a link. The plan for this screen is explicit that
    /// a card which cannot reach its own evidence does not ship, so the card
    /// surface itself is the tap target rather than a separate "see more" row.
    private func overviewCard<Content: View>(
        route: ProgressRoute,
        identifier: String,
        icon: String,
        tint: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationLink(value: route) {
            GymCard {
                // No chevron drawn here: a `NavigationLink` inside a `List`
                // already supplies the platform disclosure indicator, and
                // adding one produced two arrows per card.
                HStack(spacing: Spacing.m) {
                    GymIconChip(systemImage: icon, tint: tint)
                    Text(title)
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.gymSubduedText)
                    Spacer(minLength: 0)
                }
                content()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("progress-overview-\(identifier)")
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

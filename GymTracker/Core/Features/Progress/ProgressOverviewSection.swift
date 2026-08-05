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
        if let record = summary.latestRecord {
            recordCard(record)
        }
        if let series = summary.featuredSeries {
            trendCard(series)
        }
        mobilityCard(summary)
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
    var latestRecord: PersonalRecordItem?
    var featuredSeries: ExerciseProgressSeries?
    var mobilitySessionsInRange: Int
    var assessmentRecencyText: String
}

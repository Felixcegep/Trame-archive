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
    // MARK: - Journey preview

    private func journeyCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewRow(
            route: .trainingJourney,
            identifier: "journey",
            icon: AppIcon.journey,
            tint: .gymAccent,
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

    // MARK: - Current period

    private func currentPeriodCard(_ summary: ProgressOverviewSummary) -> some View {
        overviewRow(
            route: .workoutHistory,
            identifier: "current-period",
            icon: AppIcon.history,
            tint: .gymPrimary,
            title: "This week"
        ) {
            let countText = countDescription(summary.workoutsThisWeek, singular: "completed workout")
            let detailText = summary.trainingTimeThisWeekText.map { "\(countText) · \($0)" } ?? countText
            Text(detailText)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)

            if let takeaway = summary.consistencyTakeaway {
                Text(takeaway)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func countDescription(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
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
                    Image(systemName: "chevron.right")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress-overview-current-plan")
        )
    }

    // MARK: - Latest record

    private func recordCard(_ record: PersonalRecordItem) -> some View {
        overviewRow(
            route: .records,
            identifier: "latest-record",
            icon: AppIcon.trophy,
            tint: .gymSecondary,
            title: "Latest record"
        ) {
            Text("\(record.exerciseName) — \(record.displayValue)")
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymText)
            Text("\(record.kind) · \(record.date.formatted(date: .abbreviated, time: .omitted))")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    // MARK: - Exercise trend

    private func trendCard(_ series: ExerciseProgressSeries) -> some View {
        overviewRow(
            route: .trainingTrends,
            identifier: "exercise-trend",
            icon: AppIcon.progression,
            tint: .gymAccent,
            title: "Most logged"
        ) {
            Text("\(series.name) · \(sessionCountText(series))")
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
        overviewRow(
            route: .mobilityHistory,
            identifier: "mobility",
            icon: AppIcon.mobility,
            tint: .gymSecondary,
            title: "Mobility"
        ) {
            let sessionText = summary.mobilitySessionsInRange == 1 ? "1 session" : "\(summary.mobilitySessionsInRange) sessions"
            Text("\(sessionText) · \(summary.assessmentRecencyText)")
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

    private func overviewRow<Content: View>(
        route: ProgressRoute,
        identifier: String,
        icon: String,
        tint: Color,
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Spacing.m) {
                GymIconChip(systemImage: icon, tint: tint)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    content()
                }
            }
            .padding(.vertical, Spacing.xs)
        }
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

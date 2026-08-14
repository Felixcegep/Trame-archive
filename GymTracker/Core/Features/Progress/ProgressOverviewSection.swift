import Charts
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
    var onNavigate: (ProgressRoute) -> Void = { _ in }
    var presentation: ProgressOverviewPresentation = .all

    @ViewBuilder
    var body: some View {
        switch state {
        case .loading:
            if presentation != .insights { loadingCard }
        case .failed:
            if presentation != .insights { failedCard }
        case .empty:
            if presentation != .insights { emptyCard }
        case let .loaded(summary):
            switch presentation {
            case .weekly:
                weekHeroCard(summary)
            case .insights:
                insightCards(summary)
            case .all:
                weekHeroCard(summary)
                insightCards(summary)
            }
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
    private func insightCards(_ summary: ProgressOverviewSummary) -> some View {
        performanceDashboardCard(summary)
        if summary.currentPlanID != nil {
            currentPlanCard(summary)
        }
        mobilityCard(summary)
        journeyCard(summary)
    }

    // MARK: - Hero

    /// The week as a figure, not a sentence.
    private func weekHeroCard(_ summary: ProgressOverviewSummary) -> some View {
        Button {
            onNavigate(.workoutHistory)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        eyebrow("Training rhythm")
                        Text("This week")
                            .font(AppFont.titleSmallSemibold)
                            .foregroundStyle(Color.gymText)
                    }
                    Spacer(minLength: Spacing.m)
                    Text("History")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymPrimary)
                }

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                    figure(
                        "\(summary.workoutsThisWeek)",
                        caption: String(localized: "workouts")
                    )

                    if let time = summary.trainingTimeThisWeekText {
                        figure(time, caption: String(localized: "trained"))
                    }

                    Spacer(minLength: 0)
                }

                weeklyFrequencyChart(summary.weeklyFrequency)
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

    @ViewBuilder
    private func weeklyFrequencyChart(_ points: [WeeklyFrequencyPoint]) -> some View {
        if !points.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text("Last 8 weeks")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Completed workouts", point.workoutCount),
                        width: .ratio(0.56)
                    )
                    .foregroundStyle(
                        point.id == points.last?.id
                            ? Color.gymPrimary
                            : (point.workoutCount == 0 ? Color.gymBorder : Color.gymPrimary.opacity(0.35))
                    )
                    .cornerRadius(Radius.medium)
                }
                .chartYScale(domain: 0...max(1, points.map(\.workoutCount).max() ?? 1))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot
                        .background(Color.gymPrimarySurface.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                }
                .frame(height: ComponentSize.overviewChartHeight)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(weeklyFrequencyAccessibilityLabel(points))
            .accessibilityIdentifier("progress-overview-weekly-frequency-chart")
        }
    }

    private func weeklyFrequencyAccessibilityLabel(_ points: [WeeklyFrequencyPoint]) -> String {
        let values = points.map {
            "\($0.weekStart.formatted(.dateTime.month(.abbreviated).day())): \(CountPhrase.completedWorkouts($0.workoutCount))"
        }
        return String(localized: "Completed workouts over the last eight weeks. \(values.joined(separator: ", "))")
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
        return parts.joined(separator: " ")
    }

    // MARK: - Performance dashboard

    /// Oura's best trend screens make one graph the subject and keep the
    /// supporting numbers attached to it. The previous layout turned the same
    /// exercise into a "Most logged" card and a second chart card, with a
    /// detached list chevron beside both. This is one evidence panel with two
    /// compact entry points and no list accessory column.
    @ViewBuilder
    private func performanceDashboardCard(_ summary: ProgressOverviewSummary) -> some View {
        if summary.latestRecord != nil || summary.featuredSeries != nil {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    eyebrow("Performance")
                    Text("Exercise progress")
                        .font(AppFont.titleSmallSemibold)
                        .foregroundStyle(Color.gymText)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        performanceMetrics(summary)
                    }
                    VStack(spacing: Spacing.s) {
                        performanceMetrics(summary)
                    }
                }

                if let series = summary.featuredSeries,
                   let projection = featuredTrendProjection(series),
                   projection.points.count >= 2 {
                    Divider().overlay(Color.gymBorder)
                    featuredTrendDiagram(series, projection: projection)
                }
            }
            .padding(Spacing.l)
            .background(overviewSurface)
            .overviewRowChrome(identifier: nil)
        }
    }

    @ViewBuilder
    private func performanceMetrics(_ summary: ProgressOverviewSummary) -> some View {
        if let record = summary.latestRecord,
           shouldShowRecordMetric(record, summary: summary) {
            performanceMetric(
                route: .records,
                identifier: "latest-record",
                label: String(localized: "Latest record"),
                value: record.displayValue,
                caption: "\(record.exerciseName) · \(record.kind)",
                tint: .gymSecondary,
                surface: .gymSecondarySurface
            )
        }
        if let series = summary.featuredSeries,
           (featuredTrendProjection(series)?.points.count ?? 0) < 2 {
            performanceMetric(
                route: .trainingTrends,
                identifier: "exercise-trend",
                label: String(localized: "Most logged"),
                value: series.name,
                caption: series.quality == .sparse
                    ? String(localized: "Early evidence")
                    : sessionCountText(series),
                tint: .gymPrimary,
                surface: .gymPrimarySurface
            )
        }
    }

    private func shouldShowRecordMetric(
        _ record: PersonalRecordItem,
        summary: ProgressOverviewSummary
    ) -> Bool {
        guard let series = summary.featuredSeries,
              (featuredTrendProjection(series)?.points.count ?? 0) >= 2 else {
            return true
        }
        return series.name != record.exerciseName
    }

    private func performanceMetric(
        route: ProgressRoute,
        identifier: String,
        label: String,
        value: String,
        caption: String,
        tint: Color,
        surface: Color
    ) -> some View {
        Button {
            onNavigate(route)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label)
                    .font(AppFont.captionBold)
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
                Text(value)
                    .font(AppFont.titleSmallSemibold)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(caption)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(surface.opacity(0.72))
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(value). \(caption)")
        .accessibilityHint("Opens full evidence")
        .accessibilityIdentifier("progress-overview-\(identifier)")
    }

    private func featuredTrendDiagram(
        _ series: ExerciseProgressSeries,
        projection: (label: String, points: [ExerciseProgressPoint])
    ) -> some View {
        let first = projection.points[0]
        let latest = projection.points[projection.points.count - 1]
        let usesTimeLabels = Calendar.current.isDate(first.date, inSameDayAs: latest.date)
        let maximum = projection.points.map(\.value).max() ?? 1
        let upperBound = max(Float(1), maximum * 1.12)

        return Button {
            onNavigate(.trainingTrends)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        eyebrow(projection.points.count >= 4 ? "Exercise trend" : "Early comparison")
                        Text(series.name)
                            .font(AppFont.titleSmallSemibold)
                            .foregroundStyle(Color.gymText)
                    }
                    Spacer(minLength: Spacing.m)
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text(latest.value.formatted(.number.precision(.fractionLength(0...1))))
                            .font(AppFont.titleSmallSemiboldMonospaced)
                            .foregroundStyle(Color.gymText)
                        Text(projection.label)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .lineLimit(1)
                    }
                }

                Chart(projection.points) { point in
                    // An area implies continuity. Reserve it for an actual
                    // multi-session trend; two points are only a comparison.
                    if projection.points.count >= 4 {
                        AreaMark(
                            x: .value("Session", point.date),
                            y: .value(projection.label, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gymPrimary.opacity(0.22), Color.gymPrimary.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.linear)
                    }

                    LineMark(
                        x: .value("Session", point.date),
                        y: .value(projection.label, point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value("Session", point.date),
                        y: .value(projection.label, point.value)
                    )
                    .symbolSize(point.id == latest.id ? 72 : 34)
                    .foregroundStyle(
                        point.id == latest.id
                            ? Color.gymPrimary
                            : Color.gymPrimary.opacity(0.55)
                    )
                }
                .chartYScale(domain: Float.zero...upperBound)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.gymBorder)
                        AxisValueLabel()
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .chartLegend(.hidden)
                .frame(
                    height: projection.points.count >= 4
                        ? ComponentSize.progressDashboardChartHeight
                        : ComponentSize.overviewChartHeight
                )
                .accessibilityHidden(true)

                HStack {
                    Text("Earlier · \(featuredSessionLabel(first.date, usesTime: usesTimeLabels))")
                    Spacer(minLength: Spacing.s)
                    Text("Latest · \(featuredSessionLabel(latest.date, usesTime: usesTimeLabels))")
                }
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)

            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(featuredTrendAccessibilityLabel(series, projection: projection))
        .accessibilityHint("Opens exercise trends")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("progress-overview-featured-trend-chart")
    }

    private func featuredTrendProjection(
        _ series: ExerciseProgressSeries
    ) -> (label: String, points: [ExerciseProgressPoint])? {
        if series.loadPoints.count >= 2 {
            return (
                String(localized: "Best load (\(series.unit))"),
                series.loadPoints.sorted { $0.date < $1.date }
            )
        }
        if series.volumePoints.count >= 2 {
            return (
                String(localized: "Session volume (\(series.unit))"),
                series.volumePoints.sorted { $0.date < $1.date }
            )
        }
        if series.repsPoints.count >= 2 {
            return (
                String(localized: "Completed repetitions"),
                series.repsPoints.sorted { $0.date < $1.date }
            )
        }
        return nil
    }

    private func featuredTrendAccessibilityLabel(
        _ series: ExerciseProgressSeries,
        projection: (label: String, points: [ExerciseProgressPoint])
    ) -> String {
        guard let first = projection.points.first, let last = projection.points.last else {
            return series.name
        }
        return String(
            localized: "\(series.name), \(projection.label). \(projection.points.count) comparable sessions. First \(first.value.formatted()), latest \(last.value.formatted()). Opens exercise trends."
        )
    }

    private func featuredSessionLabel(_ date: Date, usesTime: Bool) -> String {
        if usesTime {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
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

    @ViewBuilder
    private func currentPlanCard(_ summary: ProgressOverviewSummary) -> some View {
        if let planID = summary.currentPlanID, let name = summary.currentPlanName {
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
        }
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

enum ProgressOverviewPresentation {
    case weekly
    case insights
    case all
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
    var weeklyFrequency: [WeeklyFrequencyPoint]
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

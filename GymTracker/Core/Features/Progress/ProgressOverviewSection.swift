import Charts
import SwiftUI

/// The evidence-first Global lens for Progress.
///
/// Every value is supplied by an existing analytics projection. This view only
/// composes those facts and keeps exact values, periods, and source routes
/// available beside the visual summaries.
///
/// Diagram specification — cadence:
/// QUESTION: What rhythm of completed training was recorded over eight weeks?
/// DATA: `WeeklyFrequencyPoint`; every represented week remains present, and a
/// zero-work week is distinct from an unavailable series.
/// ENCODING: week -> x-position; completed-workout count -> bar height;
/// strength hue -> recorded work; separator hue -> represented zero work.
/// INTERACTION: native chart selection chooses a week.
/// DETAIL: the selected week and exact count sit below the chart; History opens
/// the immutable source workouts.
/// EMPTY STATE: no series renders no cadence diagram; a represented zero stays
/// a labelled zero-work week.
/// ACCESSIBILITY: one ordered label announces every week and exact count.
///
/// Diagram specification — exercise evidence:
/// QUESTION: How did one comparable performed exercise value change?
/// DATA: one existing `ExerciseProgressSeries` projection; unavailable or
/// incomparable measurements never become points.
/// ENCODING: session date -> x-position; exact value -> y-position; dots ->
/// observations; the selected observation also receives a rule and text.
/// INTERACTION: native chart selection chooses a session.
/// DETAIL: selected date/value/method label is visible; Exercise trends opens
/// full evidence and methodology.
/// EMPTY STATE: fewer than two comparable observations renders a textual
/// evidence route rather than a fabricated line.
/// ACCESSIBILITY: the complete chronological date/value sequence is announced.
struct ProgressOverviewSection: View {
    let range: AnalyticsDateRange
    let state: ProgressOverviewState
    var onOpenPlan: ((UUID) -> Void)? = nil
    var onNavigate: (ProgressRoute) -> Void = { _ in }
    var presentation: ProgressOverviewPresentation = .all

    @State private var selectedFrequencyDate: Date?
    @State private var selectedTrendDate: Date?

    @ViewBuilder
    var body: some View {
        switch state {
        case .loading:
            if presentation != .insights { loadingState }
        case .failed:
            if presentation != .insights { failedState }
        case .empty:
            if presentation != .insights { emptyState }
        case let .loaded(summary):
            switch presentation {
            case .weekly:
                periodOverview(summary)
            case .insights:
                insightGroups(summary)
            case .all:
                periodOverview(summary)
                insightGroups(summary)
            }
        }
    }

    // MARK: - Glance

    private func periodOverview(_ summary: ProgressOverviewSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(range.title)
                    .font(AppFont.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.trameSubdued)

                TrameMetric(
                    value: "\(summary.completedWorkoutsInRange)",
                    label: summary.completedWorkoutsInRange == 1 ? "workout" : "workouts",
                    accessibilityLabel: CountPhrase.completedWorkouts(summary.completedWorkoutsInRange)
                )
            }
            .accessibilityIdentifier("progress-global-summary")
            .accessibilityIdentifier("progress-overview-current-period")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.xxl) {
                    periodSupportingMetrics(summary)
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    periodSupportingMetrics(summary)
                }
            }

            if summary.completedWorkoutsInRange > 0,
               summary.trainingTimeInRangeText == nil {
                Text("Training duration is unavailable for this period; it is not counted as zero.")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("progress-overview-duration-missing")
            }

            Button {
                onNavigate(.workoutHistory)
            } label: {
                Label("Open training history", systemImage: AppIcon.chevronRight)
                    .font(AppFont.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.trameText)
        }
        .overviewRowChrome(identifier: nil)
    }

    @ViewBuilder
    private func periodSupportingMetrics(_ summary: ProgressOverviewSummary) -> some View {
        if let time = summary.trainingTimeInRangeText {
            supportingMetric(
                value: time,
                label: String(localized: "Training time"),
                accessibilityLabel: String(localized: "\(time) of recorded training time")
            )
        }
        supportingMetric(
            value: "\(summary.completedEntriesInRange)",
            label: String(localized: "Recorded exercises"),
            accessibilityLabel: String(localized: "\(summary.completedEntriesInRange) completed exercise entries")
        )
    }

    private func supportingMetric(
        value: String,
        label: String,
        accessibilityLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(AppFont.metricCompact)
                .foregroundStyle(Color.trameText)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Read

    @ViewBuilder
    private func insightGroups(_ summary: ProgressOverviewSummary) -> some View {
        recentCadence(summary.weeklyFrequency)
        performanceEvidence(summary)
        sportEvidence(summary)
        inspectRoutes(summary)
    }

    @ViewBuilder
    private func recentCadence(_ points: [WeeklyFrequencyPoint]) -> some View {
        if points.isEmpty == false {
            let selectedPoint = selectedFrequencyPoint(in: points)
            VStack(alignment: .leading, spacing: Spacing.m) {
                TrameSectionRule(title: "Training rhythm")

                Text("Completed workouts · last 8 weeks")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)

                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Completed workouts", point.workoutCount),
                        width: .ratio(0.54)
                    )
                    .foregroundStyle(
                        point.workoutCount == 0
                            ? Color.trameSeparator
                            : Color.trameStrength
                    )

                    if selectedPoint?.id == point.id {
                        RuleMark(x: .value("Selected week", point.weekStart))
                            .foregroundStyle(Color.trameText)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYScale(domain: 0...max(1, points.map(\.workoutCount).max() ?? 1))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(AppFont.micro)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot.background(Color.clear)
                }
                .chartXSelection(value: $selectedFrequencyDate)
                .frame(height: ComponentSize.overviewChartHeight)
                .accessibilityHidden(true)

                Text(frequencyDetail(selectedPoint, points: points))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(weeklyFrequencyAccessibilityLabel(points))
                    .accessibilityIdentifier("progress-overview-weekly-frequency-chart")
            }
            .overviewRowChrome(identifier: nil)
        }
    }

    private func selectedFrequencyPoint(in points: [WeeklyFrequencyPoint]) -> WeeklyFrequencyPoint? {
        guard let selectedFrequencyDate else { return points.last }
        return points.min {
            abs($0.weekStart.timeIntervalSince(selectedFrequencyDate))
                < abs($1.weekStart.timeIntervalSince(selectedFrequencyDate))
        }
    }

    private func frequencyDetail(
        _ point: WeeklyFrequencyPoint?,
        points: [WeeklyFrequencyPoint]
    ) -> String {
        guard let point else { return String(localized: "No weekly frequency evidence") }
        let week = point.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let suffix = point.id == points.last?.id ? String(localized: " · current week") : ""
        return "\(week) · \(CountPhrase.completedWorkouts(point.workoutCount))\(suffix)"
    }

    private func weeklyFrequencyAccessibilityLabel(_ points: [WeeklyFrequencyPoint]) -> String {
        let values = points.map {
            "\($0.weekStart.formatted(.dateTime.month(.abbreviated).day())): \(CountPhrase.completedWorkouts($0.workoutCount))"
        }
        return String(localized: "Completed workouts over the last eight weeks. \(values.joined(separator: ", "))")
    }

    // MARK: - Exercise evidence

    @ViewBuilder
    private func performanceEvidence(_ summary: ProgressOverviewSummary) -> some View {
        if summary.latestRecord != nil || summary.featuredSeries != nil {
            VStack(alignment: .leading, spacing: Spacing.m) {
                TrameSectionRule(title: "Exercise evidence")

                if let record = summary.latestRecord,
                   shouldShowRecordMetric(record, summary: summary) {
                    evidenceButton(
                        route: .records,
                        identifier: "latest-record",
                        eyebrow: String(localized: "Latest record"),
                        value: record.displayValue,
                        detail: "\(record.exerciseName) · \(record.kind)"
                    )
                }

                if let series = summary.featuredSeries,
                   let projection = featuredTrendProjection(series),
                   projection.points.count >= 2 {
                    Divider().overlay(Color.trameSeparator)
                    featuredTrendDiagram(series, projection: projection)
                } else if let series = summary.featuredSeries {
                    evidenceButton(
                        route: .trainingTrends,
                        identifier: "exercise-trend",
                        eyebrow: String(localized: "Most logged"),
                        value: series.name,
                        detail: series.quality == .sparse
                            ? String(localized: "Early evidence")
                            : sessionCountText(series)
                    )
                }
            }
            .overviewRowChrome(identifier: nil)
        }
    }

    private func evidenceButton(
        route: ProgressRoute,
        identifier: String,
        eyebrow: String,
        value: String,
        detail: String
    ) -> some View {
        Button { onNavigate(route) } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(eyebrow)
                    .font(AppFont.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.trameSubdued)
                Text(value)
                    .font(AppFont.metricLarge)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(eyebrow). \(value). \(detail)")
        .accessibilityHint("Opens full evidence")
        .accessibilityIdentifier("progress-overview-\(identifier)")
    }

    private func featuredTrendDiagram(
        _ series: ExerciseProgressSeries,
        projection: (label: String, points: [ExerciseProgressPoint])
    ) -> some View {
        let selected = selectedTrendPoint(in: projection.points)
        let maximum = projection.points.map(\.value).max() ?? 1
        let upperBound = max(Float(1), maximum * 1.12)

        return VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(projection.points.count >= 4 ? "Exercise trend" : "Early comparison")
                        .font(AppFont.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.trameSubdued)
                    Text(series.name)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.trameText)
                }
                Spacer(minLength: Spacing.m)
                Text(projection.label)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .multilineTextAlignment(.trailing)
            }

            Chart(projection.points) { point in
                LineMark(
                    x: .value("Session", point.date),
                    y: .value(projection.label, point.value)
                )
                .foregroundStyle(Color.trameStrength)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)

                PointMark(
                    x: .value("Session", point.date),
                    y: .value(projection.label, point.value)
                )
                .symbolSize(selected?.id == point.id ? 70 : 34)
                .foregroundStyle(selected?.id == point.id ? Color.trameText : Color.trameStrength)

                if selected?.id == point.id {
                    RuleMark(x: .value("Selected session", point.date))
                        .foregroundStyle(Color.trameText)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYScale(domain: Float.zero...upperBound)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.trameSeparator)
                    AxisValueLabel()
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedTrendDate)
            .frame(height: ComponentSize.progressDashboardChartHeight)
            .accessibilityHidden(true)

            if let selected {
                Text(trendPointDetail(selected, label: projection.label))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            }

            Button("Open exercise trends") {
                onNavigate(.trainingTrends)
            }
            .font(AppFont.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .buttonStyle(.plain)
            .foregroundStyle(Color.trameText)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(featuredTrendAccessibilityLabel(series, projection: projection))
        .accessibilityIdentifier("progress-overview-featured-trend-chart")
    }

    private func selectedTrendPoint(in points: [ExerciseProgressPoint]) -> ExerciseProgressPoint? {
        guard let selectedTrendDate else { return points.last }
        return points.min {
            abs($0.date.timeIntervalSince(selectedTrendDate))
                < abs($1.date.timeIntervalSince(selectedTrendDate))
        }
    }

    private func trendPointDetail(_ point: ExerciseProgressPoint, label: String) -> String {
        let value = point.value.formatted(.number.precision(.fractionLength(0...1)))
        let date = point.date.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(date) · \(value) · \(label)"
    }

    private func featuredTrendProjection(
        _ series: ExerciseProgressSeries
    ) -> (label: String, points: [ExerciseProgressPoint])? {
        if series.loadPoints.count >= 2 {
            return (String(localized: "Best load (\(series.unit))"), series.loadPoints.sorted { $0.date < $1.date })
        }
        if series.volumePoints.count >= 2 {
            return (String(localized: "Session volume (\(series.unit))"), series.volumePoints.sorted { $0.date < $1.date })
        }
        if series.repsPoints.count >= 2 {
            return (String(localized: "Completed repetitions"), series.repsPoints.sorted { $0.date < $1.date })
        }
        return nil
    }

    private func featuredTrendAccessibilityLabel(
        _ series: ExerciseProgressSeries,
        projection: (label: String, points: [ExerciseProgressPoint])
    ) -> String {
        let values = projection.points.map { trendPointDetail($0, label: projection.label) }
        return String(localized: "\(series.name), \(projection.label). \(projection.points.count) comparable sessions. \(values.joined(separator: ". "))")
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

    private func sessionCountText(_ series: ExerciseProgressSeries) -> String {
        let count = max(series.loadPoints.count, max(series.volumePoints.count, series.repsPoints.count))
        return CountPhrase.recordedSessions(count)
    }

    // MARK: - Sport evidence

    private func sportEvidence(_ summary: ProgressOverviewSummary) -> some View {
        let orderedEvidence = summary.sportEvidence.sorted {
            $0.completedWorkoutCount > $1.completedWorkoutCount
        }

        return VStack(alignment: .leading, spacing: Spacing.m) {
            TrameSectionRule(title: "Recorded sports")
                .accessibilityIdentifier("progress-sport-highlights")

            if summary.hasComparableSportFocus == false {
                Text("Complete at least four workouts across two weeks to compare how your recorded sport focus changes over time.")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("progress-sport-focus-insufficient")
            }

            if summary.sportEvidence.isEmpty {
                Text(summary.completedWorkoutsInRange == 0
                    ? String(localized: "No completed training in this period.")
                    : String(localized: "No authored sport classification is available for this period."))
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(orderedEvidence) { evidence in
                    HStack(spacing: Spacing.m) {
                        Rectangle()
                            .fill(SportDisciplinePalette.color(for: evidence.discipline))
                            .frame(width: Spacing.xs, height: ComponentSize.minimumTouchTarget)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(evidence.discipline.title)
                                .font(AppFont.body.weight(.semibold))
                                .foregroundStyle(Color.trameText)
                            Text(evidence.qualityLabel)
                                .font(AppFont.micro)
                                .foregroundStyle(Color.trameSubdued)
                        }
                        Spacer(minLength: Spacing.s)
                        Text("\(evidence.completedWorkoutCount)")
                            .font(AppFont.metricCompact)
                            .foregroundStyle(Color.trameText)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(evidence.accessibilityLabel)

                    if evidence.id != orderedEvidence.last?.id {
                        Divider().overlay(Color.trameSeparator)
                    }
                }
            }

            Text("Completed workout snapshots with recorded sport identities. One workout may contribute to more than one sport; unavailable classifications are omitted, not counted as zero.")
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("progress-overview-sport-method")
        }
        .overviewRowChrome(identifier: nil)
    }

    // MARK: - Inspect

    @ViewBuilder
    private func inspectRoutes(_ summary: ProgressOverviewSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TrameSectionRule(title: "Inspect")
                .padding(.bottom, Spacing.s)

            if let planID = summary.currentPlanID, let name = summary.currentPlanName {
                Button { onOpenPlan?(planID) } label: {
                    inspectRow(
                        title: String(localized: "Current plan"),
                        detail: [name, summary.currentPlanPhaseText].compactMap { $0 }.joined(separator: " · ")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("progress-overview-current-plan")
                Divider().overlay(Color.trameSeparator)
            }

            NavigationLink(value: ProgressRoute.supportingHistory(.mobility)) {
                inspectRow(
                    title: String(localized: "Mobility"),
                    detail: "\(CountPhrase.sessions(summary.mobilitySessionsInRange)) · \(summary.assessmentRecencyText)"
                )
            }
            .accessibilityIdentifier("progress-overview-mobility")

            Divider().overlay(Color.trameSeparator)

            NavigationLink(value: ProgressRoute.trainingJourney) {
                inspectRow(
                    title: String(localized: "Journey"),
                    detail: [summary.latestChapterTitle, summary.journeySummaryText]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                )
            }
            .accessibilityIdentifier("progress-overview-journey")
        }
        .overviewRowChrome(identifier: nil)
    }

    private func inspectRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(AppFont.body.weight(.semibold))
                .foregroundStyle(Color.trameText)
            Text(detail)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - States

    private var loadingState: some View {
        HStack(spacing: Spacing.m) {
            ProgressView()
            Text("Reading your history…")
                .font(AppFont.body)
                .foregroundStyle(Color.trameSubdued)
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .overviewRowChrome(identifier: "loading")
    }

    private var failedState: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Summary unavailable")
            Text("Your history could not be read just now. The evidence routes below remain available.")
                .font(AppFont.body)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overviewRowChrome(identifier: "failed")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "No completed workouts")
            Text("Finish a workout and its recorded totals, cadence, sport evidence, and exact source history appear here.")
                .font(AppFont.body)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overviewRowChrome(identifier: "empty")
    }
}

enum ProgressOverviewPresentation {
    case weekly
    case insights
    case all
}

private extension View {
    @ViewBuilder
    func overviewRowChrome(identifier: String?) -> some View {
        let reset = listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: Spacing.m,
                    leading: Spacing.xs,
                    bottom: Spacing.m,
                    trailing: Spacing.xs
                )
            )

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
    /// No completed workout exists at all. A loaded summary may legitimately
    /// contain zero workouts for its selected range.
    case empty
    case loaded(ProgressOverviewSummary)
}

struct ProgressOverviewSummary: Equatable {
    var completedWorkoutsInRange: Int
    var completedEntriesInRange: Int
    var trainingTimeInRangeText: String?
    var sportEvidence: [ProgressOverviewSportEvidence]
    var hasComparableSportFocus: Bool
    var weeklyFrequency: [WeeklyFrequencyPoint]
    var currentPlanID: UUID?
    var currentPlanName: String?
    var currentPlanPhaseText: String?
    var latestRecord: PersonalRecordItem?
    var featuredSeries: ExerciseProgressSeries?
    var mobilitySessionsInRange: Int
    var assessmentRecencyText: String
    var latestChapterTitle: String?
    var journeySummaryText: String
}

struct ProgressOverviewSportEvidence: Equatable, Identifiable {
    var id: String { discipline.rawValue }
    let discipline: SportDiscipline
    let completedWorkoutCount: Int
    let quality: AnalyticsDataQuality

    var qualityLabel: String {
        switch quality {
        case .insufficient: String(localized: "Latest evidence")
        case .sparse: String(localized: "Early evidence")
        case .adequate: String(localized: "Recorded evidence")
        }
    }

    var accessibilityLabel: String {
        "\(discipline.title), \(CountPhrase.completedWorkouts(completedWorkoutCount)), \(qualityLabel)"
    }
}

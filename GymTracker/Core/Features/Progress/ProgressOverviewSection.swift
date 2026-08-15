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
/// INTERACTION: tapping the compact diagram opens the full Trends destination.
/// DETAIL: the complete period/count sequence remains available to VoiceOver;
/// Trends exposes the larger analysis surface.
/// EMPTY STATE: no series renders no cadence diagram; a represented zero stays
/// a labelled zero-work week.
/// ACCESSIBILITY: one ordered label announces every week and exact count.
///
/// Diagram specification — training focus:
/// QUESTION: Which recorded sports make up completed training in this period?
/// DATA: completed-workout sport highlights; unclassified evidence remains
/// unavailable rather than being assigned to a sport.
/// ENCODING: segment width -> completed-workout count; semantic hue -> sport;
/// direct labels and counts reinforce every hue. More than four sports collapse
/// visually into an explicitly labelled Other segment.
/// INTERACTION: none on the compact overview; the lens picker changes scope.
/// DETAIL: the visible legend provides counts and VoiceOver announces every
/// underlying sport before any visual grouping.
/// EMPTY STATE: no completed training and unavailable classification remain
/// distinct textual states.
/// ACCESSIBILITY: one complete label announces all sports and exact counts.
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

    @State private var selectedTrendDate: Date?

    @ViewBuilder
    var body: some View {
        switch state {
        case .loading:
            loadingState
        case .failed:
            failedState
        case .empty:
            emptyState
        case let .loaded(summary):
            insightGroups(summary)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func insightGroups(_ summary: ProgressOverviewSummary) -> some View {
        recentCadence(summary.weeklyFrequency, summary: summary)
        sportEvidence(summary)
        performanceEvidence(summary)
    }

    @ViewBuilder
    private func recentCadence(
        _ points: [WeeklyFrequencyPoint],
        summary: ProgressOverviewSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Training rhythm")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.xxl) {
                    cadenceMetric(
                        value: "\(summary.completedWorkoutsInRange)",
                        label: summary.completedWorkoutsInRange == 1 ? "workout" : "workouts",
                        accessibilityLabel: CountPhrase.completedWorkouts(summary.completedWorkoutsInRange)
                    )
                    cadenceMetric(
                        value: summary.trainingTimeInRangeText ?? "—",
                        label: "trained",
                        accessibilityLabel: summary.trainingTimeInRangeText.map { "\($0) trained" }
                            ?? "Training duration unavailable"
                    )
                }

                VStack(alignment: .leading, spacing: Spacing.m) {
                    cadenceMetric(
                        value: "\(summary.completedWorkoutsInRange)",
                        label: summary.completedWorkoutsInRange == 1 ? "workout" : "workouts",
                        accessibilityLabel: CountPhrase.completedWorkouts(summary.completedWorkoutsInRange)
                    )
                    cadenceMetric(
                        value: summary.trainingTimeInRangeText ?? "—",
                        label: "trained",
                        accessibilityLabel: summary.trainingTimeInRangeText.map { "\($0) trained" }
                            ?? "Training duration unavailable"
                    )
                }
            }
            .padding(.vertical, Spacing.xxs)

            if points.isEmpty == false {
                Button {
                    onNavigate(.trainingTrends)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
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
                        }
                        .chartYScale(domain: 0...max(1, points.map(\.workoutCount).max() ?? 1))
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                                AxisGridLine().foregroundStyle(Color.trameSeparator)
                            }
                        }
                        .chartPlotStyle { plot in
                            plot.background(Color.clear)
                        }
                        .frame(height: ComponentSize.overviewChartHeight)

                        HStack {
                            Text("8W")
                            Spacer()
                            Text("NOW")
                        }
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weeklyFrequencyAccessibilityLabel(points))
                .accessibilityHint("Opens training trends")
                .accessibilityIdentifier("progress-overview-current-period")
            }
        }
        .overviewRowChrome(identifier: nil)
    }

    private func cadenceMetric(
        value: String,
        label: String,
        accessibilityLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(AppFont.metricHero)
                .foregroundStyle(Color.trameText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
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
            VStack(alignment: .leading, spacing: Spacing.s) {
                TrameSectionRule(title: "Performance")

                if let series = summary.featuredSeries,
                   let projection = featuredTrendProjection(series),
                   projection.points.count >= 2 {
                    featuredTrendDiagram(series, projection: projection)
                } else if let record = summary.latestRecord {
                    evidenceButton(
                        route: .records,
                        identifier: "latest-record",
                        eyebrow: String(localized: "Latest record"),
                        value: record.displayValue,
                        detail: "\(record.exerciseName) · \(record.kind)"
                    )
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
        let latestPoint = projection.points.last

        return Button {
            onNavigate(.trainingTrends)
        } label: {
            HStack(alignment: .bottom, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if let latestPoint {
                        Text("\(latestPoint.value.formatted(.number.precision(.fractionLength(0...1))))")
                            .font(AppFont.metricHero)
                            .foregroundStyle(Color.trameText)
                        Text("\(series.name) · \(series.unit)")
                            .font(AppFont.micro)
                            .foregroundStyle(Color.trameSubdued)
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 100, alignment: .leading)

                Chart(projection.points) { point in
                    LineMark(
                        x: .value("Session", point.date),
                        y: .value(projection.label, point.value)
                    )
                    .foregroundStyle(Color.trameStrength)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value("Session", point.date),
                        y: .value(projection.label, point.value)
                    )
                    .symbolSize(selected?.id == point.id ? 60 : 28)
                    .foregroundStyle(selected?.id == point.id ? Color.trameText : Color.trameStrength)

                    if selected?.id == point.id {
                        RuleMark(x: .value("Selected session", point.date))
                            .foregroundStyle(Color.trameText)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYScale(domain: Float.zero...upperBound)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .chartXSelection(value: $selectedTrendDate)
                .frame(height: ComponentSize.progressOverviewSparklineHeight)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
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
        let segments = sportFocusSegments(orderedEvidence)
        let total = max(segments.reduce(0) { $0 + $1.count }, 1)

        return VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Training focus")
                .accessibilityIdentifier("progress-sport-highlights")

            if summary.sportEvidence.isEmpty {
                Text(summary.completedWorkoutsInRange == 0
                    ? String(localized: "No completed training in this period.")
                    : String(localized: "Sport classification unavailable."))
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    GeometryReader { geometry in
                        let gaps = CGFloat(max(segments.count - 1, 0)) * Spacing.xxs
                        let availableWidth = max(geometry.size.width - gaps, 0)
                        HStack(spacing: Spacing.xxs) {
                            ForEach(segments) { segment in
                                Rectangle()
                                    .fill(segment.color)
                                    .frame(width: availableWidth * CGFloat(segment.count) / CGFloat(total))
                            }
                        }
                    }
                    .frame(height: ComponentSize.minimumTouchTarget)
                    .accessibilityHidden(true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Spacing.l) {
                            ForEach(segments) { segment in
                                sportLegendItem(segment)
                            }
                        }

                        VStack(alignment: .leading, spacing: Spacing.s) {
                            ForEach(segments) { segment in
                                sportLegendItem(segment)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(sportFocusAccessibilityLabel(orderedEvidence))
            }
        }
        .overviewRowChrome(identifier: nil)
    }

    private func sportFocusSegments(
        _ evidence: [ProgressOverviewSportEvidence]
    ) -> [SportFocusSegment] {
        let visible = evidence.prefix(evidence.count > 4 ? 3 : 4).map {
            SportFocusSegment(
                id: $0.id,
                title: $0.discipline.title,
                count: $0.completedWorkoutCount,
                color: SportDisciplinePalette.color(for: $0.discipline)
            )
        }
        guard evidence.count > 4 else { return visible }
        let otherCount = evidence.dropFirst(3).reduce(0) { $0 + $1.completedWorkoutCount }
        return visible + [
            SportFocusSegment(
                id: "other",
                title: String(localized: "Other"),
                count: otherCount,
                color: Color.trameSubdued
            )
        ]
    }

    private func sportLegendItem(_ segment: SportFocusSegment) -> some View {
        HStack(spacing: Spacing.xs) {
            Rectangle()
                .fill(segment.color)
                .frame(width: Spacing.s, height: Spacing.s)
                .accessibilityHidden(true)
            Text(segment.title)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
                .lineLimit(1)
            Text("\(segment.count)")
                .font(AppFont.micro)
                .monospacedDigit()
                .foregroundStyle(Color.trameText)
        }
    }

    private func sportFocusAccessibilityLabel(
        _ evidence: [ProgressOverviewSportEvidence]
    ) -> String {
        evidence.map(\.accessibilityLabel).joined(separator: ". ")
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .accessibilityLabel("Reading history")
            .overviewRowChrome(identifier: "loading")
    }

    private var failedState: some View {
        Text("Progress unavailable. Try again.")
            .font(AppFont.body)
            .foregroundStyle(Color.trameSubdued)
            .fixedSize(horizontal: false, vertical: true)
            .overviewRowChrome(identifier: "failed")
    }

    private var emptyState: some View {
        Text("Complete a workout to see progress.")
            .font(AppFont.body)
            .foregroundStyle(Color.trameSubdued)
            .fixedSize(horizontal: false, vertical: true)
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

private struct SportFocusSegment: Identifiable {
    let id: String
    let title: String
    let count: Int
    let color: Color
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

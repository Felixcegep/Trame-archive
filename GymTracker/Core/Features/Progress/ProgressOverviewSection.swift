import Charts
import SwiftUI

/// The evidence-first Global lens for Progress.
///
/// Every value is supplied by an existing analytics projection. This view composes
/// those facts with strict visual hierarchy and glance-level clarity:
/// Performance (if available) -> Rhythm -> Focus (if >1 sport).
///
/// Diagram specification — cadence:
/// QUESTION: What rhythm of completed training was recorded over the selected range?
/// DATA: `WeeklyFrequencyPoint`; every represented week remains present, and a
/// zero-work week is distinct from an unavailable series.
/// ENCODING: week -> x-position; completed-workout count -> bar height;
/// strength hue -> recorded work; separator hue -> represented zero work.
/// INTERACTION: tapping the compact diagram opens the full Trends destination.
/// DETAIL: the complete period/count sequence remains available to VoiceOver.
/// EMPTY STATE: no series renders no cadence diagram; zero work stays a labelled bar.
/// ACCESSIBILITY: one ordered label announces every week and exact count.
///
/// Diagram specification — training focus:
/// QUESTION: Which recorded sports make up completed training in this period?
/// DATA: normalized completed-workout contributions from `MixedProgressProjection`;
/// each completed workout contributes exactly 1.0 unit shared evenly across its sports.
/// ENCODING: segment width -> normalized proportion; semantic hue -> sport;
/// direct labels and percentages reinforce every hue. More than four sports collapse
/// visually into an explicitly labelled Other segment.
/// INTERACTION: none on the compact overview; the lens picker changes scope.
/// DETAIL: the visible legend provides percentages and VoiceOver announces every
/// underlying sport and percentage.
/// EMPTY STATE: omitted when training is 100% one sport or unclassified.
/// ACCESSIBILITY: one complete label announces all sports and percentages.
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

    @State private var selectedTrendDate: Date?

    var body: some View {
        switch state {
        case .loading:
            loadingState
        case .failed:
            failedState
        case .empty:
            emptyState
        case let .loaded(summary):
            if summary.completedWorkoutsInRange == 0 {
                periodEmptyState
            } else {
                insightGroups(summary)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func insightGroups(_ summary: ProgressOverviewSummary) -> some View {
        if hasComparableSeries(summary) {
            performanceSection(summary)
            rhythmSection(summary)
            if shouldShowFocus(summary) {
                focusSection(summary)
            }
        } else if summary.latestRecord != nil {
            latestRecordSection(summary)
            rhythmSection(summary)
            if shouldShowFocus(summary) {
                focusSection(summary)
            }
        } else {
            rhythmSection(summary)
            if shouldShowFocus(summary) {
                focusSection(summary)
            }
        }
    }

    private func hasComparableSeries(_ summary: ProgressOverviewSummary) -> Bool {
        guard let series = summary.featuredSeries,
              let projection = featuredTrendProjection(series)
        else { return false }
        return projection.points.count >= 2
    }

    // MARK: - Performance

    @ViewBuilder
    private func performanceSection(_ summary: ProgressOverviewSummary) -> some View {
        if let series = summary.featuredSeries,
           let projection = featuredTrendProjection(series),
           projection.points.count >= 2,
           let latestPoint = projection.points.last {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("PERFORMANCE")
                    .font(AppFont.eyebrow)
                    .tracking(1.0)
                    .foregroundStyle(Color.trameSubdued)

                Button {
                    onNavigate(.trainingTrends)
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .bottom, spacing: Spacing.l) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("\(latestPoint.value.formatted(.number.precision(.fractionLength(0...1)))) \(series.unit)")
                                    .font(AppFont.metricHero)
                                    .foregroundStyle(Color.trameText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text(series.name)
                                    .font(AppFont.bodyMedium)
                                    .foregroundStyle(Color.trameSubdued)
                                    .lineLimit(2)
                            }
                            .frame(minWidth: 120, alignment: .leading)

                            sparklineChart(points: projection.points, label: projection.label)
                        }

                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("\(latestPoint.value.formatted(.number.precision(.fractionLength(0...1)))) \(series.unit)")
                                .font(AppFont.metricHero)
                                .foregroundStyle(Color.trameText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(series.name)
                                .font(AppFont.bodyMedium)
                                .foregroundStyle(Color.trameSubdued)
                                .lineLimit(2)

                            sparklineChart(points: projection.points, label: projection.label)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(featuredTrendAccessibilityLabel(series, projection: projection))
                .accessibilityIdentifier("progress-overview-featured-trend-chart")
            }
        }
    }

    private func sparklineChart(points: [ExerciseProgressPoint], label: String) -> some View {
        let selected = selectedTrendPoint(in: points)
        let maximum = points.map(\.value).max() ?? 1
        let upperBound = max(Float(1), maximum * 1.12)

        return Chart(points) { point in
            LineMark(
                x: .value("Session", point.date),
                y: .value(label, point.value)
            )
            .foregroundStyle(Color.trameStrength)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.linear)

            PointMark(
                x: .value("Session", point.date),
                y: .value(label, point.value)
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

    @ViewBuilder
    private func latestRecordSection(_ summary: ProgressOverviewSummary) -> some View {
        if let record = summary.latestRecord {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("LATEST BEST")
                    .font(AppFont.eyebrow)
                    .tracking(1.0)
                    .foregroundStyle(Color.trameSubdued)

                Button {
                    onNavigate(.records)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(record.displayValue)
                            .font(AppFont.metricHero)
                            .foregroundStyle(Color.trameText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(record.exerciseName)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.trameSubdued)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Latest record. \(record.displayValue). \(record.exerciseName)")
                .accessibilityHint("Opens records")
                .accessibilityIdentifier("progress-overview-latest-record")
            }
        }
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

    // MARK: - Training Rhythm

    private func rhythmSection(_ summary: ProgressOverviewSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("RHYTHM")
                .font(AppFont.eyebrow)
                .tracking(1.0)
                .foregroundStyle(Color.trameSubdued)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("\(summary.completedWorkoutsInRange)")
                        .font(AppFont.metricHero)
                        .foregroundStyle(Color.trameText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(summary.completedWorkoutsInRange == 1 ? "workout" : "workouts")
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameSubdued)
                }

                if let durationText = summary.trainingTimeInRangeText {
                    Text("\(durationText) trained")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
            .padding(.bottom, Spacing.xxs)
            .accessibilityElement(children: .combine)

            if summary.weeklyFrequency.isEmpty == false {
                Button {
                    onNavigate(.trainingTrends)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Chart(summary.weeklyFrequency) { point in
                            BarMark(
                                x: .value("Week", point.weekStart, unit: .weekOfYear),
                                y: .value("Completed workouts", point.workoutCount),
                                width: .ratio(summary.weeklyFrequency.count > 20 ? 0.8 : 0.54)
                            )
                            .foregroundStyle(
                                point.workoutCount == 0
                                    ? Color.trameSeparator
                                    : Color.trameStrength
                            )
                        }
                        .chartYScale(domain: 0...max(1, summary.weeklyFrequency.map(\.workoutCount).max() ?? 1))
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                                AxisGridLine().foregroundStyle(Color.trameSeparator)
                            }
                        }
                        .chartPlotStyle { plot in
                            plot.background(Color.clear)
                        }
                        .frame(height: 76)

                        HStack {
                            Text(rangeStartLabel(for: range))
                            Spacer()
                            Text("NOW")
                        }
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weeklyFrequencyAccessibilityLabel(summary.weeklyFrequency, range: range))
                .accessibilityHint("Opens training trends")
                .accessibilityIdentifier("progress-overview-current-period")
            }
        }
    }

    private func rangeStartLabel(for range: AnalyticsDateRange) -> String {
        switch range {
        case .fourWeeks: "4W"
        case .twelveWeeks: "12W"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .allTime: "ALL"
        }
    }

    private func weeklyFrequencyAccessibilityLabel(_ points: [WeeklyFrequencyPoint], range: AnalyticsDateRange) -> String {
        let values = points.map {
            "\($0.weekStart.formatted(.dateTime.month(.abbreviated).day())): \(CountPhrase.completedWorkouts($0.workoutCount))"
        }
        return String(localized: "Completed workouts over \(range.title). \(values.joined(separator: ", "))")
    }

    // MARK: - Training Focus

    private func shouldShowFocus(_ summary: ProgressOverviewSummary) -> Bool {
        guard summary.completedWorkoutsInRange > 0 else { return false }
        let nonZero = summary.sportFocus.filter { $0.proportion > 0 }
        guard nonZero.count > 1 else { return false }
        let known = nonZero.filter { $0.discipline != nil }
        return known.count > 1 || (known.count == 1 && nonZero.contains { $0.discipline == nil })
    }

    private func focusSection(_ summary: ProgressOverviewSummary) -> some View {
        let segments = sportFocusSegments(summary.sportFocus)

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("FOCUS")
                .font(AppFont.eyebrow)
                .tracking(1.0)
                .foregroundStyle(Color.trameSubdued)
                .accessibilityIdentifier("progress-sport-highlights")

            VStack(alignment: .leading, spacing: Spacing.s) {
                GeometryReader { geometry in
                    let gaps = CGFloat(max(segments.count - 1, 0)) * Spacing.xxs
                    let availableWidth = max(geometry.size.width - gaps, 0)
                    HStack(spacing: Spacing.xxs) {
                        ForEach(segments) { segment in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(segment.color)
                                .frame(width: max(availableWidth * CGFloat(segment.proportion), 2))
                        }
                    }
                }
                .frame(height: 12)
                .accessibilityHidden(true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.m) {
                        ForEach(segments) { segment in
                            sportLegendItem(segment)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(segments) { segment in
                            sportLegendItem(segment)
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sportFocusAccessibilityLabel(segments))
        }
    }

    private func sportFocusSegments(
        _ items: [ProgressOverviewSportFocusItem]
    ) -> [SportFocusSegment] {
        let filtered = items.filter { $0.proportion > 0 }.sorted { $0.proportion > $1.proportion }
        let topLimit = filtered.count > 4 ? 3 : filtered.count
        let topSlices = filtered.prefix(topLimit).map { item in
            SportFocusSegment(
                id: item.id,
                title: item.title,
                proportion: item.proportion,
                percentage: Int((item.proportion * 100).rounded()),
                color: item.color
            )
        }
        guard filtered.count > 4 else { return topSlices }
        let otherProportion = filtered.dropFirst(topLimit).reduce(0.0) { $0 + $1.proportion }
        let otherSegment = SportFocusSegment(
            id: "other",
            title: String(localized: "Other"),
            proportion: otherProportion,
            percentage: Int((otherProportion * 100).rounded()),
            color: Color.trameSubdued
        )
        return topSlices + [otherSegment]
    }

    private func sportLegendItem(_ segment: SportFocusSegment) -> some View {
        HStack(spacing: Spacing.xxs) {
            Rectangle()
                .fill(segment.color)
                .frame(width: 8, height: 8)
                .cornerRadius(1.5)
                .accessibilityHidden(true)
            Text(segment.title)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
                .lineLimit(1)
            Text("\(segment.percentage)%")
                .font(AppFont.micro)
                .monospacedDigit()
                .foregroundStyle(Color.trameText)
        }
    }

    private func sportFocusAccessibilityLabel(
        _ segments: [SportFocusSegment]
    ) -> String {
        let details = segments.map { "\($0.title) \($0.percentage) percent" }
        return "Training focus. " + details.joined(separator: ". ")
    }

    // MARK: - States

    private var periodEmptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(periodEmptyTitle(for: range))
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
            Text("Previous training remains in History.")
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress-period-empty")
    }

    private func periodEmptyTitle(for range: AnalyticsDateRange) -> String {
        switch range {
        case .fourWeeks: String(localized: "No workouts in the last 4 weeks.")
        case .twelveWeeks: String(localized: "No workouts in the last 12 weeks.")
        case .sixMonths: String(localized: "No workouts in the last 6 months.")
        case .oneYear: String(localized: "No workouts in the last year.")
        case .allTime: String(localized: "No completed workouts recorded.")
        }
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .accessibilityLabel("Reading history")
            .accessibilityIdentifier("progress-overview-loading")
    }

    private var failedState: some View {
        Text("Progress unavailable.")
            .font(AppFont.bodyMedium)
            .foregroundStyle(Color.trameSubdued)
            .accessibilityIdentifier("progress-overview-failed")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("No progress yet")
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
            Text("Complete a workout to see progress.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress-overview-empty")
    }
}

// MARK: - Types

private struct SportFocusSegment: Identifiable {
    let id: String
    let title: String
    let proportion: Double
    let percentage: Int
    let color: Color
}

struct ProgressOverviewSportFocusItem: Equatable, Identifiable, Sendable {
    var id: String { discipline?.rawValue ?? "unclassified" }
    let discipline: SportDiscipline?
    let contribution: Double
    let proportion: Double

    var title: String {
        discipline?.title ?? String(localized: "Unclassified")
    }

    var color: Color {
        SportDisciplinePalette.color(for: discipline)
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
    var sportFocus: [ProgressOverviewSportFocusItem]
    var weeklyFrequency: [WeeklyFrequencyPoint]
    var latestRecord: PersonalRecordItem?
    var featuredSeries: ExerciseProgressSeries?
}

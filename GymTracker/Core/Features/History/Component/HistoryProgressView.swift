import Charts
import SwiftData
import SwiftUI

struct HistoryProgressView: View {
    let workouts: [Workout]

    var body: some View {
        let projection = HistoryProgressProjection.make(
            workouts: workouts,
            displayWeightType: UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        )
        let series = projection.exerciseSeries
        let frequency = projection.frequencyPoints

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Progress")
                        .font(AppFont.displayMedium)
                    // "Based on", not "Trends from": the page shows whatever
                    // evidence exists, and most of it will not be a trend on a
                    // new install. The heading should not assert one before a
                    // single chart has been drawn.
                    Text("Based on completed workouts only.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }

                HistoryFrequencyChart(points: frequency)

                if series.isEmpty {
                    ContentUnavailableView(
                        "No measurable progress yet",
                        systemImage: AppIcon.chart,
                        description: Text("Complete weighted or rep-based sets to see exercise trends.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("By exercise")
                            .font(AppFont.titleSmallSemibold)

                        ForEach(Array(series.prefix(5))) { item in
                            HistoryExerciseProgressCard(series: item)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
    }

}

private struct HistoryFrequencyChart: View {
    let points: [HistoryFrequencyPoint]

    @State private var selectedDate: Date?

    init(points: [HistoryFrequencyPoint]) {
        self.points = points
        _selectedDate = State(initialValue: points.last(where: { $0.count > 0 })?.start ?? points.last?.start)
    }

    private var selectedPoint: HistoryFrequencyPoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.start.timeIntervalSince(selectedDate)) < abs($1.start.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        GymChartCard(
            title: "Training frequency · 8 weeks",
            evidence: "Completed workouts only; every week is shown.",
            takeaway: takeaway,
            titleIdentifier: "training-frequency-chart",
            insight: insight
        ) {
            if let selectedPoint {
                GymChartSelectionAnnotation(
                    title: selectedPoint.start.formatted(.dateTime.month(.abbreviated).day()),
                    value: "\(selectedPoint.count) \(selectedPoint.count == 1 ? "workout" : "workouts")"
                )
            }
            Chart(points) { point in
                BarMark(
                    x: .value("Week", point.start, unit: .weekOfYear),
                    y: .value("Workouts", point.count),
                    width: .ratio(0.6)
                )
                .foregroundStyle(point.count == 0 ? Color.gymRowSurface : Color.gymPrimary)
                .cornerRadius(Radius.small)
                if selectedPoint?.id == point.id {
                    RuleMark(x: .value("Selected week", point.start))
                        .foregroundStyle(Color.gymPrimary.opacity(0.42))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 1)) { _ in
                    AxisGridLine().foregroundStyle(Color.gymBorder)
                    AxisTick().foregroundStyle(Color.gymBorder)
                    AxisValueLabel().foregroundStyle(Color.gymSubduedText)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.gymBorder)
                    AxisTick().foregroundStyle(Color.gymBorder)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
            .frame(height: ComponentSize.compactChartHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Workout frequency for the last eight weeks")
            .accessibilityValue(points.map { "\($0.start.formatted(.dateTime.month(.abbreviated).day())): \($0.count) workouts" }.joined(separator: ", "))
        }
    }

    private var takeaway: String? {
        guard points.count >= 8 else { return nil }
        let previous = points.prefix(4).reduce(0) { $0 + $1.count }
        let recent = points.suffix(4).reduce(0) { $0 + $1.count }
        if previous == recent { return "Training frequency was the same across the two four-week windows." }
        let diff = abs(recent - previous)
        let noun = diff == 1 ? "workout" : "workouts"
        return "You completed \(diff) \(recent > previous ? "more" : "fewer") \(noun) in the recent four weeks."
    }

    private var insight: AnalyticsInsight {
        let workoutCount = points.reduce(0) { $0 + $1.count }
        let level = StrengthEvidenceLevel.resolve(comparableSessionCount: workoutCount)
        let tier: String? = switch workoutCount {
        case 0: nil
        case 1...3: "Limited data"
        case 4...7: "Short window"
        default: "Trend"
        }
        return AnalyticsInsight(
            sessionCount: workoutCount,
            wordingTier: tier,
            evidenceLevel: level,
            allowsDirectionalClaim: level.allowsDirectionalClaim,
            comparisonConditions: "Completed workouts grouped by calendar week across the last 8 weeks.",
            excludedEvidence: "Active, planned, or discarded workouts.",
            calculationMethod: "Weekly workout counts compared across two four-week windows.",
            takeaway: takeaway
        )
    }
}

struct HistoryExerciseProgressCard: View {
    let series: HistoryExerciseSeries
    @State private var metric: HistoryProgressMetric = .load
    @State private var selectedDate: Date?

    private var selectedPoint: HistoryMetricPoint? {
        guard let selectedDate else { return nil }
        return series.points(for: metric).min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var insight: AnalyticsInsight {
        let count = series.points(for: metric).count
        let policy = StandardStrengthAnalyticsPolicy()
        return policy.evaluateInsight(sessionCount: count, takeaway: takeaway)
    }

    var body: some View {
        GymChartCard(
            title: series.name,
            evidence: evidenceLevel.evidenceText(comparableSessionCount: series.points(for: metric).count),
            takeaway: takeaway,
            insight: insight
        ) {
            Picker("Metric", selection: $metric) {
                ForEach(HistoryProgressMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if series.points(for: metric).isEmpty {
                Text("Not enough data for this metric yet.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
            } else {
                if let selectedPoint {
                    GymChartSelectionAnnotation(
                        title: selectedPoint.date.formatted(.dateTime.month(.abbreviated).day()),
                        value: formatted(selectedPoint.value)
                    )
                }
                Chart(series.points(for: metric)) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gymPrimary.opacity(0.16), Color.gymPrimary.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                    .symbolSize(64)
                    if selectedPoint?.id == point.id {
                        RuleMark(x: .value("Selected session", point.date))
                            .foregroundStyle(Color.gymPrimary.opacity(0.42))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.gymBorder)
                        AxisTick().foregroundStyle(Color.gymBorder)
                        AxisValueLabel().foregroundStyle(Color.gymSubduedText)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.gymBorder)
                        AxisTick().foregroundStyle(Color.gymBorder)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .frame(height: ComponentSize.compactChartHeight)
                // `children: .ignore` so the label below is what VoiceOver
                // reads. Without it the chart's own marks stay traversable and
                // shadow it — the frequency chart already did this; this one
                // did not.
                .accessibilityElement(children: .ignore)
                // Not "trend": VoiceOver would assert a pattern the evidence line
        // beneath may be explicitly declining to claim.
        .accessibilityLabel("\(series.name) \(metric.title) over time")
                .accessibilityValue(seriesAccessibilityValue)
            }
        }
        .onAppear {
            selectedDate = series.points(for: metric).last?.date
        }
        .onChange(of: metric) { _, newMetric in
            selectedDate = series.points(for: newMetric).last?.date
        }
    }

    private var evidenceLevel: StrengthEvidenceLevel {
        .resolve(comparableSessionCount: series.points(for: metric).count)
    }

    /// The one sentence under the chart — and only when the data can carry it.
    ///
    /// This used to make the same percentage claim from two points as from
    /// twenty: "The latest value was 24% higher than the first recorded
    /// value", drawn across a chart whose width implied months of evidence.
    /// With a single comparison the direction is as likely to be a good day as
    /// a change in strength, so two or three sessions now get the same
    /// sentence explicitly marked as early, and one session gets no direction
    /// at all — just the value it actually recorded.
    private var takeaway: String? {
        let points = series.points(for: metric)
        guard let first = points.first, let last = points.last else { return nil }

        let level = evidenceLevel
        guard level.allowsDirectionalClaim else {
            let format = String(
                localized: "strength.takeaway.latestOnly",
                defaultValue: "Latest completed-session value: %@. A second session is needed before anything can be called a change."
            )
            return String(format: format, formatted(last.value))
        }

        guard first.value != 0 else { return "No non-zero baseline is available for a percentage comparison." }
        let change = (last.value - first.value) / abs(first.value)
        let percentage = Int((abs(change) * 100).rounded())
        if percentage < 1 {
            return level == .trend
                ? String(localized: "The first and latest completed-session values were about the same.")
                : String(localized: "So far the first and latest completed-session values are about the same.")
        }

        let format = level == .trend
            ? String(
                localized: "strength.takeaway.trend",
                defaultValue: "The latest value was %1$lld%% %2$@ than the first recorded value."
            )
            : String(
                localized: "strength.takeaway.early",
                defaultValue: "Across only a few sessions so far, the latest value was %1$lld%% %2$@ than the first recorded value."
            )
        let direction = change > 0
            ? String(localized: "higher")
            : String(localized: "lower")
        return String(format: format, Int64(percentage), direction)
    }

    /// Every period, but summarised past a readable length.
    ///
    /// Concatenating an unbounded series produced a single utterance that could
    /// run for minutes on a long history — technically complete, practically
    /// unusable. The recent points are what a trend question is about, so those
    /// are spoken and the remainder is counted.
    private var seriesAccessibilityValue: String {
        let points = series.points(for: metric)
        guard !points.isEmpty else { return String(localized: "No data") }

        let spokenLimit = 12
        let spoken = points.suffix(spokenLimit).map {
            "\($0.date.formatted(.dateTime.month(.abbreviated).day())): \(formatted($0.value))"
        }.joined(separator: ", ")

        guard points.count > spokenLimit else { return spoken }
        let earlier = points.count - spokenLimit
        return String(localized: "Most recent \(spokenLimit) of \(points.count) values. \(spoken). \(earlier) earlier values not listed.")
    }

    private func formatted(_ value: Float) -> String {
        switch metric {
        case .load: "\(Formatters.formatFloat(value)) \(series.unit)"
        case .volume: "\(Formatters.formatGroupedMetric(value)) volume"
        case .reps: "\(Formatters.formatFloat(value)) reps"
        }
    }
}

enum HistoryProgressMetric: String, CaseIterable, Identifiable {
    case load
    case volume
    case reps

    var id: Self { self }

    var title: String {
        switch self {
        case .load: "Load"
        case .volume: "Volume"
        case .reps: "Reps"
        }
    }
}

struct HistoryExerciseSeries: Identifiable {
    // The historical identity (`HistoricalExerciseIdentityPolicy`), not the
    // display name — two exercises can share a name, and one exercise's name
    // can change, so only the identity is safe to key SwiftUI's diffing on.
    let id: UUID
    var name: String
    let unit: String
    var loadPoints: [HistoryMetricPoint] = []
    var volumePoints: [HistoryMetricPoint] = []
    var repsPoints: [HistoryMetricPoint] = []

    var totalPointCount: Int { loadPoints.count + volumePoints.count + repsPoints.count }

    func points(for metric: HistoryProgressMetric) -> [HistoryMetricPoint] {
        switch metric {
        case .load: loadPoints
        case .volume: volumePoints
        case .reps: repsPoints
        }
    }

    func summary(for metric: HistoryProgressMetric) -> String {
        guard let value = points(for: metric).last?.value else { return "—" }
        switch metric {
        case .load: return "\(Formatters.formatFloat(value)) \(unit)"
        case .volume: return "\(Formatters.formatFloat(value))"
        case .reps: return "\(Formatters.formatFloat(value)) reps"
        }
    }
}

struct HistoryMetricPoint: Identifiable {
    let date: Date
    let value: Float
    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(value)" }
}

struct HistoryFrequencyPoint: Identifiable {
    let start: Date
    let count: Int
    var id: Date { start }
}

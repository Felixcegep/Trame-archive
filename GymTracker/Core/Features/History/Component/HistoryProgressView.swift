import Charts
import SwiftData
import SwiftUI

struct HistoryProgressView: View {
    let workouts: [Workout]

    var body: some View {
        let series = exerciseSeries
        let frequency = frequencyPoints

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Progress")
                        .font(AppFont.displayMedium)
                    Text("Trends from completed workouts only.")
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
                        Text("Exercise trends")
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

    private var exerciseSeries: [HistoryExerciseSeries] {
        var byName: [String: HistoryExerciseSeries] = [:]
        let displayWeightType: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs

        for workout in workouts.sorted(by: { $0.startTime < $1.startTime }) {
            for exercise in workout.orderedExercises {
                let completedSets = exercise.orderedSets.filter(\.done)
                let trackingType = exercise.trackingTypeSnapshot
                let weightedSets = completedSets.filter { _ in trackingType.usesWeight }
                let load = weightedSets
                    .map { UnitConversion.weight($0.weight, from: $0.weightType, to: displayWeightType) }
                    .max()
                let semantics = exercise.loggingSemanticsSnapshot
                let volume = trackingType.usesWeight && trackingType.usesReps
                    ? completedSets.reduce(Float.zero) { total, set in
                        total + VolumeCalculator.setVolume(
                            weight: set.weight,
                            weightType: set.weightType,
                            repetitions: set.repetitions,
                            semantics: semantics,
                            in: displayWeightType
                        )
                    }
                    : 0
                let reps = completedSets.reduce(Float.zero) { $0 + (trackingType.usesReps ? $1.repetitions : 0) }

                guard load != nil || volume > 0 || reps > 0 else { continue }
                var series = byName[exercise.nameSnapshot] ?? HistoryExerciseSeries(
                    name: exercise.nameSnapshot,
                    unit: trackingType.usesWeight ? displayWeightType.rawValue : ""
                )
                if let load {
                    series.loadPoints.append(HistoryMetricPoint(date: workout.startTime, value: load))
                }
                if volume > 0 {
                    series.volumePoints.append(HistoryMetricPoint(date: workout.startTime, value: volume))
                }
                if reps > 0 {
                    series.repsPoints.append(HistoryMetricPoint(date: workout.startTime, value: reps))
                }
                byName[exercise.nameSnapshot] = series
            }
        }

        return byName.values.sorted { $0.totalPointCount > $1.totalPointCount }
    }

    private var frequencyPoints: [HistoryFrequencyPoint] {
        let calendar = Calendar.autoupdatingCurrent
        guard let currentStart = calendar.dateInterval(of: .weekOfYear, for: Date.now)?.start else { return [] }
        let starts: [(start: Date, end: Date)] = (0..<8).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset - 7, to: currentStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            return (start, end)
        }
        var counts = Array(repeating: 0, count: starts.count)
        for workout in workouts {
            for (index, interval) in starts.enumerated() where workout.startTime >= interval.0 && workout.startTime < interval.1 {
                counts[index] += 1
                break
            }
        }
        return starts.enumerated().map { index, interval in
            HistoryFrequencyPoint(start: interval.0, count: counts[index])
        }
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
            titleIdentifier: "training-frequency-chart"
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
                    y: .value("Workouts", point.count)
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
                AxisMarks(position: .leading, values: .stride(by: 1))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.gymText.opacity(0.08))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
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
        return "You completed \(abs(recent - previous)) \(recent > previous ? "more" : "fewer") workouts in the recent four weeks."
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

    var body: some View {
        GymChartCard(
            title: series.name,
            evidence: "\(series.points(for: metric).count) completed-session values.",
            takeaway: takeaway
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
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                    if selectedPoint?.id == point.id {
                        RuleMark(x: .value("Selected session", point.date))
                            .foregroundStyle(Color.gymPrimary.opacity(0.42))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: ComponentSize.compactChartHeight)
                // `children: .ignore` so the label below is what VoiceOver
                // reads. Without it the chart's own marks stay traversable and
                // shadow it — the frequency chart already did this; this one
                // did not.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(series.name) \(metric.title) trend")
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

    private var takeaway: String? {
        let points = series.points(for: metric)
        guard let first = points.first, let last = points.last else { return nil }
        guard points.count >= 2 else { return "Early pattern — one completed-session value is available." }
        guard first.value != 0 else { return "No non-zero baseline is available for a percentage comparison." }
        let change = (last.value - first.value) / abs(first.value)
        let percentage = Int((abs(change) * 100).rounded())
        if percentage < 1 { return "The first and latest completed-session values were about the same." }
        return "The latest value was \(percentage)% \(change > 0 ? "higher" : "lower") than the first recorded value."
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
    let name: String
    let unit: String
    var loadPoints: [HistoryMetricPoint] = []
    var volumePoints: [HistoryMetricPoint] = []
    var repsPoints: [HistoryMetricPoint] = []

    var id: String { name }
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

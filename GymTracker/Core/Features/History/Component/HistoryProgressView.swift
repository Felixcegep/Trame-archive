import Charts
import SwiftData
import SwiftUI

struct HistoryProgressView: View {
    let workouts: [Workout]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Progress")
                        .font(AppFont.displayMedium)
                    Text("Trends from completed workouts only.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }

                frequencyCard

                if exerciseSeries.isEmpty {
                    ContentUnavailableView(
                        "No measurable progress yet",
                        systemImage: AppIcon.chart,
                        description: Text("Complete weighted or rep-based sets to see exercise trends.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Exercise trends")
                            .font(AppFont.titleSmallSemibold)

                        ForEach(Array(exerciseSeries.prefix(5))) { series in
                            HistoryExerciseProgressCard(series: series)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
    }

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Label("Training frequency", systemImage: AppIcon.history)
                    .font(AppFont.headlineSemibold)
                Spacer()
                Text("Last 8 weeks")
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            Chart(frequencyPoints) { point in
                BarMark(
                    x: .value("Week", point.start, unit: .weekOfYear),
                    y: .value("Workouts", point.count)
                )
                .foregroundStyle(Color.gymPrimary.gradient)
                .cornerRadius(Radius.small)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 1))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 150)
            .accessibilityLabel("Workout frequency for the last eight weeks")
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var exerciseSeries: [HistoryExerciseSeries] {
        var byName: [String: HistoryExerciseSeries] = [:]
        let displayWeightType: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs

        for workout in workouts.sorted(by: { $0.startTime < $1.startTime }) {
            for exercise in workout.orderedExercises {
                let completedSets = exercise.orderedSets.filter(\.done)
                let weightedSets = completedSets.filter { _ in exercise.exercise.trackingType.usesWeight }
                let load = weightedSets
                    .map { UnitConversion.weight($0.weight, from: $0.weightType, to: displayWeightType) }
                    .max()
                let volume = completedSets.reduce(Float.zero) { total, set in
                    guard exercise.exercise.trackingType.usesWeight, exercise.exercise.trackingType.usesReps else { return total }
                    let displayWeight = UnitConversion.weight(set.weight, from: set.weightType, to: displayWeightType)
                    return total + (displayWeight * set.repetitions)
                }
                let reps = completedSets.reduce(Float.zero) { $0 + (exercise.exercise.trackingType.usesReps ? $1.repetitions : 0) }

                guard load != nil || volume > 0 || reps > 0 else { continue }
                var series = byName[exercise.exercise.name] ?? HistoryExerciseSeries(
                    name: exercise.exercise.name,
                    unit: exercise.exercise.trackingType.usesWeight ? displayWeightType.rawValue : ""
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
                byName[exercise.exercise.name] = series
            }
        }

        return byName.values.sorted { $0.totalPointCount > $1.totalPointCount }
    }

    private var frequencyPoints: [HistoryFrequencyPoint] {
        let calendar = Calendar.autoupdatingCurrent
        guard let currentStart = calendar.dateInterval(of: .weekOfYear, for: Date.now)?.start else { return [] }

        return (0..<8).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset - 7, to: currentStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let count = workouts.filter { $0.startTime >= start && $0.startTime < end }.count
            return HistoryFrequencyPoint(start: start, count: count)
        }
    }
}

struct HistoryExerciseProgressCard: View {
    let series: HistoryExerciseSeries
    @State private var metric: HistoryProgressMetric = .load

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text(series.name)
                    .font(AppFont.headlineSemibold)
                Spacer()
                Text(series.summary(for: metric))
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymPrimary)
            }

            Picker("Metric", selection: $metric) {
                ForEach(HistoryProgressMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if series.points(for: metric).isEmpty {
                Text("Not enough data for this metric yet.")
                    .font(AppFont.footnote)
                    .foregroundStyle(WorkoutPalette.subduedText)
            } else {
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
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 140)
                .accessibilityLabel("\(series.name) \(metric.title) trend")
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
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

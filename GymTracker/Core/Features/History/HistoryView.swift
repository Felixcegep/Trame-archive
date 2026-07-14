//
//  HistoryView.swift
//  GymTracker
//

import Foundation
import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    let viewModel: WorkoutViewModel
    var onStartFreeWorkout: (() -> Void)? = nil
    @State private var selectedTab: HistoryTab = .workouts

    var body: some View {
        Group {
            if completedWorkouts.isEmpty {
                ContentUnavailableView {
                    Label("No Workout History", systemImage: AppIcon.history)
                        .foregroundStyle(Color.gymAccent)
                } description: {
                    Text("Completed workouts will appear here.")
                } actions: {
                    if let onStartFreeWorkout {
                        Button("Start a workout", action: onStartFreeWorkout)
                            .buttonStyle(.borderedProminent)
                            .tint(Color.gymPrimary)
                            .accessibilityIdentifier("history-start-workout")
                    }
                }
            } else {
                VStack(spacing: 0) {
                    Picker("History view", selection: $selectedTab) {
                        ForEach(HistoryTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)

                    switch selectedTab {
                    case .workouts:
                        List {
                            ForEach(historySections) { section in
                                Section(section.title) {
                                    ForEach(section.workouts) { workout in
                                        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                                            HistoryWorkoutRow(workout: workout)
                                        }
                                        .contentShape(Rectangle())
                                        .accessibilityIdentifier("history-workout-row")
                                        .listRowBackground(Color.gymCard)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                viewModel.removeWorkout(using: modelContext, workout: workout)
                                            } label: {
                                                Label("Delete", systemImage: AppIcon.trash)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    case .progress:
                        HistoryProgressView(workouts: completedWorkouts)
                    case .records:
                        HistoryRecordsView(workouts: completedWorkouts)
                    }
                }
            }
        }
        .background(Color.gymBackground)
        .accessibilityIdentifier("history-screen")
        .navigationTitle("History")
    }

    private var completedWorkouts: [Workout] {
        workouts.filter { workout in
            workout.status == .completed && workout.orderedExercises.contains { exercise in
                exercise.orderedSets.contains(where: \.done)
            }
        }
    }

    private var historySections: [HistorySection] {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        var today: [Workout] = []
        var thisWeek: [Workout] = []
        var months: [Date: [Workout]] = [:]

        for workout in completedWorkouts {
            if calendar.isDateInToday(workout.startTime) {
                today.append(workout)
            } else if weekInterval?.contains(workout.startTime) == true {
                thisWeek.append(workout)
            } else if let monthStart = calendar.dateInterval(of: .month, for: workout.startTime)?.start {
                months[monthStart, default: []].append(workout)
            }
        }

        var sections: [HistorySection] = []
        if !today.isEmpty {
            sections.append(HistorySection(id: "today", title: "Today", workouts: today))
        }
        if !thisWeek.isEmpty {
            sections.append(HistorySection(id: "this-week", title: "This Week", workouts: thisWeek))
        }
        sections.append(contentsOf: months.keys.sorted(by: >).map { monthStart in
            HistorySection(
                id: "month-\(monthStart.timeIntervalSinceReferenceDate)",
                title: monthStart.formatted(.dateTime.month(.wide).year()),
                workouts: months[monthStart] ?? []
            )
        })
        return sections
    }
}

private enum HistoryTab: String, CaseIterable, Identifiable {
    case workouts
    case progress
    case records

    var id: Self { self }

    var title: String {
        switch self {
        case .workouts: "Workouts"
        case .progress: "Progress"
        case .records: "Records"
        }
    }
}

private struct HistorySection: Identifiable {
    let id: String
    let title: String
    let workouts: [Workout]
}

private struct HistoryWorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Text(workoutTitle)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                Text(workoutDate)
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
                    .lineLimit(1)
            }

            HStack(spacing: Spacing.m) {
                metadataItem(workoutDuration, icon: AppIcon.timer)
                metadataItem(exerciseSummary, icon: AppIcon.workout)
                metadataItem(setSummary, icon: AppIcon.checkmarkCircle)
            }

            if let sourceName {
                Label("From \(sourceName)", systemImage: AppIcon.folders)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func metadataItem(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppFont.caption)
            .foregroundStyle(WorkoutPalette.subduedText)
            .lineLimit(1)
    }

    private var workoutTitle: String {
        workout.displayTitle
    }

    private var workoutDate: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(workout.startTime) {
            return "Today, \(workout.startTime.formatted(date: .omitted, time: .shortened))"
        }
        return workout.startTime.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var workoutDuration: String {
        guard let endTime = workout.endTime else { return "0 min" }
        let minutes = max(1, Int(endTime.timeIntervalSince(workout.startTime)) / 60)
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes) min"
    }

    private var exerciseSummary: String {
        let count = workout.orderedExercises.count
        return "\(count) \(count == 1 ? "exercise" : "exercises")"
    }

    private var setSummary: String {
        let count = workout.completedSetCount
        return "\(count) \(count == 1 ? "set" : "sets")"
    }

    private var sourceName: String? {
        if let templateName = workout.sourceTemplate?.name, !templateName.isEmpty {
            return templateName
        }
        if let planName = workout.sourcePlanName, !planName.isEmpty {
            return planName
        }
        return nil
    }

    private var accessibilitySummary: String {
        var values = [workoutTitle, workoutDate, workoutDuration, exerciseSummary, setSummary]
        if let sourceName { values.append("From \(sourceName)") }
        return values.joined(separator: ", ")
    }
}

private struct HistoryProgressView: View {
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
            .padding(.horizontal, Spacing.l)
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
                let weightedSets = completedSets.filter { _ in exercise.exercice.trackingType.usesWeight }
                let load = weightedSets
                    .map { UnitConversion.weight($0.weight, from: $0.weightType, to: displayWeightType) }
                    .max()
                let volume = completedSets.reduce(Float.zero) { total, set in
                    guard exercise.exercice.trackingType.usesWeight, exercise.exercice.trackingType.usesReps else { return total }
                    let displayWeight = UnitConversion.weight(set.weight, from: set.weightType, to: displayWeightType)
                    return total + (displayWeight * set.repetition)
                }
                let reps = completedSets.reduce(Float.zero) { $0 + (exercise.exercice.trackingType.usesReps ? $1.repetition : 0) }

                guard load != nil || volume > 0 || reps > 0 else { continue }
                var series = byName[exercise.exercice.name] ?? HistoryExerciseSeries(
                    name: exercise.exercice.name,
                    unit: exercise.exercice.trackingType.usesWeight ? displayWeightType.rawValue : ""
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
                byName[exercise.exercice.name] = series
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

private struct HistoryExerciseProgressCard: View {
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

private enum HistoryProgressMetric: String, CaseIterable, Identifiable {
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

private struct HistoryExerciseSeries: Identifiable {
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

private struct HistoryMetricPoint: Identifiable {
    let date: Date
    let value: Float
    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(value)" }
}

private struct HistoryFrequencyPoint: Identifiable {
    let start: Date
    let count: Int
    var id: Date { start }
}

private struct HistoryRecordsView: View {
    let workouts: [Workout]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Records")
                        .font(AppFont.displayMedium)
                    Text("Personal bests from completed workouts.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }

                if bestLoadRecords.isEmpty && bestRepRecords.isEmpty && notableSessions.isEmpty {
                    ContentUnavailableView(
                        "No records yet",
                        systemImage: AppIcon.trophy,
                        description: Text("Complete weighted or rep-based sets to establish personal bests.")
                    )
                } else {
                    if !bestLoadRecords.isEmpty {
                        recordsSection("Best load", icon: AppIcon.workout, records: bestLoadRecords)
                    }
                    if !bestRepRecords.isEmpty {
                        recordsSection("Best reps", icon: AppIcon.number, records: bestRepRecords)
                    }
                    if !notableSessions.isEmpty {
                        notableSection
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
    }

    private func recordsSection(_ title: String, icon: String, records: [HistoryRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label(title, systemImage: icon)
                .font(AppFont.titleSmallSemibold)
            ForEach(records) { record in
                recordRow(record)
            }
        }
    }

    private var notableSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("Notable sessions", systemImage: AppIcon.favoriteFilled)
                .font(AppFont.titleSmallSemibold)
            ForEach(notableSessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(session.title)
                            .font(AppFont.bodyMedium)
                        Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }
                    Spacer()
                    Text("\(Formatters.formatFloat(session.volume)) volume")
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymPrimary)
                }
                .padding(Spacing.m)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
    }

    private func recordRow(_ record: HistoryRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(record.exercise)
                    .font(AppFont.bodyMedium)
                Text(record.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }
            Spacer()
            Text(record.valueText)
                .font(AppFont.headlineMonospaced)
                .foregroundStyle(Color.gymPrimary)
        }
        .padding(Spacing.m)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .combine)
    }

    private var bestLoadRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises where exercise.exercice.trackingType.usesWeight {
                for set in exercise.orderedSets where set.done && set.weight > 0 {
                    let candidate = HistoryRecord(exercise: exercise.exercice.name, value: set.weight, unit: set.weightType.rawValue, date: workout.startTime, kind: "load")
                    if candidate.value > (best[exercise.exercice.name]?.value ?? 0) { best[exercise.exercice.name] = candidate }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var bestRepRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises where exercise.exercice.trackingType.usesReps {
                for set in exercise.orderedSets where set.done && set.repetition > 0 {
                    let candidate = HistoryRecord(exercise: exercise.exercice.name, value: set.repetition, unit: "reps", date: workout.startTime, kind: "reps")
                    if candidate.value > (best[exercise.exercice.name]?.value ?? 0) { best[exercise.exercice.name] = candidate }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var notableSessions: [HistorySessionRecord] {
        workouts.map { workout in
            let volume = workout.orderedExercises.reduce(Float.zero) { total, exercise in
                total + exercise.orderedSets.filter(\.done).reduce(Float.zero) { subtotal, set in
                    subtotal + (exercise.exercice.trackingType.usesWeight && exercise.exercice.trackingType.usesReps ? set.weight * set.repetition : 0)
                }
            }
            return HistorySessionRecord(title: workout.displayTitle, volume: volume, date: workout.startTime)
        }
        .filter { $0.volume > 0 }
        .sorted { $0.volume > $1.volume }
        .prefix(3)
        .map { $0 }
    }
}

private struct HistoryRecord: Identifiable {
    let exercise: String
    let value: Float
    let unit: String
    let date: Date
    let kind: String

    var id: String { "\(kind)-\(exercise)-\(date.timeIntervalSinceReferenceDate)" }
    var valueText: String { "\(Formatters.formatFloat(value)) \(unit)" }
}

private struct HistorySessionRecord: Identifiable {
    let title: String
    let volume: Float
    let date: Date
    var id: String { "\(title)-\(date.timeIntervalSinceReferenceDate)" }
}

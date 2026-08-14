import Charts
import SwiftData
import SwiftUI

struct ExerciseDetailInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let model: ExerciseDetailInsightsModel

    var body: some View {
        Group {
            if model.hasHistory {
                insightsContent
            } else {
                emptyState
            }
        }
        .background(Color.gymBackground.ignoresSafeArea())
        .navigationTitle(model.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: AppIcon.chevronLeft)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("exercise-insights-back")
            }
        }
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("exercise-insights-screen", label: "Exercise insights")
        }
    }

    private var insightsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                if model.hasInsufficientHistory {
                    InsufficientExerciseHistoryCard(sessionCount: model.historyCount)
                }


                if let latestSession = model.latestSession {
                    ExerciseSessionSection(
                        session: latestSession,
                        workout: latestSession.workoutID.flatMap(completedWorkout)
                    )
                }

                if let changeSummary = model.changeSummary {
                    ExerciseChangeSection(summary: changeSummary)
                }

                if let progression = model.progression {
                    ExerciseProgressionSection(progression: progression)
                }

                if !model.volumePoints.isEmpty {
                    ExerciseVolumeChartSection(
                        points: model.volumePoints,
                        historyCount: model.historyCount,
                        takeaway: model.volumeTakeaway,
                        insight: model.insight
                    )
                }

                if !model.bestResults.isEmpty {
                    ExerciseBestResultsSection(results: model.bestResults)
                }

                if let estimatedOneRepMax = model.estimatedOneRepMax {
                    EstimatedOneRepMaxSection(metric: estimatedOneRepMax)
                } else if let reason = model.estimatedOneRepMaxUnavailableReason {
                    EstimatedOneRepMaxUnavailableSection(reason: reason)
                }

                if !model.notes.isEmpty {
                    ExerciseNotesSection(notes: model.notes)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l)
            .padding(.bottom, 112)
        }
        .accessibilityIdentifier("exercise-insights-content")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No completed history yet",
            systemImage: AppIcon.chart,
            description: Text("Complete a workout with this exercise to see performance insights here.")
        )
        .accessibilityIdentifier("exercise-insights-empty")
    }

    private func completedWorkout(id: UUID) -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first.flatMap { $0.status == .completed ? $0 : nil }
    }
}

private struct InsufficientExerciseHistoryCard: View {
    let sessionCount: Int

    var body: some View {
        let level = StrengthEvidenceLevel.resolve(comparableSessionCount: sessionCount)
        let title = level.title ?? (sessionCount == 1 ? String(localized: "Latest result") : String(localized: "Early comparison"))
        GymCard(variant: .current) {
            Label(title, systemImage: AppIcon.info)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
            Text("Based on \(sessionCount) completed \(sessionCount == 1 ? "session" : "sessions"). Keep logging before treating changes as a trend.")
                .font(AppFont.subheadline)
        }
        .accessibilityIdentifier("exercise-insights-insufficient-history")
    }
}

private struct ExerciseSessionSection: View {
    let session: ExerciseDetailSession
    let workout: Workout?

    var body: some View {
        InsightSection(title: "Latest performance", identifier: "exercise-insights-last-session") {
            if let workout {
                NavigationLink {
                    HistoryWorkoutView(workout: workout)
                } label: {
                    sessionCard
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the completed workout in History")
            } else {
                sessionCard
            }
        }
    }

    private var sessionCard: some View {
        GymCard {
            HStack(alignment: .firstTextBaseline) {
                Text(session.date)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Text(session.summary)
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Divider()
            ForEach(session.sets) { set in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    Text(set.label)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(width: 44, alignment: .leading)
                    Text(set.value)
                        .font(AppFont.bodyMedium.monospacedDigit())
                    Spacer()
                    if let detail = set.detail {
                        Text(detail)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymAccent)
                    }
                }
            }
        }
    }
}

private struct ExerciseChangeSection: View {
    let summary: String

    var body: some View {
        InsightSection(title: "What changed", identifier: "exercise-insights-comparison") {
            GymCard {
                Label(summary, systemImage: AppIcon.history)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymText)
            }
        }
    }
}

private struct ExerciseProgressionSection: View {
    let progression: ExerciseDetailProgression

    var body: some View {
        InsightSection(title: "Next suggestion", identifier: "exercise-insights-progression") {
            GymCard(variant: .completed) {
                Label(progression.title, systemImage: AppIcon.progression)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSecondary)
                Text(progression.explanation)
                    .font(AppFont.subheadline)
                if let actionLabel = progression.actionLabel {
                    Text(actionLabel)
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymSecondary)
                }
            }
        }
    }
}

private struct ExerciseVolumeChartSection: View {
    let points: [ExerciseDetailVolumePoint]
    let historyCount: Int
    let takeaway: String?
    let insight: AnalyticsInsight?

    @State private var selectedDate: Date?

    init(points: [ExerciseDetailVolumePoint], historyCount: Int, takeaway: String?, insight: AnalyticsInsight? = nil) {
        self.points = points
        self.historyCount = historyCount
        self.takeaway = takeaway
        self.insight = insight
        _selectedDate = State(initialValue: points.last(where: { $0.sessionCount > 0 })?.date ?? points.last?.date)
    }

    private var selectedPoint: ExerciseDetailVolumePoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        GymChartCard(
            title: "Completed volume · 8 weeks",
            evidence: "Based on \(historyCount) completed \(historyCount == 1 ? "session" : "sessions").",
            takeaway: takeaway,
            insight: insight
        ) {
            if let selectedPoint {
                GymChartSelectionAnnotation(
                    title: selectedPoint.label,
                    value: selectedPoint.sessionCount == 0
                        ? "No completed sets"
                        : "\(Formatters.formatGroupedMetric(Float(selectedPoint.value))) \(selectedPoint.unit) volume",
                    detail: selectedPoint.sessionCount == 0
                        ? nil
                        : "\(selectedPoint.workingSetCount) working sets · \(selectedPoint.sessionCount) \(selectedPoint.sessionCount == 1 ? "session" : "sessions")"
                )
            }

            Chart(points) { point in
                AreaMark(
                    x: .value("Week", point.date),
                    y: .value("Volume", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.gymPrimary.opacity(0.16), Color.gymPrimary.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.linear)

                LineMark(
                    x: .value("Week", point.date),
                    y: .value("Volume", point.value)
                )
                .foregroundStyle(Color.gymPrimary)
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Week", point.date),
                    y: .value("Volume", point.value)
                )
                .symbol(point.sessionCount == 0 ? .diamond : .circle)
                .foregroundStyle(point.sessionCount == 0 ? Color.gymSubduedText : Color.gymPrimary)
                .symbolSize(64)

                if selectedPoint?.id == point.id {
                    RuleMark(x: .value("Selected week", point.date))
                        .foregroundStyle(Color.gymPrimary.opacity(0.42))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .frame(height: ComponentSize.compactChartHeight)
            .chartXSelection(value: $selectedDate)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.gymBorder)
                    AxisTick().foregroundStyle(Color.gymBorder)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Eight-week completed exercise volume")
            .accessibilityValue(points.map { "\($0.label): \($0.accessibilityValue)" }.joined(separator: ", "))
        }
        .accessibilityIdentifier("exercise-insights-volume")
    }
}

private struct ExerciseBestResultsSection: View {
    let results: [ExerciseDetailBestResult]

    var body: some View {
        InsightSection(title: "Records", identifier: "exercise-insights-best-results") {
            GymCard {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(result.title)
                                .font(AppFont.subheadline)
                                .foregroundStyle(Color.gymSubduedText)
                            if let detail = result.detail {
                                Text(detail)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        Spacer()
                        Text(result.value)
                            .font(AppFont.subheadlineSemiboldMonospaced)
                    }
                }
            }
        }
    }
}

private struct EstimatedOneRepMaxSection: View {
    let metric: ExerciseDetailMetric

    var body: some View {
        InsightSection(title: "Estimated 1RM", identifier: "exercise-insights-estimated-1rm") {
            GymCard {
                HStack(alignment: .firstTextBaseline) {
                    GymMetricValue(value: metric.value, unit: metric.unit, isEstimate: true, prominence: .display)
                    Spacer()
                    Image(systemName: AppIcon.progression)
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymPrimary)
                }
                // Names this a calculated estimate, not a measured max, and
                // does not compare it against an earlier estimate — a change
                // here reflects a change in the formula's input set, not a
                // confirmed change in maximal strength.
                Text("Estimate from your best qualifying working set, not a tested maximum.")
                    .font(AppFont.subheadline)
                if let context = metric.context {
                    Text(context)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
    }
}

private struct EstimatedOneRepMaxUnavailableSection: View {
    let reason: String

    var body: some View {
        InsightSection(title: "Estimated 1RM", identifier: "exercise-insights-estimated-1rm") {
            GymCard {
                Text(reason)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .accessibilityIdentifier("exercise-insights-estimated-1rm-unavailable")
        }
    }
}

private struct ExerciseNotesSection: View {
    let notes: [ExerciseDetailNote]

    var body: some View {
        InsightSection(title: "Notes history", identifier: "exercise-insights-notes") {
            GymCard {
                ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(note.date)
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.gymSubduedText)
                        Text(note.text)
                            .font(AppFont.subheadline)
                    }
                }
            }
        }
    }
}

private struct InsightSection<Content: View>: View {
    let title: String
    let identifier: String
    @ViewBuilder let content: Content

    init(title: String, identifier: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.identifier = identifier
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: title)
            content
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview("Exercise Insights") {
    NavigationStack { ExerciseDetailInsightsView(model: .previewFull) }
}

#Preview("Exercise Insights — Insufficient History") {
    NavigationStack { ExerciseDetailInsightsView(model: .previewInsufficient) }
}

#Preview("Exercise Insights — Empty") {
    NavigationStack { ExerciseDetailInsightsView(model: .previewEmpty) }
}

import Charts
import SwiftData
import SwiftUI

struct ExerciseDetailInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let model: ExerciseDetailInsightsModel

    var body: some View {
        Group {
            if !model.hasHistory {
                emptyState
            } else {
                insightsContent
            }
        }
        .background(Color.gymBackground.ignoresSafeArea())
        .navigationTitle(model.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
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

    private var emptyState: some View {
        ContentUnavailableView(
            "No completed history yet",
            systemImage: AppIcon.chart,
            description: Text("Complete a workout with this exercise to see performance insights here.")
        )
        .accessibilityIdentifier("exercise-insights-empty")
    }

    private var insightsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                if model.hasInsufficientHistory {
                    insufficientHistoryCard
                }

                if let latestSession = model.latestSession {
                    sessionSection(title: "Last session", session: latestSession, identifier: "exercise-insights-last-session")
                }

                if let previousSession = model.previousSession,
                   let latestSession = model.latestSession {
                    comparisonSection(latest: latestSession, previous: previousSession)
                }

                if !model.bestResults.isEmpty {
                    bestResultsSection
                }

                if let estimatedOneRepMax = model.estimatedOneRepMax {
                    estimatedOneRepMaxSection(estimatedOneRepMax)
                }

                if !model.volumePoints.isEmpty {
                    volumeSection
                }

                if !model.notes.isEmpty {
                    notesSection
                }

                if let progression = model.progression {
                    progressionSection(progression)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l)
            .padding(.bottom, 112)
        }
        .accessibilityIdentifier("exercise-insights-content")
    }

    private var insufficientHistoryCard: some View {
        InsightCard {
            Label("Build more history", systemImage: AppIcon.info)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
            Text("Keep logging this exercise. More completed sessions will unlock comparisons, trends, and stronger records.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymText)
        }
        .accessibilityIdentifier("exercise-insights-insufficient-history")
    }

    private func sessionSection(
        title: String,
        session: ExerciseDetailSession,
        identifier: String
    ) -> some View {
        insightSection(title: title, identifier: identifier) {
            if let workoutID = session.workoutID,
               let workout = completedWorkout(id: workoutID) {
                NavigationLink {
                    HistoryWorkoutView(workout: workout)
                } label: {
                    sessionCard(session)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the completed workout in History")
            } else {
                sessionCard(session)
            }
        }
    }

    private func sessionCard(_ session: ExerciseDetailSession) -> some View {
        InsightCard {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.date)
                        .font(AppFont.subheadlineSemibold)
                    Spacer()
                    Text(session.summary)
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymText.opacity(0.68))
                }

                Divider()

                ForEach(session.sets) { set in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                        Text(set.label)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymText.opacity(0.62))
                            .frame(width: 44, alignment: .leading)
                        Text(set.value)
                            .font(AppFont.bodyMedium.monospacedDigit())
                        Spacer()
                        if let detail = set.detail {
                            Text(detail)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymAccent)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
    }

    private func completedWorkout(id: UUID) -> Workout? {
        try? modelContext.fetch(FetchDescriptor<Workout>()).first {
            $0.id == id && $0.status == .completed
        }
    }

    private func comparisonSection(
        latest: ExerciseDetailSession,
        previous: ExerciseDetailSession
    ) -> some View {
        insightSection(title: "Previous-session comparison", identifier: "exercise-insights-comparison") {
            InsightCard {
                comparisonRow(title: "Latest", value: latest.summary, detail: latest.date)
                comparisonRow(title: "Previous", value: previous.summary, detail: previous.date)
                Label("Compare completed sets and notes in History for the full context.", systemImage: AppIcon.history)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymText.opacity(0.68))
                    .padding(.top, Spacing.xs)
            }
        }
    }

    private func comparisonRow(title: String, value: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(value)
                    .font(AppFont.subheadlineSemiboldMonospaced)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymText.opacity(0.62))
            }
        }
    }

    private var bestResultsSection: some View {
        insightSection(title: "Best results", identifier: "exercise-insights-best-results") {
            InsightCard {
                ForEach(Array(model.bestResults.enumerated()), id: \.element.id) { index, result in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(result.title)
                                .font(AppFont.subheadline)
                                .foregroundStyle(Color.gymText.opacity(0.68))
                            if let detail = result.detail {
                                Text(detail)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymText.opacity(0.58))
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

    private func estimatedOneRepMaxSection(_ metric: ExerciseDetailMetric) -> some View {
        insightSection(title: "Estimated 1RM", identifier: "exercise-insights-estimated-1rm") {
            InsightCard {
                HStack(alignment: .firstTextBaseline) {
                    Text(metric.value)
                        .font(AppFont.displayMedium)
                        .foregroundStyle(Color.gymPrimary)
                    Text(metric.unit)
                        .font(AppFont.titleSmallSemibold)
                    Spacer()
                    Image(systemName: AppIcon.progression)
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymPrimary)
                }
                Text("Estimate only — based on completed historical sets, not a tested max.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymText)
                if let context = metric.context {
                    Text(context)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymText.opacity(0.62))
                }
            }
        }
    }

    private var volumeSection: some View {
        insightSection(title: "Volume · 8 weeks", identifier: "exercise-insights-volume") {
            InsightCard {
                Chart(model.volumePoints) { point in
                    LineMark(
                        x: .value("Week", point.label),
                        y: .value("Volume", point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Week", point.label),
                        y: .value("Volume", point.value)
                    )
                    .foregroundStyle(Color.gymPrimary)
                }
                .frame(height: 180)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Color.gymText.opacity(0.08))
                        AxisValueLabel().font(AppFont.caption)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Eight-week volume trend")
                .accessibilityValue(model.volumePoints.map { "\($0.label): \($0.accessibilityValue)" }.joined(separator: ", "))
            }
        }
    }

    private var notesSection: some View {
        insightSection(title: "Notes history", identifier: "exercise-insights-notes") {
            InsightCard {
                ForEach(Array(model.notes.enumerated()), id: \.element.id) { index, note in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(note.date)
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.gymText.opacity(0.62))
                        Text(note.text)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymText)
                    }
                }
            }
        }
    }

    private func progressionSection(_ progression: ExerciseDetailProgression) -> some View {
        insightSection(title: "Next suggestion", identifier: "exercise-insights-progression") {
            InsightCard {
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

    private func insightSection<Content: View>(
        title: String,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)
            content()
        }
        .accessibilityIdentifier(identifier)
    }
}

private struct InsightCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymText.opacity(0.08), lineWidth: 1)
        }
    }
}

#Preview("Exercise Insights") {
    NavigationStack {
        ExerciseDetailInsightsView(model: .previewFull)
    }
}

#Preview("Exercise Insights — Insufficient History") {
    NavigationStack {
        ExerciseDetailInsightsView(model: .previewInsufficient)
    }
}

#Preview("Exercise Insights — Empty") {
    NavigationStack {
        ExerciseDetailInsightsView(model: .previewEmpty)
    }
}

import Charts
import SwiftData
import SwiftUI

struct HistoryMuscleBalanceDestination: View {
    @Environment(\.modelContext) private var modelContext
    @State private var analytics: MuscleBalanceAnalytics?
    @State private var hasError = false

    var body: some View {
        Group {
            if let analytics {
                HistoryMuscleBalanceView(analytics: analytics)
            } else if hasError {
                ContentUnavailableView(
                    "Balance unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("Completed workout history could not be loaded.")
                )
            } else {
                ProgressView("Loading balance…")
            }
        }
        .task {
            guard analytics == nil, !hasError else { return }
            do {
                analytics = try MuscleBalanceAnalyticsService(modelContext: modelContext).analytics()
            } catch {
                hasError = true
            }
        }
        .navigationTitle("Muscle Balance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HistoryMuscleBalanceView: View {
    let analytics: MuscleBalanceAnalytics

    var body: some View {
        Group {
            if !analytics.hasHistory {
                ContentUnavailableView(
                    "No estimated muscle balance yet",
                    systemImage: AppIcon.chart,
                    description: Text("Complete working sets to see estimated weekly muscle-group balance.")
                )
                .accessibilityIdentifier("muscle-balance-empty")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xxl) {
                        introduction
                        weeklyChart

                        if !analytics.callouts.isEmpty {
                            calloutsSection
                        }

                        summariesSection
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.xxxl)
                }
                .accessibilityIdentifier("muscle-balance-content")
            }
        }
        .background(Color.gymBackground.ignoresSafeArea())
    }

    private var introduction: some View {
        MuscleBalanceCard {
            Label("Estimated working sets", systemImage: AppIcon.info)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
            Text("Primary muscles count as 1.0 set and secondary muscles as 0.5. Warm-ups are excluded. These are estimates, not a measurement of physiological response.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymText)
        }
        .accessibilityIdentifier("muscle-balance-explanation")
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Weekly balance · 8 weeks")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)

            MuscleBalanceCard {
                Chart(chartPoints) { point in
                    BarMark(
                        x: .value("Week", point.weekLabel),
                        y: .value("Estimated sets", point.count)
                    )
                    .foregroundStyle(by: .value("Muscle group", point.group.displayName))
                }
                .chartForegroundStyleScale(
                    domain: chartGroups,
                    range: [Color.gymPrimary, Color.gymSecondary, Color.gymAccent, Color.gymText.opacity(0.68), Color.gymPrimary.opacity(0.7), Color.gymSecondary.opacity(0.7), Color.gymAccent.opacity(0.7), Color.gymText.opacity(0.45), Color.gymPrimary.opacity(0.45), Color.gymSecondary.opacity(0.45)]
                )
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color.gymText.opacity(0.08))
                        AxisValueLabel().font(AppFont.caption)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel().font(AppFont.caption)
                    }
                }
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Eight-week estimated muscle balance")
                .accessibilityValue(chartAccessibilityValue)
            }
        }
        .accessibilityIdentifier("muscle-balance-chart")
    }

    private var calloutsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Worth noticing")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)

            MuscleBalanceCard {
                ForEach(analytics.callouts) { callout in
                    Label {
                        Text(callout.message)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymText)
                    } icon: {
                        Image(systemName: AppIcon.warning)
                            .foregroundStyle(Color.gymAccent)
                    }
                }
            }
            .accessibilityIdentifier("muscle-balance-callouts")
        }
    }

    private var summariesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Last four weeks")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)

            MuscleBalanceCard {
                ForEach(Array(analytics.summaries.enumerated()), id: \.element.id) { index, summary in
                    if index > 0 { Divider() }
                    MuscleBalanceSummaryRow(summary: summary)
                }
            }
            .accessibilityIdentifier("muscle-balance-summaries")
        }
    }

    private var chartGroups: [String] {
        analytics.summaries.map(\.group.displayName)
    }

    private var chartPoints: [MuscleBalanceChartPoint] {
        analytics.weeks.flatMap { week in
            analytics.summaries.compactMap { summary in
                let count = week.count(for: summary.group)
                guard count > 0 else { return nil }
                return MuscleBalanceChartPoint(
                    id: "\(week.id.timeIntervalSinceReferenceDate)-\(summary.group.rawValue)",
                    weekLabel: week.weekStart.formatted(.dateTime.month(.abbreviated).day()),
                    group: summary.group,
                    count: count
                )
            }
        }
    }

    private var chartAccessibilityValue: String {
        chartPoints.map {
            "\($0.weekLabel): \($0.group.displayName) \(Formatters.formatFloat(Float($0.count))) sets"
        }.joined(separator: ", ")
    }
}

private struct MuscleBalanceChartPoint: Identifiable {
    let id: String
    let weekLabel: String
    let group: MuscleBalanceGroup
    let count: Double
}

private struct MuscleBalanceSummaryRow: View {
    let summary: MuscleBalanceSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Text(summary.group.displayName)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(Formatters.formatFloat(Float(summary.recentAverage))) sets / week")
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
                Text(changeText)
                    .font(AppFont.caption)
                    .foregroundStyle(changeColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.group.displayName), \(Formatters.formatFloat(Float(summary.recentAverage))) estimated sets per week, \(changeText)")
    }

    private var changeText: String {
        guard let ratio = summary.changeRatio else {
            return "No previous four-week baseline"
        }
        let percent = Int((abs(ratio) * 100).rounded())
        if percent == 0 { return "About the same as the previous four weeks" }
        return ratio > 0 ? "\(percent)% more than previous" : "\(percent)% less than previous"
    }

    private var changeColor: Color {
        if summary.change > 0 { return Color.gymSecondary }
        if summary.change < 0 { return Color.gymAccent }
        return Color.gymText.opacity(0.62)
    }
}

private struct MuscleBalanceCard<Content: View>: View {
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

#Preview("Muscle Balance") {
    NavigationStack {
        HistoryMuscleBalanceView(
            analytics: MuscleBalanceAnalytics(
                weeks: [],
                summaries: [
                    MuscleBalanceSummary(group: .chest, recentAverage: 8, previousAverage: 6),
                    MuscleBalanceSummary(group: .back, recentAverage: 6, previousAverage: 8),
                    MuscleBalanceSummary(group: .quadriceps, recentAverage: 5, previousAverage: 5),
                    MuscleBalanceSummary(group: .hamstrings, recentAverage: 2, previousAverage: 5)
                ],
                callouts: [
                    MuscleBalanceCallout(group: .hamstrings, message: "Hamstrings received much less estimated work than the previous four-week average.")
                ]
            )
        )
    }
}

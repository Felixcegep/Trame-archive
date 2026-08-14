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
                    "Volume unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("Completed workout history could not be loaded.")
                )
            } else {
                ProgressView("Loading muscle-group volume…")
            }
        }
        .task {
            await loadAnalytics()
        }
        .navigationTitle("Muscle-group volume")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadAnalytics() async {
        guard analytics == nil, !hasError else { return }
        do {
            analytics = try MuscleBalanceAnalyticsService(modelContext: modelContext).analytics()
        } catch {
            hasError = true
        }
    }
}

struct HistoryMuscleBalanceView: View {
    let analytics: MuscleBalanceAnalytics

    @State private var selectedGroup: MuscleBalanceGroup?

    init(analytics: MuscleBalanceAnalytics) {
        self.analytics = analytics
        _selectedGroup = State(initialValue: analytics.summaries.first?.group)
    }

    var body: some View {
        Group {
            if analytics.hasHistory {
                content
            } else {
                ContentUnavailableView(
                    "No estimated muscle-group volume yet",
                    systemImage: AppIcon.chart,
                    description: Text("Complete working sets to see weekly muscle-group training distribution.")
                )
                .accessibilityIdentifier("muscle-balance-empty")
            }
        }
        .background(Color.gymBackground.ignoresSafeArea())
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                methodology
                MuscleGroupRankingSection(
                    summaries: analytics.summaries,
                    selectedGroup: $selectedGroup
                )

                if let selectedGroup {
                    MuscleGroupVolumeChart(
                        group: selectedGroup,
                        weeks: analytics.weeks,
                        summary: analytics.summaries.first { $0.group == selectedGroup }
                    )
                }

                if !analytics.callouts.isEmpty {
                    observation
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private var methodology: some View {
        GymCard(variant: .current) {
            Label("Estimated working sets", systemImage: AppIcon.info)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
            Text("Primary muscles count as 1.0 set and secondary muscles as 0.5. Warm-ups are excluded. This describes training distribution, not physiological response.")
                .font(AppFont.subheadline)
        }
        .accessibilityIdentifier("muscle-balance-explanation")
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("muscle-balance-content", label: "Muscle-group volume content")
        }
    }

    private var observation: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "Worth noticing")
            GymCard(variant: .accent) {
                Label {
                    Text(observationText)
                        .font(AppFont.subheadline)
                } icon: {
                    Image(systemName: AppIcon.warning)
                        .foregroundStyle(Color.gymAccent)
                }
            }
        }
        .accessibilityIdentifier("muscle-balance-callouts")
    }

    private var observationText: String {
        let affected = analytics.callouts.compactMap { callout in
            analytics.summaries.first { $0.group == callout.group }
        }
        guard affected.count > 1 else { return analytics.callouts.first?.message ?? "" }
        let evidence = affected.map {
            "\($0.group.displayName) (\(Formatters.formatFloat(Float($0.recentAverage))) from \(Formatters.formatFloat(Float($0.previousAverage))))"
        }
        let joined: String
        if evidence.count == 2 {
            joined = evidence.joined(separator: " and ")
        } else {
            joined = evidence.dropLast().joined(separator: ", ") + ", and " + (evidence.last ?? "")
        }
        return "Estimated sets per week fell for \(joined) compared with the previous four weeks."
    }
}

private struct MuscleGroupRankingSection: View {
    let summaries: [MuscleBalanceSummary]
    @Binding var selectedGroup: MuscleBalanceGroup?

    @State private var showsAllGroups = false

    private var visibleSummaries: [MuscleBalanceSummary] {
        showsAllGroups ? summaries : Array(summaries.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(
                title: "Last four weeks",
                detail: "Select a muscle group to inspect its weekly evidence."
            )
            GymCard {
                ForEach(Array(visibleSummaries.enumerated()), id: \.element.id) { index, summary in
                    if index > 0 { Divider() }
                    Button {
                        selectedGroup = summary.group
                    } label: {
                        MuscleGroupSummaryRow(
                            summary: summary,
                            isSelected: selectedGroup == summary.group
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityAddTraits(selectedGroup == summary.group ? .isSelected : [])
                }
                if summaries.count > 4 {
                    Divider()
                    Button(showsAllGroups ? "Show fewer muscle groups" : "Show all \(summaries.count) muscle groups") {
                        showsAllGroups.toggle()
                    }
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("muscle-balance-show-all")
                }
            }
            .accessibilityIdentifier("muscle-balance-summaries")
        }
    }
}

private struct MuscleGroupSummaryRow: View {
    let summary: MuscleBalanceSummary
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymSubduedText)
                .accessibilityHidden(true)
            Text(summary.group.displayName)
                .font(AppFont.subheadlineSemibold)
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(Formatters.formatFloat(Float(summary.recentAverage))) sets / week")
                    .font(AppFont.subheadlineSemiboldMonospaced)
                Text(changeText)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.group.displayName), \(Formatters.formatFloat(Float(summary.recentAverage))) estimated sets per week, \(changeText)")
    }

    private var changeText: String {
        guard let ratio = summary.changeRatio else { return "No earlier baseline" }
        let percent = Int((abs(ratio) * 100).rounded())
        if percent == 0 { return "About the same as before" }
        return ratio > 0 ? "\(percent)% more than before" : "\(percent)% less than before"
    }
}

private struct MuscleGroupVolumeChart: View {
    let group: MuscleBalanceGroup
    let weeks: [MuscleBalanceWeek]
    let summary: MuscleBalanceSummary?

    @State private var selectedDate: Date?

    init(group: MuscleBalanceGroup, weeks: [MuscleBalanceWeek], summary: MuscleBalanceSummary?) {
        self.group = group
        self.weeks = weeks
        self.summary = summary
        _selectedDate = State(
            initialValue: weeks.last(where: { $0.count(for: group) > 0 })?.weekStart ?? weeks.last?.weekStart
        )
    }

    private var selectedWeek: MuscleBalanceWeek? {
        guard let selectedDate else { return nil }
        return weeks.min { abs($0.weekStart.timeIntervalSince(selectedDate)) < abs($1.weekStart.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        GymChartCard(
            title: "\(group.displayName) · 8 weeks",
            evidence: "Estimated completed working sets; every week is shown.",
            takeaway: takeaway,
            titleIdentifier: "muscle-balance-chart-title",
            insight: insight
        ) {
            if let selectedWeek {
                GymChartSelectionAnnotation(
                    title: selectedWeek.weekStart.formatted(.dateTime.month(.abbreviated).day()),
                    value: selectedWeek.count(for: group) == 0
                        ? "No completed working sets"
                        : "\(Formatters.formatFloat(Float(selectedWeek.count(for: group)))) estimated sets"
                )
                .accessibilityIdentifier("muscle-balance-chart-selection")
            }

            Chart(weeks) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Estimated sets", week.count(for: group)),
                    width: .ratio(0.6)
                )
                .foregroundStyle(week.count(for: group) == 0 ? Color.gymRowSurface : Color.gymPrimary)
                .cornerRadius(Radius.small)

                if selectedWeek?.id == week.id {
                    RuleMark(x: .value("Selected week", week.weekStart))
                        .foregroundStyle(Color.gymPrimary.opacity(0.42))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .frame(height: ComponentSize.standardChartHeight)
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.gymBorder)
                    AxisTick().foregroundStyle(Color.gymBorder)
                    AxisValueLabel().font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
            }
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
            .accessibilityLabel("Eight-week estimated \(group.displayName) working-set volume")
            .accessibilityValue(weeks.map {
                "\($0.weekStart.formatted(.dateTime.month(.abbreviated).day())): \(Formatters.formatFloat(Float($0.count(for: group)))) estimated sets"
            }.joined(separator: ", "))
        }
        .id(group)
        .accessibilityIdentifier("muscle-balance-chart")
    }

    private var takeaway: String? {
        guard let summary else { return nil }
        guard let ratio = summary.changeRatio else {
            return "No previous four-week baseline is available for comparison."
        }
        let percentage = Int((abs(ratio) * 100).rounded())
        if percentage < 5 {
            return "Estimated weekly sets were about the same as the previous four weeks."
        }
        return "Estimated weekly sets were \(percentage)% \(ratio > 0 ? "higher" : "lower") than the previous four weeks."
    }

    private var insight: AnalyticsInsight {
        let activeWeeks = weeks.filter { $0.count(for: group) > 0 }.count
        let level = StrengthEvidenceLevel.resolve(comparableSessionCount: activeWeeks)
        return AnalyticsInsight(
            sessionCount: activeWeeks,
            wordingTier: level.title,
            evidenceLevel: level,
            allowsDirectionalClaim: level.allowsDirectionalClaim,
            comparisonConditions: "Completed working sets mapped to primary (1.0) and secondary (0.5) muscle groups across 8 weeks.",
            excludedEvidence: "Warm-up sets, active, planned, or discarded workouts.",
            calculationMethod: "Estimated sets per week averaged across recent 4 weeks vs previous 4 weeks.",
            takeaway: takeaway
        )
    }
}

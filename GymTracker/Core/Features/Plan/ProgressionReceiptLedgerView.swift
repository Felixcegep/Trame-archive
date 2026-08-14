import Charts
import SwiftData
import SwiftUI

#if !GYMTRACKER_EXTENSION

struct ProgressionReceiptLedgerView: View {
    enum Filter: String, CaseIterable, Hashable {
        case all
        case pending
        case resolved

        var title: String {
            switch self {
            case .all: return String(localized: "progression.ledger.filter.all", defaultValue: "All")
            case .pending: return String(localized: "progression.ledger.filter.pending", defaultValue: "Pending")
            case .resolved: return String(localized: "progression.ledger.filter.resolved", defaultValue: "Resolved")
            }
        }
    }

    @Query(sort: \PlanProgressionRecommendationRecord.createdAt, order: .reverse)
    private var records: [PlanProgressionRecommendationRecord]
    @State private var filter: Filter = .all
    @State private var projectionCache: ProgressionReceiptLedgerProjectionCache?

    var body: some View {
        let inputID = projectionInputID
        let entries = projectionCache.flatMap {
            $0.inputID == inputID ? $0.entries : nil
        } ?? ProgressionReceiptLedgerProjection.project(records: records)
        let filteredEntries = filteredEntries(from: entries)
        let decisionSummary = ProgressionReceiptLedgerProjection.decisionSummary(entries: entries)

        List {
            Picker(
                String(localized: "progression.ledger.filter.label", defaultValue: "Show"),
                selection: $filter
            ) {
                ForEach(Filter.allCases, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("progression-ledger-filter")
            .listRowBackground(Color.clear)

            if !entries.isEmpty {
                Section {
                    decisionSummaryChart(decisionSummary)
                } header: {
                    Text(String(localized: "progression.ledger.summary.title", defaultValue: "Recommendation outcomes"))
                }
            }

            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: AppIcon.progression,
                    description: Text(emptyDescription)
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("progression-ledger-empty")
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            ProgressionReceiptLedgerDetailView(entry: entry)
                        } label: {
                            ProgressionReceiptLedgerRow(entry: entry)
                        }
                        .accessibilityIdentifier("progression-ledger-row-\(entry.id.uuidString)")
                    }
                } header: {
                    Text(String(localized: "progression.ledger.section.title", defaultValue: "Recommendation history"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(String(localized: "progression.ledger.title", defaultValue: "Training ledger"))
        .accessibilityIdentifier("progression-ledger-screen")
        .task(id: inputID) {
            projectionCache = .init(inputID: inputID, entries: entries)
        }
    }

    private var projectionInputID: Int {
        var revision = Hasher()
        for record in records {
            revision.combine(record.id)
            revision.combine(record.isResolved)
            revision.combine(record.resolvedAt)
            revision.combine(record.decisionOutcome?.rawValue)
            revision.combine(record.appliedLoad)
        }
        return revision.finalize()
    }

    private func filteredEntries(
        from entries: [ProgressionReceiptLedgerProjection.Entry]
    ) -> [ProgressionReceiptLedgerProjection.Entry] {
        switch filter {
        case .all: return entries
        case .pending: return entries.filter { $0.decision == .pending }
        case .resolved: return entries.filter { $0.isResolved }
        }
    }

    private func decisionSummaryChart(
        _ decisionSummary: [ProgressionReceiptLedgerProjection.DecisionSummary]
    ) -> some View {
        Chart(decisionSummary) { item in
            BarMark(
                x: .value(
                    String(localized: "progression.ledger.summary.axis.count", defaultValue: "Recommendations"),
                    item.count
                ),
                y: .value(
                    String(localized: "progression.ledger.summary.axis.outcome", defaultValue: "Outcome"),
                    ProgressionReceiptLedgerPresentation.decisionLabel(item.decision)
                )
            )
            .foregroundStyle(summaryColor(item.decision))
            .annotation(position: .trailing) {
                Text(item.count, format: .number)
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(minHeight: CGFloat(decisionSummary.count) * (Spacing.xxl + Spacing.xs))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "progression.ledger.summary.accessibility.label", defaultValue: "Recommendation outcome summary")
        )
        .accessibilityValue(summaryAccessibilityValue(decisionSummary))
        .accessibilityIdentifier("progression-ledger-summary-chart")
    }

    private func summaryAccessibilityValue(
        _ decisionSummary: [ProgressionReceiptLedgerProjection.DecisionSummary]
    ) -> String {
        decisionSummary
            .map {
                "\(ProgressionReceiptLedgerPresentation.decisionLabel($0.decision)): \($0.count.formatted())"
            }
            .joined(separator: ", ")
    }

    private func summaryColor(_ decision: ProgressionReceiptLedgerProjection.DecisionState) -> Color {
        switch decision {
        case .accepted: return .gymSuccess
        case .acceptedWithModifiedValue: return .gymPrimary
        case .declined, .outcomeNotRecorded: return .gymSubduedText
        case .pending: return .gymAccent
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: return String(localized: "progression.ledger.empty.title", defaultValue: "No progression receipts")
        case .pending: return String(localized: "progression.ledger.empty.pending.title", defaultValue: "No pending receipts")
        case .resolved: return String(localized: "progression.ledger.empty.resolved.title", defaultValue: "No resolved receipts")
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all: return String(localized: "progression.ledger.empty.description", defaultValue: "Recommendation decisions will appear here as your plan evolves.")
        case .pending: return String(localized: "progression.ledger.empty.pending.description", defaultValue: "There are no recommendations waiting for a decision.")
        case .resolved: return String(localized: "progression.ledger.empty.resolved.description", defaultValue: "Resolved recommendation history will appear here.")
        }
    }
}

private struct ProgressionReceiptLedgerProjectionCache {
    let inputID: Int
    let entries: [ProgressionReceiptLedgerProjection.Entry]
}

private struct ProgressionReceiptLedgerRow: View {
    let entry: ProgressionReceiptLedgerProjection.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(ProgressionReceiptLedgerPresentation.decisionLabel(entry.decision))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(statusColor)
                Spacer(minLength: 0)
                Text(entry.createdAt, style: .date)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Text(ProgressionReceiptLedgerPresentation.proposalSummary(entry.proposal))
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.gymDataEmphasis)
            Text(ProgressionReceiptLedgerPresentation.ruleLabel(version: entry.ruleVersion))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            if let applied = ProgressionReceiptLedgerPresentation.appliedValue(entry) {
                Text(applied)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymSuccess)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var statusColor: Color {
        switch entry.decision {
        case .accepted: return .gymSuccess
        case .acceptedWithModifiedValue: return .gymPrimary
        case .declined, .outcomeNotRecorded: return .gymSubduedText
        case .pending: return .gymAccent
        }
    }

    private var accessibilityText: String {
        let proposal = ProgressionReceiptLedgerPresentation.proposalSummary(entry.proposal)
        return "\(ProgressionReceiptLedgerPresentation.decisionLabel(entry.decision)). \(proposal). \(ProgressionReceiptLedgerPresentation.ruleLabel(version: entry.ruleVersion)). \(entry.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct ProgressionReceiptLedgerDetailView: View {
    let entry: ProgressionReceiptLedgerProjection.Entry

    var body: some View {
        List {
            Section(String(localized: "progression.ledger.detail.proposal", defaultValue: "Proposal")) {
                detailRow(
                    title: String(localized: "progression.ledger.detail.proposedChange", defaultValue: "Proposed change"),
                    value: ProgressionReceiptLedgerPresentation.proposalSummary(entry.proposal)
                )
                detailRow(
                    title: String(localized: "progression.ledger.detail.rule", defaultValue: "Rule"),
                    value: ProgressionReceiptLedgerPresentation.ruleLabel(version: entry.ruleVersion)
                )
            }

            Section(String(localized: "progression.ledger.detail.evidence", defaultValue: "Evidence")) {
                detailRow(
                    title: String(localized: "progression.ledger.detail.action", defaultValue: "Action"),
                    value: ProgressionReceiptLedgerPresentation.evidenceLabel(entry.evidence.actionAvailability, kind: .action)
                )
                detailRow(
                    title: String(localized: "progression.ledger.detail.performance", defaultValue: "Performance"),
                    value: ProgressionReceiptLedgerPresentation.evidenceLabel(entry.evidence.performanceAvailability, kind: .performance)
                )
                if entry.evidence.reasonKey != nil {
                    detailRow(
                        title: String(localized: "progression.ledger.detail.reason", defaultValue: "Reason"),
                        value: String(localized: "progression.ledger.detail.reasonRecorded", defaultValue: "Structured reason recorded")
                    )
                }
            }

            Section(String(localized: "progression.ledger.detail.decision", defaultValue: "Decision")) {
                detailRow(
                    title: String(localized: "progression.ledger.detail.outcome", defaultValue: "Outcome"),
                    value: ProgressionReceiptLedgerPresentation.decisionLabel(entry.decision)
                )
                if let applied = ProgressionReceiptLedgerPresentation.appliedValue(entry) {
                    detailRow(
                        title: String(localized: "progression.ledger.detail.applied", defaultValue: "Applied value"),
                        value: applied
                    )
                }
            }

            Section(String(localized: "progression.ledger.detail.source", defaultValue: "Source")) {
                detailRow(
                    title: String(localized: "progression.ledger.detail.created", defaultValue: "Created"),
                    value: entry.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                if let resolvedAt = entry.resolvedAt {
                    detailRow(
                        title: String(localized: "progression.ledger.detail.resolved", defaultValue: "Resolved"),
                        value: resolvedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                detailRow(
                    title: String(localized: "progression.ledger.detail.identifiers", defaultValue: "Run and workout"),
                    value: ProgressionReceiptLedgerPresentation.sourceLabel(entry)
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(String(localized: "progression.ledger.detail.title", defaultValue: "Receipt"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("progression-ledger-detail-\(entry.id.uuidString)")
    }

    private func detailRow(title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.gymText)
        }
    }
}

#endif

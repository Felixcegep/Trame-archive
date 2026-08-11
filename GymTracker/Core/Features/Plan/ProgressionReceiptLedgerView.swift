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

    var body: some View {
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
    }

    private var filteredEntries: [ProgressionReceiptLedgerProjection.Entry] {
        let entries = ProgressionReceiptLedgerProjection.project(records: records)
        switch filter {
        case .all: return entries
        case .pending: return entries.filter { $0.decision == .pending }
        case .resolved: return entries.filter { $0.isResolved }
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

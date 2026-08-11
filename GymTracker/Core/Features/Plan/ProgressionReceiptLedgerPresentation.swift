import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgressionReceiptLedgerPresentation {
    static func decisionLabel(_ decision: ProgressionReceiptLedgerProjection.DecisionState) -> String {
        switch decision {
        case .pending: return String(localized: "progression.ledger.decision.pending", defaultValue: "Pending")
        case .accepted: return String(localized: "progression.ledger.decision.accepted", defaultValue: "Accepted")
        case .acceptedWithModifiedValue: return String(localized: "progression.ledger.decision.modified", defaultValue: "Accepted with a different value")
        case .declined: return String(localized: "progression.ledger.decision.declined", defaultValue: "Declined")
        case .outcomeNotRecorded: return String(localized: "progression.ledger.decision.notRecorded", defaultValue: "Outcome not recorded")
        }
    }

    static func evidenceLabel(_ availability: ProgressionReceiptLedgerProjection.EvidenceAvailability, kind: EvidenceKind) -> String {
        switch (kind, availability) {
        case (.action, .decoded):
            return String(localized: "progression.ledger.evidence.action.recorded", defaultValue: "Rule action recorded")
        case (.action, .absent):
            return String(localized: "progression.ledger.evidence.action.absent", defaultValue: "Rule action unavailable")
        case (.action, .unreadable):
            return String(localized: "progression.ledger.evidence.action.unreadable", defaultValue: "Rule action could not be read")
        case (.performance, .decoded):
            return String(localized: "progression.ledger.evidence.performance.recorded", defaultValue: "Performance evidence recorded")
        case (.performance, .absent):
            return String(localized: "progression.ledger.evidence.performance.absent", defaultValue: "Performance evidence not recorded")
        case (.performance, .unreadable):
            return String(localized: "progression.ledger.evidence.performance.unreadable", defaultValue: "Performance evidence could not be read")
        }
    }

    static func proposalSummary(_ proposal: ProgressionReceiptLedgerProjection.Proposal) -> String {
        if let load = proposal.load {
            let value = Formatters.formatFloat(Float(load))
            let unit = proposal.loadUnit.map { " \($0.rawValue)" } ?? ""
            return String(format: String(localized: "progression.ledger.proposal.load", defaultValue: "Proposed load: %@%@"), value, unit)
        }

        var changes: [String] = []
        if proposal.repetitionOffset != 0 {
            changes.append(String(format: String(localized: "progression.ledger.proposal.repetitions", defaultValue: "%@ reps"), signed(proposal.repetitionOffset)))
        }
        if proposal.setCountOffset != 0 {
            changes.append(String(format: String(localized: "progression.ledger.proposal.sets", defaultValue: "%@ sets"), signed(proposal.setCountOffset)))
        }
        if proposal.durationOffset != 0 {
            changes.append(String(format: String(localized: "progression.ledger.proposal.seconds", defaultValue: "%@ sec"), signed(Int(proposal.durationOffset))))
        }
        if proposal.distanceOffset != 0 {
            changes.append(String(format: String(localized: "progression.ledger.proposal.distance", defaultValue: "%@ distance"), signed(Formatters.formatFloat(Float(proposal.distanceOffset)))))
        }
        if proposal.restDurationOffset != 0 {
            changes.append(String(format: String(localized: "progression.ledger.proposal.rest", defaultValue: "%@ sec rest"), signed(proposal.restDurationOffset)))
        }
        if proposal.caloriesOffset != 0 {
            changes.append(String(format: String(localized: "progression.ledger.proposal.calories", defaultValue: "%@ calories"), signed(Formatters.formatFloat(Float(proposal.caloriesOffset)))))
        }
        if proposal.isDeloading {
            changes.append(String(localized: "progression.ledger.proposal.deload", defaultValue: "Deload"))
        }
        if changes.isEmpty {
            return String(localized: "progression.ledger.proposal.structural", defaultValue: "Structural prescription change")
        }
        return changes.joined(separator: " · ")
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private static func signed(_ value: String) -> String {
        value.hasPrefix("-") || value.hasPrefix("+") ? value : "+\(value)"
    }

    static func ruleLabel(version: Int?) -> String {
        guard let version else {
            return String(localized: "progression.ledger.rule.unversioned", defaultValue: "Rule version not recorded")
        }
        return String(format: String(localized: "progression.ledger.rule.versioned", defaultValue: "Rule version %lld"), Int64(version))
    }

    static func appliedValue(_ entry: ProgressionReceiptLedgerProjection.Entry) -> String? {
        guard let applied = entry.appliedLoad else { return nil }
        let value = Formatters.formatFloat(Float(applied))
        let unit = entry.proposal.loadUnit.map { " \($0.rawValue)" } ?? ""
        return String(format: String(localized: "progression.ledger.applied", defaultValue: "Applied: %@%@"), value, unit)
    }

    static func sourceLabel(_ entry: ProgressionReceiptLedgerProjection.Entry) -> String {
        _ = entry.planRunID
        _ = entry.workoutID
        return String(
            localized: "progression.ledger.source.linked",
            defaultValue: "Linked plan run · Linked workout"
        )
    }

    enum EvidenceKind {
        case action
        case performance
    }
}

#endif

import Foundation

/// Turns one persisted `PlanProgressionRecommendationRecord` into display
/// strings for `ProgressionReceiptSheet`.
///
/// This type only reports what the program engine already decided. It reads
/// the record's persisted `reason`, decoded `performanceData`, `proposedLoad`,
/// and `ruleVersion` and never re-runs, re-derives, or second-guesses the
/// recommendation — the receipt's whole purpose is to make an already-made
/// decision explainable, not to compute a new one. Modeled on
/// `RecommendationPresentation`, which does the equivalent job for the
/// simpler template (non plan-run) recommendation path.
struct ProgressionReceiptPresentation: WhyExplainable {
    let id: UUID
    let exerciseName: String
    /// Deliberately not displayed. This is `PlanProgressionRecommendationRecord.reason`,
    /// produced by `ProgressionEvaluator.successReason(...)` as hard-coded
    /// English literals and persisted at creation time — it can never be
    /// retroactively localized. Rendering it would put English sentences
    /// inside an otherwise localized receipt. Kept here only as legitimate
    /// persisted provenance for a later slice that gives the engine a
    /// structured, localizable reason; the fully localized `evidenceLines`
    /// below are what actually explains the recommendation to the user today.
    let reason: String
    let reasonKey: String?
    let proposedLoad: Double?
    let appliedLoad: Double?
    let unit: WeightType?
    let ruleVersion: Int?
    let performance: ProgressionPerformance?
    let isResolved: Bool
    let decisionOutcome: ProgressionDecisionOutcome?

    init(
        record: PlanProgressionRecommendationRecord,
        exerciseName: String
    ) {
        self.id = record.id
        self.exerciseName = exerciseName
        self.reason = record.reason
        self.reasonKey = record.reasonKey
        self.proposedLoad = record.proposedLoad
        self.appliedLoad = record.appliedLoad
        self.unit = record.proposedLoadUnit
        self.ruleVersion = record.ruleVersion
        self.performance = record.performance()
        self.isResolved = record.isResolved
        self.decisionOutcome = record.decisionOutcome
    }

    /// Only load-bearing recommendations can be accepted with an overridden
    /// value — `PlanProgressionRecommendationService.accept(_:withLoad:...)`
    /// only ever touches load. Structural recommendations (stage change,
    /// week/wave/block advance, variation change, and similar) have no
    /// meaningful "different value" to offer here.
    var canApplyDifferentValue: Bool { proposedLoad != nil }

    /// Named for the rule that produced it. The record has no human-authored
    /// rule name, only a `ruleID` (opaque) and an optional `ruleVersion`, so
    /// the label is generic and versioned rather than invented (never
    /// fabricates a name like "Double Progression" the record cannot back).
    var ruleLabel: String {
        if let ruleVersion {
            let format = String(
                localized: "progression.receipt.rule.versioned",
                defaultValue: "Progression rule v%lld"
            )
            return String(format: format, Int64(ruleVersion))
        }
        return String(
            localized: "progression.receipt.rule.unversioned",
            defaultValue: "Progression rule"
        )
    }

    var proposedLoadText: String? {
        formattedLoad(proposedLoad)
    }

    var appliedLoadText: String? {
        formattedLoad(appliedLoad)
    }

    private func formattedLoad(_ value: Double?) -> String? {
        guard let value else { return nil }
        let formatted = Formatters.formatFloat(Float(value))
        guard let unit else { return formatted }
        return "\(formatted) \(unit.rawValue)"
    }

    /// What the program proposes, in plain language. Load-bearing
    /// recommendations name the number; structural ones describe the change
    /// generically rather than surfacing an internal identifier (a stage ID
    /// or variation UUID) that means nothing to a lifter.
    var proposedChangeText: String {
        if let proposedLoadText {
            let format = String(
                localized: "progression.receipt.proposedChange.load",
                defaultValue: "Proposed next load: %@"
            )
            return String(format: format, proposedLoadText)
        }
        return String(
            localized: "progression.receipt.proposedChange.structural",
            defaultValue: "The program proposes a change to your prescription."
        )
    }

    /// The evidence behind the decision, one line per data point the
    /// completed occurrence actually recorded. Never invents a line for data
    /// that was not captured.
    var evidenceLines: [String] {
        guard let performance else {
            return [
                String(
                    localized: "progression.receipt.evidence.none",
                    defaultValue: "No evidence was recorded for this recommendation."
                )
            ]
        }

        var lines: [String] = []

        if performance.requiredSets > 0 {
            let format = String(
                localized: "progression.receipt.evidence.sets",
                defaultValue: "Completed %1$lld of %2$lld required sets."
            )
            lines.append(String(format: format, Int64(performance.completedSets), Int64(performance.requiredSets)))
        }

        if performance.requiredRepetitions > 0 {
            let format = String(
                localized: "progression.receipt.evidence.reps",
                defaultValue: "Completed %1$lld of %2$lld required repetitions."
            )
            lines.append(String(format: format, Int64(performance.completedRepetitions), Int64(performance.requiredRepetitions)))
        }

        if let amrap = performance.amrapRepetitions {
            let format = String(
                localized: "progression.receipt.evidence.amrap",
                defaultValue: "The AMRAP set reached %lld repetitions."
            )
            lines.append(String(format: format, Int64(amrap)))
        }

        if let actualRIR = performance.actualRIR {
            if let targetRIR = performance.targetRIR {
                let format = String(
                    localized: "progression.receipt.evidence.rir.withTarget",
                    defaultValue: "Reported RIR was %1$lld against a target of %2$lld."
                )
                lines.append(String(format: format, Int64(actualRIR), Int64(targetRIR)))
            } else {
                let format = String(
                    localized: "progression.receipt.evidence.rir",
                    defaultValue: "Reported RIR was %lld."
                )
                lines.append(String(format: format, Int64(actualRIR)))
            }
        }

        if let actualRPE = performance.actualRPE {
            let format = String(
                localized: "progression.receipt.evidence.rpe",
                defaultValue: "Reported RPE was %@."
            )
            lines.append(String(format: format, Formatters.formatFloat(Float(actualRPE))))
        }

        if let ratio = performance.successfulAttemptRatio {
            let format = String(
                localized: "progression.receipt.evidence.successRatio",
                defaultValue: "%@%% of attempts were successful."
            )
            lines.append(String(format: format, Formatters.formatFloat(Float(ratio * 100))))
        }

        if performance.didFail {
            lines.append(
                String(
                    localized: "progression.receipt.evidence.didNotMeetPrescription",
                    defaultValue: "The prescribed performance was not completed."
                )
            )
        }

        return lines
    }

    /// A localized rule outcome, when the recommendation was created after
    /// receipt evidence was structured. Legacy English provenance is never
    /// rendered, so an old receipt remains localized and simply shows its
    /// recorded measurement evidence instead.
    var reasonText: String? {
        guard let reasonKey else { return nil }
        switch reasonKey {
        case "progression.receipt.reason.triggerSatisfied":
            return String(localized: "progression.receipt.reason.triggerSatisfied", defaultValue: "The rule's condition was met.")
        case "progression.receipt.reason.prescriptionNotCompleted":
            return String(localized: "progression.receipt.reason.prescriptionNotCompleted", defaultValue: "The prescribed performance was not completed.")
        default:
            return nil
        }
    }

    /// A coarse, honest qualifier — never a numeric confidence score — shown
    /// only when the evidence genuinely is thin. Silent otherwise: solid
    /// evidence does not need a badge asserting that it is solid.
    var evidenceQualifier: String? {
        guard let performance else { return nil }
        guard performance.requiredSets <= 1, performance.completedSets <= 1 else { return nil }
        return String(
            localized: "progression.receipt.evidence.qualifier.thin",
            defaultValue: "Based on limited evidence — a single set."
        )
    }

    /// "Keep current load" only makes sense when there is a load to keep;
    /// structural recommendations use a plain, honest "Decline" instead.
    /// Declining is a legitimate, ordinary choice either way — this label
    /// never frames it as failure or noncompliance.
    var declineActionTitle: String {
        proposedLoad != nil
            ? String(localized: "progression.receipt.action.keepCurrent", defaultValue: "Keep current load")
            : String(localized: "progression.receipt.action.decline", defaultValue: "Decline")
    }

    var acceptActionTitle: String {
        if let proposedLoadText {
            let format = String(localized: "progression.receipt.action.apply.load", defaultValue: "Apply %@")
            return String(format: format, proposedLoadText)
        }
        return String(localized: "progression.receipt.action.apply.generic", defaultValue: "Apply this change")
    }

    var applyDifferentActionTitle: String {
        String(localized: "progression.receipt.action.applyDifferent", defaultValue: "Apply a different value")
    }

    /// What applying this changes — and, just as importantly, what it does not.
    ///
    /// Promoted out of the Why sheet and onto the card itself. This is the one
    /// moment where the separation between prescription and performed truth
    /// becomes a decision the lifter is actually making, and it is exactly the
    /// moment they need to be told that the sessions they already did are not
    /// being rewritten underneath them. Buried behind a "Why?" tap, the
    /// guarantee was doing none of that work.
    var planEffectText: String {
        let format = String(
            localized: "progression.receipt.effect.plan",
            defaultValue: "This changes future %@ prescriptions. Your completed workouts stay exactly as you performed them."
        )
        return String(format: format, exerciseName)
    }

    /// What was decided, for a record already resolved. A `nil`
    /// `decisionOutcome` on a resolved row is a legacy row written before
    /// outcomes were recorded — it reads plainly as "resolved without a
    /// recorded outcome" and must never be presented as either an accept or
    /// a decline.
    var resolutionSummary: String? {
        guard isResolved else { return nil }
        switch decisionOutcome {
        case .accepted:
            if let proposedLoadText {
                let format = String(localized: "progression.receipt.resolution.accepted.load", defaultValue: "Applied %@.")
                return String(format: format, proposedLoadText)
            }
            return String(localized: "progression.receipt.resolution.accepted.generic", defaultValue: "Applied as proposed.")
        case .acceptedWithModifiedValue:
            let format = String(
                localized: "progression.receipt.resolution.modified",
                defaultValue: "Applied %1$@ instead of the proposed %2$@."
            )
            return String(format: format, appliedLoadText ?? "", proposedLoadText ?? "")
        case .declined:
            return String(localized: "progression.receipt.resolution.declined", defaultValue: "Kept without applying the change.")
        case nil:
            return String(localized: "progression.receipt.resolution.unknown", defaultValue: "Resolved without a recorded outcome.")
        }
    }

    // MARK: - Why?

    /// The receipt's "Why?" explanation, built entirely from fields already on
    /// this presentation. Nothing here re-runs, recomputes, or second-guesses
    /// the recommendation — it only maps already-persisted evidence onto the
    /// shared section vocabulary. Modeled on
    /// `SubstitutionPresentation.whyModel(for:replacing:scope:policy:)`, the
    /// reference adopter.
    ///
    /// `reason` — `PlanProgressionRecommendationRecord.reason`, hard-coded
    /// English persisted by `ProgressionEvaluator.successReason(...)` — is
    /// deliberately never read here. See its doc comment above.
    var whyModel: WhyExplanationModel {
        let subtitleFormat = String(
            localized: "progression.receipt.why.subtitle",
            defaultValue: "%1$@ · %2$@"
        )
        var builder = WhyExplanationBuilder(
            title: String(localized: "progression.receipt.why.title", defaultValue: "Why?"),
            subtitle: String(format: subtitleFormat, exerciseName, ruleLabel),
            isDecision: true
        )

        builder.add(.whatChanged, body: proposedChangeText)
        // A resolved record is history, not a live proposal anymore — say
        // what was actually decided (including the legacy nil-outcome case,
        // which reads as "resolved without a recorded outcome") rather than
        // leaving only the original proposal to read.
        if let resolutionSummary {
            builder.add(.whatChanged, body: resolutionSummary)
        }

        builder.add(.evidenceUsed, items: ([reasonText].compactMap { $0 } + evidenceLines))

        builder.add(
            .effectOnPlan,
            body: String(
                localized: "progression.receipt.why.effectOnPlan",
                defaultValue: "Applying this writes your plan's progression state for this exercise. It doesn't change any workout you've already completed."
            )
        )

        // A resolved record's decision already happened. Presenting
        // "if you accept" / "if you decline" as live choices would misrepresent
        // history — including the legacy nil-outcome row, which must never be
        // rendered as either an accept or a decline. Omit rather than fabricate.
        if !isResolved {
            builder.add(.ifYouAccept, body: ifYouAcceptText)
            builder.add(.ifYouDecline, body: ifYouDeclineText)
        }

        if let whyConfidenceNote {
            builder.noteMissingEvidence(qualifier: whyConfidenceNote)
        }

        return builder.build()
    }

    /// Consequence of `acceptActionTitle` / `applyDifferentActionTitle`: what
    /// applying the recommendation, in either form, actually does.
    private var ifYouAcceptText: String {
        if let proposedLoadText {
            let format = String(
                localized: "progression.receipt.why.ifYouAccept.load",
                defaultValue: "Applying sets your next prescribed load for this exercise to %@. You can also choose a different value instead."
            )
            return String(format: format, proposedLoadText)
        }
        return String(
            localized: "progression.receipt.why.ifYouAccept.structural",
            defaultValue: "Applying carries out this change in your plan."
        )
    }

    /// Consequence of `declineActionTitle`. Declining is an ordinary,
    /// legitimate choice — this is never worded as failure, noncompliance, or
    /// falling behind.
    private var ifYouDeclineText: String {
        if proposedLoad != nil {
            return String(
                localized: "progression.receipt.why.ifYouDecline.load",
                defaultValue: "Declining keeps your current load. Your plan stays as it is."
            )
        }
        return String(
            localized: "progression.receipt.why.ifYouDecline.structural",
            defaultValue: "Declining keeps your plan as it is now."
        )
    }

    /// The confidence qualifier for the Why sheet. Mirrors `evidenceQualifier`
    /// when evidence is thin. When that's `nil` — evidence is either solid or
    /// entirely absent — this only adds a plain, true statement when there is
    /// one to add (solid performance was in fact recorded); it never invents a
    /// reassuring sentence, and entirely absent evidence renders no confidence
    /// section here (the absence is already stated in `evidenceLines`).
    private var whyConfidenceNote: String? {
        if let evidenceQualifier { return evidenceQualifier }
        guard performance != nil else { return nil }
        return String(
            localized: "progression.receipt.why.confidence.solid",
            defaultValue: "Based on the recorded performance for this exercise."
        )
    }
}

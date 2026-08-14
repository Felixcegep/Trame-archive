import Foundation

/// Mirrors `SportAnalyticsPolicy`'s role (`Core/Features/History/
/// SportAnalyticsPolicy.swift`) for the mobility domain, but is deliberately
/// never merged with it: a mobility occurrence's comparison conditions
/// (method/purpose/assistance/effective support) and its non-negotiable
/// rules (preparation never counts as development volume; no universal
/// composite score) have no meaningful analogue on the workout-set side, and
/// a workout discipline reclassification must never change what a mobility
/// occurrence's history reports or vice versa.
///
/// This does not introduce a second history path: `MobilityHistoryView`
/// keeps reading `MobilitySession`/`MobilityEntry`/`MobilityResult`/
/// `MobilityResultEvidence` exactly as before and now asks a policy at the
/// call sites that decide what counts as development volume or a comparable
/// trend — the same "ask a policy first at the existing call site" shape
/// `SportAnalyticsPolicy`'s own header comment documents.
protocol MobilityAnalyticsPolicy {
    /// Which structured `MobilityMetric`s this entry's performed evidence
    /// can report on. Never a fixed set per tracking type: an entry with
    /// authored per-side `MobilityResultEvidence.metricProfileSnapshot`s
    /// reports their union; an entry with no evidence at all (a routine item
    /// with no authored prescription) falls back to
    /// `MobilityTrackingType.derivedMetricProfile` — the same single source
    /// of truth the session-start and completion paths already use, reused
    /// here rather than re-derived.
    func eligibleMetrics(for entry: MobilityEntry) -> Set<MobilityMetric>

    /// Whether `current` and `previous` are eligible for a numeric trend.
    /// Requires matching method, purpose, assistance, and effective support
    /// (support/assistance actually performed, falling back to what was
    /// prescribed) — a single changed condition means `.notComparable` and
    /// no numeric trend at all, the same "one changed condition blocks the
    /// whole comparison" principle `MobilityAssessmentComparisonService`
    /// already enforces for assessment observations.
    func comparisonEligibility(current: MobilityResult, previous: MobilityResult) -> MobilityComparisonEligibility

    /// `false` for any occurrence whose recorded purpose was `.preparation`
    /// on any side — a warm-up occurrence must never inflate a development
    /// volume figure, regardless of what it performed. `true` when no
    /// purpose was ever recorded (a plain, non-program-authored routine
    /// item), since there is nothing marking it as preparation.
    func contributesToDevelopmentVolume(entry: MobilityEntry) -> Bool
}

/// Why a `current`/`previous` pair is or is not eligible for a numeric
/// trend. Mirrors `MobilityAssessmentComparability`/
/// `MobilityAssessmentConditionDifference`'s shape from the assessment side
/// deliberately — same principle, distinct vocabulary, never merged types.
enum MobilityComparisonEligibility: Equatable, Sendable {
    case comparable
    case notComparable(differingConditions: [MobilityComparisonConditionDifference])

    var isComparable: Bool {
        if case .comparable = self { return true }
        return false
    }
}

enum MobilityComparisonConditionDifference: String, Codable, CaseIterable, Hashable, Sendable {
    case method
    case purpose
    case assistance
    case effectiveSupport
}

/// The one shipped mobility analytics policy. Reads only immutable snapshot
/// evidence resolved by the caller — the exact `[UUID: MobilityResultEvidence]`
/// dictionary that history/session callers build from their already-scoped
/// `MobilityResultEvidence` observation — never a live catalog
/// relationship (`MobilityDefinition`, `MobilityRoutineItem`,
/// `MobilityMovementOccurrenceDefinition`). A later catalog edit must never
/// retroactively change what an already-completed occurrence's history
/// reports, matching `SportAnalyticsPolicyResolver`'s own snapshot-only
/// historical-resolution rule.
nonisolated struct StandardMobilityAnalyticsPolicy: MobilityAnalyticsPolicy {
    let evidenceByResultID: [UUID: MobilityResultEvidence]

    init(evidenceByResultID: [UUID: MobilityResultEvidence]) {
        self.evidenceByResultID = evidenceByResultID
    }

    func eligibleMetrics(for entry: MobilityEntry) -> Set<MobilityMetric> {
        var metrics: Set<MobilityMetric> = []
        for result in entry.results {
            if let profile = evidenceByResultID[result.id]?.metricProfileSnapshot {
                metrics.formUnion(profile.supportedMetrics)
            }
        }
        if metrics.isEmpty == false { return metrics }

        // No authored evidence on any side (a plain routine item with no
        // advanced prescription): fall back to the same derivation the
        // session-start/completion paths use, so this policy never invents
        // a second notion of "what metrics this entry supports."
        let fallbackTargets = MobilityMetricTargets(
            durationSeconds: entry.targetDurationSeconds.map { .exact($0) },
            repetitions: entry.targetRepetitions.map { .exact($0) },
            load: entry.prescribedLoadValue.map { .exact($0) }
        )
        let derived = MobilityTrackingType.derivedMetricProfile(
            trackingType: entry.trackingType,
            hasPhases: entry.isPhaseDriven,
            targets: fallbackTargets,
            authored: nil
        )
        return derived.supportedMetrics
    }

    func comparisonEligibility(current: MobilityResult, previous: MobilityResult) -> MobilityComparisonEligibility {
        guard let currentEvidence = evidenceByResultID[current.id],
              let previousEvidence = evidenceByResultID[previous.id] else {
            // No evidence recorded for one or both sides: never silently
            // declared comparable just because there is nothing to
            // disagree about.
            return .notComparable(differingConditions: MobilityComparisonConditionDifference.allCases)
        }
        // The actual eligibility decision is `MobilityResultEvidence
        // .isComparable(to:)` — already-existing, already-shipped rule
        // reused verbatim, not reimplemented. It already requires matching
        // method, purpose, and *effective* support/assistance (performed
        // value falling back to prescribed), exactly the spec's list.
        guard previousEvidence.isComparable(to: currentEvidence) else {
            return .notComparable(differingConditions: differingConditions(current: currentEvidence, previous: previousEvidence))
        }
        return .comparable
    }

    func contributesToDevelopmentVolume(entry: MobilityEntry) -> Bool {
        let purposes = entry.results.compactMap { evidenceByResultID[$0.id]?.purposeSnapshot }
        guard purposes.isEmpty == false else { return true }
        return purposes.contains(.preparation) == false
    }

    /// Classification only — never consulted to decide eligibility itself
    /// (that stays `isComparable(to:)` above). This exists solely because
    /// `isComparable(to:)` returns a `Bool`, not which condition disagreed,
    /// and `MobilityComparisonEligibility.notComparable` needs to name one.
    /// The arithmetic mirrors `isComparable(to:)`'s own effective-value
    /// resolution so the two can never disagree about *which* pair counts
    /// as a match.
    private func differingConditions(
        current: MobilityResultEvidence,
        previous: MobilityResultEvidence
    ) -> [MobilityComparisonConditionDifference] {
        var differences: [MobilityComparisonConditionDifference] = []
        if current.methodSnapshotRaw != previous.methodSnapshotRaw {
            differences.append(.method)
        }
        if current.purposeSnapshotRaw != previous.purposeSnapshotRaw {
            differences.append(.purpose)
        }
        let previousEffectiveSupport = previous.performedSupportLevelRaw ?? previous.supportLevelSnapshotRaw
        if previousEffectiveSupport != current.supportLevelSnapshotRaw {
            differences.append(.effectiveSupport)
        }
        var previousEffectiveAssistance = previous.assistancePrescriptionSnapshot
        if previous.performedAssistanceLevel != nil {
            previousEffectiveAssistance?.level = previous.performedAssistanceLevel
        }
        if previousEffectiveAssistance != current.assistancePrescriptionSnapshot {
            differences.append(.assistance)
        }
        return differences
    }
}

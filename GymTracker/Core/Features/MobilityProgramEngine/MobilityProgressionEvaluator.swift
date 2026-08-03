import Foundation

#if !GYMTRACKER_EXTENSION

/// Immutable, side-scoped evidence for one occurrence's most recent
/// performed evidence, built by the caller from `MobilityResultEvidence`/
/// `MobilityResult` — the evaluator itself never touches SwiftData. Two
/// occurrences of the same movement on the same side are evaluated
/// independently; nothing here averages left and right.
nonisolated struct MobilityProgressionPerformance: Codable, Hashable {
    /// Every prescribed metric for this side's result reached a terminal
    /// `.completed` status (never `.partial`/`.skipped`/`.stopped`).
    var allRequiredWorkCompleted: Bool = false
    /// This side's performed values met or exceeded every metric
    /// `MobilityResultEvidence.metricTargetsSnapshot` prescribed.
    var sideTargetsCompleted: Bool = false
    /// Consecutive/total sessions (read from `MobilityProgressionState
    /// .consecutiveTargetMetSessionCount`) where `sideTargetsCompleted` was
    /// true, counting this occurrence.
    var targetMetSessionCount: Int = 0
    var movementQuality: MobilityMovementQuality?
    var sensation: MobilitySensation?
    /// Mirrors `MobilityResultEvidence.isProgressionEligible`: `false` for a
    /// stop signal (pain/numbness/tingling). The evaluator refuses to
    /// produce any proposal at all when this is `false` — the central
    /// safety boundary for this whole file.
    var isProgressionEligible: Bool = true
    /// Caller-vetted comparison against assessment history. Always `false`
    /// unless a caller explicitly computed and supplied it — see
    /// `MobilityProgressionTrigger.comparableAssessmentReached`.
    var comparableAssessmentReached: Bool = false
    /// Set only when a human explicitly approved this specific proposal,
    /// e.g. tapping "Approve" on a recommendation-mode card. Never inferred.
    var userApproved: Bool = false
}

/// The cumulative, mobility-scoped analogue of `ProgressionEvaluationState`:
/// signed offsets a proposal adds on top of an occurrence's authored
/// prescription. Offsets are signed so a future reduction action can lower a
/// value below its authored default; only compiling the next session clamps
/// the resulting physical target, never this state.
nonisolated struct MobilityProgressionProposedState: Codable, Hashable {
    var durationOffsetSeconds: Int = 0
    var repetitionOffset: Int = 0
    var cycleOffset: Int = 0
    var loadOffset: Double = 0
    /// Negative moves toward less assistance (progression); `reduceAssistance`
    /// is the only action that ever changes this.
    var assistanceLevelOffset: Int = 0
    /// Negative steps down `MobilitySupportLevel`'s ladder toward
    /// `.unsupported`; `reduceSupport` is the only action that ever changes
    /// this.
    var supportLevelStepOffset: Int = 0
    /// Positive advances, negative regresses. No mobility variation ladder
    /// exists in the current definition graph (unlike the workout engine's
    /// `variationLadder`), so this is recorded as evidence of the decision
    /// but does not currently retarget a compiled occurrence — see
    /// `MobilityProgramRunCoordinator.adjustedProgram(for:)`.
    var variationStepOffset: Int = 0
}

nonisolated struct MobilityProgressionProposal: Hashable, Identifiable {
    let id: UUID
    let ruleID: UUID
    let action: MobilityProgressionAction
    let reason: String
    let reasonKey: String
    let applicationMode: ProgressionApplicationMode
    let proposedState: MobilityProgressionProposedState
    let performance: MobilityProgressionPerformance
}

nonisolated struct MobilityProgressionEvaluationResult: Hashable {
    let proposals: [MobilityProgressionProposal]
}

/// Pure kernel: reads immutable performed evidence (`performance`) and the
/// state a proposal would build on (`baseState`), and returns proposals. It
/// never mutates a `MobilityProgressionState` record or any domain model —
/// the domain interprets and persists a proposal, the kernel only proposes
/// one (spec §5.3).
nonisolated enum MobilityProgressionEvaluator {
    /// Sensations inside a controlled working range. Discomfort, joint
    /// pressure, and cramping are deliberately excluded even though they are
    /// not stop signals: tolerating more discomfort must never itself
    /// satisfy `.sensationWithinTarget`.
    static let sensationsWithinTarget: Set<MobilitySensation> = [
        .mildStretch, .moderateStretch, .strongControlledStretch
    ]

    static func evaluate(
        rules: [MobilityProgressionRuleDefinition],
        performance: MobilityProgressionPerformance,
        baseState: MobilityProgressionProposedState = MobilityProgressionProposedState()
    ) -> MobilityProgressionEvaluationResult {
        // A stop signal must never produce progression evidence, regardless
        // of what else the occurrence otherwise satisfied.
        guard performance.isProgressionEligible else {
            return MobilityProgressionEvaluationResult(proposals: [])
        }

        var proposals: [MobilityProgressionProposal] = []
        for rule in rules where rule.isEnabled {
            guard matches(rule.trigger, performance: performance) else { continue }
            var proposedState = baseState
            apply(rule.action, to: &proposedState)
            proposals.append(
                MobilityProgressionProposal(
                    id: UUID(),
                    ruleID: rule.id,
                    action: rule.action,
                    reason: reason(for: rule.trigger),
                    reasonKey: reasonKey(for: rule.trigger),
                    applicationMode: rule.applicationMode,
                    proposedState: proposedState,
                    performance: performance
                )
            )
        }
        return MobilityProgressionEvaluationResult(proposals: proposals)
    }

    private static func matches(
        _ trigger: MobilityProgressionTrigger,
        performance: MobilityProgressionPerformance
    ) -> Bool {
        switch trigger {
        case .allRequiredWorkCompleted:
            return performance.allRequiredWorkCompleted
        case .targetCompletedForSessions(let sessions):
            return sessions > 0 && performance.targetMetSessionCount >= sessions
        case .qualityAtLeast(let minimum):
            guard let quality = performance.movementQuality else { return false }
            return qualityRank(quality) >= qualityRank(minimum)
        case .sensationWithinTarget:
            guard let sensation = performance.sensation else { return false }
            return sensationsWithinTarget.contains(sensation)
        case .comparableAssessmentReached:
            return performance.comparableAssessmentReached
        case .sideTargetsCompleted:
            return performance.sideTargetsCompleted
        case .userApproved:
            return performance.userApproved
        case .anyOf(let triggers):
            return !triggers.isEmpty && triggers.contains { matches($0, performance: performance) }
        case .allOf(let triggers):
            return !triggers.isEmpty && triggers.allSatisfy { matches($0, performance: performance) }
        }
    }

    /// Ordinal comparison for "at least this controlled." Both
    /// `.compensationObserved` and `.unableToAssess` rank lowest: an
    /// unassessable occurrence must never read as satisfying a quality gate
    /// by default.
    private static func qualityRank(_ quality: MobilityMovementQuality) -> Int {
        switch quality {
        case .compensationObserved, .unableToAssess: 0
        case .mostlyControlled: 1
        case .controlled: 2
        }
    }

    private static func apply(_ action: MobilityProgressionAction, to state: inout MobilityProgressionProposedState) {
        switch action {
        case .addDuration(let seconds): state.durationOffsetSeconds += max(0, seconds)
        case .addRepetitions(let count): state.repetitionOffset += max(0, count)
        case .addCycle: state.cycleOffset += 1
        case .addLoad(let value): state.loadOffset += max(0, value)
        case .reduceAssistance: state.assistanceLevelOffset -= 1
        case .reduceSupport: state.supportLevelStepOffset -= 1
        case .advanceVariation: state.variationStepOffset += 1
        case .regressVariation: state.variationStepOffset -= 1
        case .repeatPrescription, .maintain: break
        }
    }

    private static func reason(for trigger: MobilityProgressionTrigger) -> String {
        switch trigger {
        case .allRequiredWorkCompleted: return "All prescribed work was completed."
        case .targetCompletedForSessions(let sessions): return "The target was met for \(sessions) sessions."
        case .qualityAtLeast: return "Movement quality met the required standard."
        case .sensationWithinTarget: return "Sensation stayed within the controlled working range."
        case .comparableAssessmentReached: return "A comparable assessment measurement was reached."
        case .sideTargetsCompleted: return "This side's targets were met."
        case .userApproved: return "You approved this progression."
        case .anyOf(let triggers): return triggers.map(reason(for:)).joined(separator: " Or ")
        case .allOf(let triggers): return triggers.map(reason(for:)).joined(separator: " And ")
        }
    }

    private static func reasonKey(for trigger: MobilityProgressionTrigger) -> String {
        switch trigger {
        case .allRequiredWorkCompleted: return "mobility.progression.reason.allRequiredWorkCompleted"
        case .targetCompletedForSessions: return "mobility.progression.reason.targetCompletedForSessions"
        case .qualityAtLeast: return "mobility.progression.reason.qualityAtLeast"
        case .sensationWithinTarget: return "mobility.progression.reason.sensationWithinTarget"
        case .comparableAssessmentReached: return "mobility.progression.reason.comparableAssessmentReached"
        case .sideTargetsCompleted: return "mobility.progression.reason.sideTargetsCompleted"
        case .userApproved: return "mobility.progression.reason.userApproved"
        case .anyOf: return "mobility.progression.reason.anyOf"
        case .allOf: return "mobility.progression.reason.allOf"
        }
    }
}

#endif

import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// Reads a completed program session's immutable performed evidence,
/// evaluates the occurrence's authored rules through `MobilityProgressionEvaluator`,
/// and turns any resulting proposals into unresolved
/// `MobilityProgressionRecommendationRecord` receipts. This is the domain
/// side of spec §5.3's split: the evaluator only proposes, this service is
/// what interprets and persists a proposal — and only `accept(_:in:using:)`
/// ever mutates a `MobilityProgressionState`, and only after an explicit
/// user decision.
@MainActor
enum MobilityProgressionRecommendationService {
    private struct GroupKey: Hashable {
        let progressionKey: String
        let side: MobilitySide
    }

    /// Called once per completed program session (see
    /// `MobilityProgramRunCoordinator.reconcileTerminalSessions`).
    @discardableResult
    static func evaluateAfterCompletion(
        progress: MobilityProgramSessionProgress,
        run: MobilityProgramRun,
        session: MobilitySession,
        userApproved: Bool = false,
        using modelContext: ModelContext
    ) -> [MobilityProgressionRecommendationRecord] {
        guard let program = run.programSnapshot,
              let sessionDefinition = program.flattenedSessions.first(where: { $0.sessionKey == progress.sessionKey })
        else { return [] }

        let grouped = groupedEvidence(for: session, using: modelContext)
        let existingUnresolved = (try? modelContext.fetch(FetchDescriptor<MobilityProgressionRecommendationRecord>()))?
            .filter { $0.sessionProgressID == progress.id && $0.isResolved == false } ?? []
        var created: [MobilityProgressionRecommendationRecord] = []

        for occurrence in sessionDefinition.recipe.occurrences {
            guard let progressionKey = occurrence.progressionKey,
                  occurrence.resolvedProgressionRules.isEmpty == false
            else { continue }

            for side in occurrence.side.resultSides {
                guard let entries = grouped[GroupKey(progressionKey: progressionKey, side: side)],
                      entries.isEmpty == false
                else { continue }

                let state = progressionState(for: progressionKey, side: side, in: run)
                let sessionOutcome = evidenceOutcome(for: entries)
                updateConsecutiveCount(state, metThisSession: sessionOutcome.sideTargetsCompleted)

                let performance = MobilityProgressionPerformance(
                    allRequiredWorkCompleted: sessionOutcome.allRequiredWorkCompleted,
                    sideTargetsCompleted: sessionOutcome.sideTargetsCompleted,
                    // Read after the update above, so a session-count
                    // trigger counts this session too.
                    targetMetSessionCount: state.consecutiveTargetMetSessionCount,
                    movementQuality: sessionOutcome.movementQuality,
                    sensation: sessionOutcome.sensation,
                    isProgressionEligible: sessionOutcome.isProgressionEligible,
                    comparableAssessmentReached: comparableAssessmentReached(
                        for: occurrence,
                        side: side,
                        using: modelContext
                    ),
                    userApproved: userApproved
                )

                let evaluation = MobilityProgressionEvaluator.evaluate(
                    rules: occurrence.resolvedProgressionRules,
                    performance: performance,
                    baseState: state.proposedState
                )
                for proposal in evaluation.proposals {
                    guard existingUnresolved.contains(where: { $0.ruleID == proposal.ruleID && $0.sideRaw == side.rawValue }) == false else {
                        continue
                    }
                    guard let record = try? MobilityProgressionRecommendationRecord(
                        runID: run.id,
                        sessionProgressID: progress.id,
                        progressionKey: progressionKey,
                        side: side,
                        proposal: proposal
                    ) else { continue }
                    modelContext.insert(record)
                    created.append(record)
                }
            }
        }
        guard save(using: modelContext) else { return [] }
        return created
    }

    /// Re-evaluates the most recently completed session for this occurrence
    /// with `userApproved: true`, so a rule gated on
    /// `.userApproved` — which can never fire from the automatic
    /// post-completion pass — has a reachable path: a "Request review"
    /// action on the run screen.
    @discardableResult
    static func requestApprovalReview(
        for progress: MobilityProgramSessionProgress,
        in run: MobilityProgramRun,
        using modelContext: ModelContext
    ) -> [MobilityProgressionRecommendationRecord] {
        guard progress.status == .completed,
              let sessionID = progress.mobilitySessionID,
              let session = try? modelContext.fetch(
                FetchDescriptor<MobilitySession>(predicate: #Predicate { $0.id == sessionID })
              ).first
        else { return [] }
        return evaluateAfterCompletion(progress: progress, run: run, session: session, userApproved: true, using: modelContext)
    }

    // MARK: - Resolution

    @discardableResult
    static func accept(
        _ record: MobilityProgressionRecommendationRecord,
        in run: MobilityProgramRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard record.isResolved == false,
              let state = run.progressionStates.first(where: {
                  $0.progressionKey == record.progressionKey && $0.sideRaw == record.sideRaw
              })
        else { return false }
        state.apply(record.proposedState, recommendationID: record.id)
        record.isResolved = true
        record.resolvedAt = .now
        record.decisionOutcome = .accepted
        return save(using: modelContext)
    }

    /// Declining is a legitimate, ordinary choice — mirroring
    /// `PlanProgressionRecommendationRecord`'s own rule, it is never
    /// presented as failure or noncompliance.
    @discardableResult
    static func decline(_ record: MobilityProgressionRecommendationRecord, using modelContext: ModelContext) -> Bool {
        guard record.isResolved == false else { return false }
        record.isResolved = true
        record.resolvedAt = .now
        record.decisionOutcome = .declined
        return save(using: modelContext)
    }

    // MARK: - Evidence gathering

    private struct EvidenceOutcome {
        var allRequiredWorkCompleted: Bool
        var sideTargetsCompleted: Bool
        var movementQuality: MobilityMovementQuality?
        var sensation: MobilitySensation?
        var isProgressionEligible: Bool
    }

    private static func groupedEvidence(
        for session: MobilitySession,
        using modelContext: ModelContext
    ) -> [GroupKey: [(result: MobilityResult, evidence: MobilityResultEvidence)]] {
        let resultsByID = Dictionary(uniqueKeysWithValues: session.entries.flatMap(\.results).map { ($0.id, $0) })
        guard resultsByID.isEmpty == false else { return [:] }
        let allEvidence = (try? modelContext.fetch(FetchDescriptor<MobilityResultEvidence>())) ?? []

        var grouped: [GroupKey: [(MobilityResult, MobilityResultEvidence)]] = [:]
        for evidence in allEvidence {
            guard let progressionKey = evidence.progressionKeySnapshot,
                  let result = resultsByID[evidence.resultID]
            else { continue }
            grouped[GroupKey(progressionKey: progressionKey, side: evidence.side), default: []].append((result, evidence))
        }
        return grouped
    }

    private static func evidenceOutcome(
        for entries: [(result: MobilityResult, evidence: MobilityResultEvidence)]
    ) -> EvidenceOutcome {
        let allCompleted = entries.allSatisfy { $0.result.status == .completed }
        let eligible = entries.allSatisfy { $0.evidence.isProgressionEligible }
        let targetsMet = entries.allSatisfy { targetsMet(result: $0.result, evidence: $0.evidence) }
        return EvidenceOutcome(
            allRequiredWorkCompleted: allCompleted,
            sideTargetsCompleted: allCompleted && targetsMet,
            movementQuality: entries.compactMap { $0.evidence.movementQuality }.last,
            sensation: entries.compactMap { $0.evidence.sensation }.last,
            isProgressionEligible: eligible
        )
    }

    // MARK: - Assessment evidence bridge (spec §9.19)

    /// Whether this occurrence/side has reached a directly comparable
    /// assessment measurement — the caller-vetted signal
    /// `MobilityProgressionTrigger.comparableAssessmentReached` requires.
    ///
    /// This never re-derives the eligibility matrix: it locates the two
    /// candidate `MobilityAssessmentResult` rows and hands them straight to
    /// the existing `MobilityAssessmentComparisonService`/
    /// `MobilityAssessmentHistoryQuery` (`MobilityAssessmentServices.swift`),
    /// the same rules the assessment history screen itself uses to decide
    /// whether two observations are comparable — definition, side, setup,
    /// method, unit, active/passive, and warm/cold must all match, or the
    /// comparison is `.notDirect` and this returns `false` with zero
    /// exceptions. A single differing condition therefore blocks the whole
    /// recommendation; there is no partial/degraded trend to fall back to,
    /// because only this `Bool` ever leaves this function — the numeric
    /// value and delta never reach `MobilityProgressionPerformance` or the
    /// evaluator.
    ///
    /// Also requires the current observation's confidence to be "accepted":
    /// `MobilityMeasurementConfidence.unknown` never supports a
    /// recommendation, matching the spec's "plus confidence must be
    /// accepted" clause on top of the condition-matching matrix.
    ///
    /// Returns `false` (never throws or crashes) whenever the occurrence has
    /// no authored `linkedAssessmentCatalogueKey`, no assessment history
    /// exists yet, or the fetch fails — an occurrence that never opted into
    /// this bridge behaves exactly as it did before this slice.
    @MainActor
    private static func comparableAssessmentReached(
        for occurrence: MobilityMovementOccurrenceDefinition,
        side: MobilitySide,
        using modelContext: ModelContext
    ) -> Bool {
        guard let catalogueKey = occurrence.linkedAssessmentCatalogueKey else { return false }
        guard let history = try? MobilityAssessmentHistoryQuery.results(
            definitionCatalogueKey: catalogueKey,
            side: assessmentSide(for: side),
            using: modelContext
        ), let current = history.first else { return false }
        guard current.confidence != .unknown else { return false }
        let comparison = MobilityAssessmentComparisonService.latestComparison(for: current, among: history)
        return comparison.comparability == .direct
    }

    /// Training `MobilitySide` has no `.combined` case; an assessment
    /// recorded as combined/bilateral is the natural counterpart to a
    /// training side that is not itself lateralized.
    private static func assessmentSide(for side: MobilitySide) -> MobilityAssessmentSide {
        switch side {
        case .left: return .left
        case .right: return .right
        case .none, .bilateral, .alternating: return .combined
        }
    }

    /// "Met" means reached at least the prescribed floor — the top of a
    /// `.range`, or the value itself for `.exact`/`.minimum` — never merely
    /// attempted. `.maximum`/`.open` targets have no floor to fall short of.
    private static func targetsMet(result: MobilityResult, evidence: MobilityResultEvidence) -> Bool {
        guard let targets = evidence.metricTargetsSnapshot else { return true }
        if let target = targets.durationSeconds, let performed = result.performedDurationSeconds, meets(target, performed) == false {
            return false
        }
        if let target = targets.repetitions, let performed = result.performedRepetitions, meets(target, performed) == false {
            return false
        }
        if let target = targets.load, let performed = result.performedLoadValue, meets(target, performed) == false {
            return false
        }
        return true
    }

    private static func meets(_ target: MobilityIntTarget, _ performed: Int) -> Bool {
        switch target {
        case .exact(let value), .minimum(let value): return performed >= value
        case .maximum(let value): return performed <= value
        case .range(_, let maximum): return performed >= maximum
        case .open: return true
        }
    }

    private static func meets(_ target: MobilityDoubleTarget, _ performed: Double) -> Bool {
        switch target {
        case .exact(let value), .minimum(let value): return performed >= value
        case .maximum(let value): return performed <= value
        case .range(_, let maximum): return performed >= maximum
        case .open: return true
        }
    }

    private static func progressionState(
        for progressionKey: String,
        side: MobilitySide,
        in run: MobilityProgramRun
    ) -> MobilityProgressionState {
        if let existing = run.progressionStates.first(where: { $0.progressionKey == progressionKey && $0.side == side }) {
            return existing
        }
        let state = MobilityProgressionState(progressionKey: progressionKey, side: side)
        run.progressionStates.append(state)
        return state
    }

    private static func updateConsecutiveCount(_ state: MobilityProgressionState, metThisSession: Bool) {
        state.consecutiveTargetMetSessionCount = metThisSession ? state.consecutiveTargetMetSessionCount + 1 : 0
        state.updatedAt = .now
    }

    private static func save(using modelContext: ModelContext) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }
}

#endif

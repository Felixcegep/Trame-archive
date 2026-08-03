import Foundation

nonisolated enum MobilityFlowSemantics: String, Sendable {
    case sequential
    case phaseDriven
    case sideAlternating
    case roundBased
    case continuous
}

nonisolated struct MobilityFlowNodeSnapshot: Hashable, Sendable {
    let id: UUID
    let orderIndex: Int
    let phaseIndex: Int
    let cycleIndex: Int
    let side: MobilitySide
    let sideOrder: Int
    let phaseType: PNFPhaseType
    let prescribedDurationSeconds: Int
    let status: MobilityResultStatus
}

nonisolated struct MobilityFlowEntrySnapshot: Hashable, Sendable {
    let id: UUID
    let orderIndex: Int
    let currentCycleIndex: Int
    let currentPhaseIndex: Int
    let restSeconds: Int?
    /// Authored scoped-rest override for this item. When present it takes
    /// priority over the legacy `restSeconds` mapping (outside a round-based
    /// or continuous block, which govern their own rest independently).
    let restPrescription: MobilityRestPrescription?
    let sideStrategy: MobilitySideStrategy?
    /// Stable authored block identity. `nil` means this entry behaves exactly
    /// as an unblocked item always has: sequential, item-scoped rest.
    let blockKey: String?
    let blockKind: MobilityBlockKind?
    let blockTargetRounds: Int?
    let blockRest: MobilityRestPrescription?
    /// Which pre-materialized repetition of a round-based block this entry
    /// represents. Always `0` outside a round-based block.
    let roundIndex: Int
    let resultStatuses: [MobilityResultStatus]
    let phaseNodes: [MobilityFlowNodeSnapshot]
}

nonisolated struct MobilityFlowSnapshot: Hashable, Sendable {
    let currentEntryIndex: Int
    let entries: [MobilityFlowEntrySnapshot]
}

nonisolated struct MobilityFlowTarget: Hashable, Sendable {
    let entryID: UUID
    let phaseResultID: UUID?
    let side: MobilitySide?
    let cycleIndex: Int?
    let phaseIndex: Int?
}

nonisolated struct MobilityUndoTransition: Hashable, Sendable {
    let target: MobilityFlowTarget?
    let successor: MobilityFlowTarget?
    let stale: Bool
}

/// Where a rest prescription or snapshot applies. This is orthogonal to the
/// directive: a scope names the boundary in the movement graph, a directive
/// names the timing policy at that boundary.
nonisolated enum MobilityRestScope: String, Codable, CaseIterable, Hashable, Sendable {
    case betweenHolds
    case betweenSides
    case betweenRepetitions
    case betweenPhases
    case betweenCycles
    case betweenMovements
    case betweenRounds
    case beforeAssessment

    var displayName: String {
        switch self {
        case .betweenHolds: String(localized: "Between holds")
        case .betweenSides: String(localized: "Between sides")
        case .betweenRepetitions: String(localized: "Between repetitions")
        case .betweenPhases: String(localized: "Between phases")
        case .betweenCycles: String(localized: "Between cycles")
        case .betweenMovements: String(localized: "Between movements")
        case .betweenRounds: String(localized: "Between rounds")
        case .beforeAssessment: String(localized: "Before assessment")
        }
    }
}

/// The timing policy at a rest scope. `.none` remains a legitimate directive
/// (no rest prescribed at that boundary), not the absence of a directive.
nonisolated enum MobilityRestDirective: Codable, Hashable, Sendable {
    case none
    case exact(seconds: Int)
    case range(minimum: Int, maximum: Int)
    case userControlled
    case breatheUntilReady

    var isValid: Bool {
        switch self {
        case .none, .userControlled, .breatheUntilReady: true
        case .exact(let seconds): seconds > 0
        case .range(let minimum, let maximum): minimum > 0 && maximum >= minimum
        }
    }
}

/// A resolved or authored rest prescription: always a scope paired with a
/// directive. Authoring stores this on `MobilityRoutineItemEvidence`
/// (optional, decode-absent-safe); execution snapshots the resolved value
/// onto `MobilityResultEvidence` so later prescription edits cannot rewrite
/// history.
nonisolated struct MobilityRestPrescription: Codable, Hashable, Sendable {
    var scope: MobilityRestScope
    var directive: MobilityRestDirective

    var isValid: Bool { directive.isValid }
}

nonisolated struct MobilityTransition: Hashable, Sendable {
    let semantics: MobilityFlowSemantics
    let nextEntryID: UUID?
    let nextPhaseResultID: UUID?
    let nextSide: MobilitySide?
    let nextCycleIndex: Int?
    let nextPhaseIndex: Int?
    let rest: MobilityRestPrescription
    let sessionCompleted: Bool
    let stale: Bool
}

nonisolated struct MobilityFlowContext: Hashable, Sendable {
    let session: MobilityFlowSnapshot
    let completedEntryID: UUID
    let completedPhaseResultID: UUID?
}

/// Pure post-completion selection over immutable performed-evidence snapshots.
/// The caller resolves this transition before mutating SwiftData, then applies
/// exactly the identified node and commits once.
nonisolated enum MobilityFlowResolver {
    private static let noRest = MobilityRestPrescription(scope: .betweenMovements, directive: .none)

    nonisolated static func currentTarget(in session: MobilityFlowSnapshot) -> MobilityFlowTarget? {
        let entries = orderedEntries(session)
        guard let entry = entries.first(where: {
            $0.orderIndex == session.currentEntryIndex
        }) else { return nil }

        guard entry.phaseNodes.isEmpty == false else {
            return MobilityFlowTarget(
                entryID: entry.id,
                phaseResultID: nil,
                side: nil,
                cycleIndex: nil,
                phaseIndex: nil
            )
        }
        let inProgressNodes = entries.flatMap(\.phaseNodes).filter { $0.status == .inProgress }
        guard inProgressNodes.count == 1,
              let node = orderedNodes(entry).first(where: { $0.status == .inProgress })
        else {
            return nil
        }
        return target(entryID: entry.id, node: node)
    }

    nonisolated static func resolve(_ context: MobilityFlowContext) -> MobilityTransition {
        let entries = orderedEntries(context.session)
        guard let completedEntry = entries.first(where: { $0.id == context.completedEntryID }),
              completedEntry.orderIndex == context.session.currentEntryIndex
        else {
            return staleTransition(in: context.session)
        }

        guard let completedPhaseResultID = context.completedPhaseResultID else {
            guard completedEntry.phaseNodes.isEmpty else {
                return staleTransition(in: context.session)
            }
            return transitionAfterEntry(
                completedEntry,
                entries: entries,
                semantics: flowSemantics(for: completedEntry, phaseDriven: false)
            )
        }

        let nodes = orderedNodes(completedEntry)
        guard let completedNodeIndex = nodes.firstIndex(where: { $0.id == completedPhaseResultID }),
              entries.flatMap(\.phaseNodes).filter({ $0.status == .inProgress }).count == 1,
              nodes[completedNodeIndex].status == .inProgress,
              nodes.prefix(completedNodeIndex).allSatisfy({ isTerminal($0.status) }),
              nodes.dropFirst(completedNodeIndex + 1).allSatisfy({ $0.status == .notStarted }),
              nodes[completedNodeIndex].cycleIndex == completedEntry.currentCycleIndex,
              nodes[completedNodeIndex].phaseIndex == completedEntry.currentPhaseIndex,
              currentTarget(in: context.session)?.phaseResultID == completedPhaseResultID
        else {
            return staleTransition(in: context.session)
        }

        let semantics = flowSemantics(for: completedEntry, phaseDriven: true)
        if let nextNode = nodes.dropFirst(completedNodeIndex + 1).first(where: { !isTerminal($0.status) }) {
            return transition(
                semantics: semantics,
                entryID: completedEntry.id,
                node: nextNode,
                rest: phaseRest(for: nextNode),
                sessionCompleted: false,
                stale: false
            )
        }
        return transitionAfterEntry(completedEntry, entries: entries, semantics: semantics)
    }

    /// Selects the latest terminal execution node in durable execution order.
    /// The optional successor is the node that completion started and is the
    /// only later node an Undo transaction may reset. Round repetitions are
    /// pre-materialized as ordered entries and side-alternating entries are
    /// already traversed in their alternating order by `orderedNodes`, so no
    /// semantics-specific branching is needed here: every semantics shares
    /// one durable execution order.
    nonisolated static func resolveUndo(
        in session: MobilityFlowSnapshot
    ) -> MobilityUndoTransition {
        let entries = orderedEntries(session)
        guard entries.isEmpty == false else {
            return MobilityUndoTransition(target: nil, successor: nil, stale: true)
        }

        var terminalTargets: [MobilityFlowTarget] = []
        for entry in entries {
            let nodes = orderedNodes(entry)
            if nodes.isEmpty {
                guard entry.resultStatuses.isEmpty == false else { continue }
                if entry.resultStatuses.allSatisfy(isTerminal) {
                    terminalTargets.append(
                        MobilityFlowTarget(
                            entryID: entry.id,
                            phaseResultID: nil,
                            side: nil,
                            cycleIndex: nil,
                            phaseIndex: nil
                        )
                    )
                }
            } else {
                terminalTargets.append(contentsOf: nodes.filter { isTerminal($0.status) }.map {
                    target(entryID: entry.id, node: $0)
                })
            }
        }
        guard let target = terminalTargets.last else {
            return MobilityUndoTransition(target: nil, successor: nil, stale: false)
        }

        let current = currentTarget(in: session)
        return MobilityUndoTransition(
            target: target,
            successor: current == target ? nil : current,
            stale: current == nil && terminalTargets.count < executionNodeCount(in: entries)
        )
    }

    private nonisolated static func transitionAfterEntry(
        _ completedEntry: MobilityFlowEntrySnapshot,
        entries: [MobilityFlowEntrySnapshot],
        semantics: MobilityFlowSemantics
    ) -> MobilityTransition {
        guard let nextEntry = entries.first(where: { $0.orderIndex > completedEntry.orderIndex }) else {
            return MobilityTransition(
                semantics: semantics,
                nextEntryID: nil,
                nextPhaseResultID: nil,
                nextSide: nil,
                nextCycleIndex: nil,
                nextPhaseIndex: nil,
                rest: noRest,
                sessionCompleted: true,
                stale: false
            )
        }

        let nextNode = orderedNodes(nextEntry).first(where: { !isTerminal($0.status) })
        let rest = restForTransition(from: completedEntry, to: nextEntry, nextNode: nextNode)
        return transition(
            semantics: flowSemantics(for: nextEntry, phaseDriven: nextEntry.phaseNodes.isEmpty == false),
            entryID: nextEntry.id,
            node: nextNode,
            rest: rest,
            sessionCompleted: false,
            stale: false
        )
    }

    /// Resolves the rest that follows completing `completedEntry`, before
    /// beginning `nextEntry`. Block containment governs first: a continuous
    /// block never rests between its own members; a round-based block rests
    /// only when the round advances, using its own scoped rest at
    /// `.betweenRounds`. For any other block kind, the block's scoped rest is
    /// the default between its own members — the same role the legacy
    /// numeric mapping plays for an unblocked item — but an item's own
    /// authored rest prescription always wins over its container's, and an
    /// upcoming explicit rest phase is the last fallback.
    private nonisolated static func restForTransition(
        from completedEntry: MobilityFlowEntrySnapshot,
        to nextEntry: MobilityFlowEntrySnapshot,
        nextNode: MobilityFlowNodeSnapshot?
    ) -> MobilityRestPrescription {
        let sameBlock = completedEntry.blockKey != nil && completedEntry.blockKey == nextEntry.blockKey
        if sameBlock, let kind = completedEntry.blockKind {
            if kind.isContinuous {
                return noRest
            }
            if kind.isRoundBased, nextEntry.roundIndex == completedEntry.roundIndex {
                return noRest
            }
        }
        if let authored = completedEntry.restPrescription {
            return authored
        }
        if sameBlock, let kind = completedEntry.blockKind, kind.isRoundBased {
            return completedEntry.blockRest
                ?? legacyRest(seconds: completedEntry.restSeconds, scope: .betweenRounds)
        }
        if sameBlock, let blockRest = completedEntry.blockRest {
            return blockRest
        }
        let itemRest = max(0, completedEntry.restSeconds ?? 0)
        if itemRest > 0 {
            return MobilityRestPrescription(scope: .betweenMovements, directive: .exact(seconds: itemRest))
        }
        if let nextNode {
            return phaseRest(for: nextNode)
        }
        return noRest
    }

    private nonisolated static func legacyRest(
        seconds: Int?,
        scope: MobilityRestScope
    ) -> MobilityRestPrescription {
        let seconds = max(0, seconds ?? 0)
        return MobilityRestPrescription(
            scope: scope,
            directive: seconds > 0 ? .exact(seconds: seconds) : .none
        )
    }

    private nonisolated static func staleTransition(
        in session: MobilityFlowSnapshot
    ) -> MobilityTransition {
        let current = currentTarget(in: session)
        let currentEntry = current.flatMap { target in
            session.entries.first { $0.id == target.entryID }
        }
        return MobilityTransition(
            semantics: currentEntry.map { flowSemantics(for: $0, phaseDriven: $0.phaseNodes.isEmpty == false) }
                ?? .sequential,
            nextEntryID: current?.entryID,
            nextPhaseResultID: current?.phaseResultID,
            nextSide: current?.side,
            nextCycleIndex: current?.cycleIndex,
            nextPhaseIndex: current?.phaseIndex,
            rest: noRest,
            sessionCompleted: false,
            stale: true
        )
    }

    private nonisolated static func transition(
        semantics: MobilityFlowSemantics,
        entryID: UUID,
        node: MobilityFlowNodeSnapshot?,
        rest: MobilityRestPrescription,
        sessionCompleted: Bool,
        stale: Bool
    ) -> MobilityTransition {
        MobilityTransition(
            semantics: semantics,
            nextEntryID: entryID,
            nextPhaseResultID: node?.id,
            nextSide: node?.side,
            nextCycleIndex: node?.cycleIndex,
            nextPhaseIndex: node?.phaseIndex,
            rest: rest,
            sessionCompleted: sessionCompleted,
            stale: stale
        )
    }

    private nonisolated static func target(
        entryID: UUID,
        node: MobilityFlowNodeSnapshot
    ) -> MobilityFlowTarget {
        MobilityFlowTarget(
            entryID: entryID,
            phaseResultID: node.id,
            side: node.side,
            cycleIndex: node.cycleIndex,
            phaseIndex: node.phaseIndex
        )
    }

    private nonisolated static func phaseRest(
        for node: MobilityFlowNodeSnapshot
    ) -> MobilityRestPrescription {
        node.phaseType == .rest
            ? MobilityRestPrescription(
                scope: .betweenPhases,
                directive: .exact(seconds: max(0, node.prescribedDurationSeconds))
              )
            : MobilityRestPrescription(scope: .betweenPhases, directive: .none)
    }

    /// The reported semantics for a transition landing on or leaving `entry`.
    /// Block containment is authoritative over side/phase driven-ness: a
    /// round-based or continuous block always reports its block semantics,
    /// even for an unphased member item, because the container — not the
    /// item — determines how rest and repetition are sequenced.
    private nonisolated static func flowSemantics(
        for entry: MobilityFlowEntrySnapshot,
        phaseDriven: Bool
    ) -> MobilityFlowSemantics {
        if let kind = entry.blockKind {
            if kind.isRoundBased { return .roundBased }
            if kind.isContinuous { return .continuous }
        }
        if phaseDriven, entry.sideStrategy == .alternateEachRepetition {
            return .sideAlternating
        }
        return phaseDriven ? .phaseDriven : .sequential
    }

    private nonisolated static func isTerminal(_ status: MobilityResultStatus) -> Bool {
        switch status {
        case .notStarted, .inProgress: false
        case .completed, .partial, .skipped, .stopped: true
        }
    }

    private nonisolated static func executionNodeCount(
        in entries: [MobilityFlowEntrySnapshot]
    ) -> Int {
        entries.reduce(into: 0) { count, entry in
            count += entry.phaseNodes.isEmpty ? 1 : entry.phaseNodes.count
        }
    }

    private nonisolated static func orderedEntries(
        _ session: MobilityFlowSnapshot
    ) -> [MobilityFlowEntrySnapshot] {
        session.entries.sorted {
            $0.orderIndex == $1.orderIndex
                ? $0.id.uuidString < $1.id.uuidString
                : $0.orderIndex < $1.orderIndex
        }
    }

    /// Side-major, then cycle, then phase, except for an entry whose side
    /// strategy is `.alternateEachRepetition`: that entry alternates sides
    /// within each cycle before advancing, so the same repetition's left and
    /// right nodes sit next to each other in execution order instead of one
    /// side finishing before the other begins.
    private nonisolated static func orderedNodes(
        _ entry: MobilityFlowEntrySnapshot
    ) -> [MobilityFlowNodeSnapshot] {
        if entry.sideStrategy == .alternateEachRepetition {
            return entry.phaseNodes.sorted {
                if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
                if $0.sideOrder != $1.sideOrder { return $0.sideOrder < $1.sideOrder }
                if $0.phaseIndex != $1.phaseIndex { return $0.phaseIndex < $1.phaseIndex }
                return $0.id.uuidString < $1.id.uuidString
            }
        }
        return entry.phaseNodes.sorted {
            if $0.sideOrder != $1.sideOrder { return $0.sideOrder < $1.sideOrder }
            if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
            if $0.phaseIndex != $1.phaseIndex { return $0.phaseIndex < $1.phaseIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

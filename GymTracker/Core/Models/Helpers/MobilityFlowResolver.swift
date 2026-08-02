import Foundation

nonisolated enum MobilityFlowSemantics: String, Sendable {
    case sequential
    case phaseDriven
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

/// This slice only represents the two rest concepts already persisted by the
/// mobility graph. A rest phase remains an executable phase; item rest remains
/// a between-movement prescription. Broader scoped-rest policy is deliberately
/// deferred until the domain owns those prescriptions.
nonisolated enum MobilityRestDirective: Hashable, Sendable {
    case none
    case explicitPhase(seconds: Int)
    case betweenMovements(seconds: Int)
}

nonisolated struct MobilityTransition: Hashable, Sendable {
    let semantics: MobilityFlowSemantics
    let nextEntryID: UUID?
    let nextPhaseResultID: UUID?
    let nextSide: MobilitySide?
    let nextCycleIndex: Int?
    let nextPhaseIndex: Int?
    let restDirective: MobilityRestDirective
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
            return transitionAfterEntry(completedEntry, entries: entries, semantics: .sequential)
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

        if let nextNode = nodes.dropFirst(completedNodeIndex + 1).first(where: { !isTerminal($0.status) }) {
            return transition(
                semantics: .phaseDriven,
                entryID: completedEntry.id,
                node: nextNode,
                rest: restDirective(for: nextNode),
                sessionCompleted: false,
                stale: false
            )
        }
        return transitionAfterEntry(completedEntry, entries: entries, semantics: .phaseDriven)
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
                restDirective: .none,
                sessionCompleted: true,
                stale: false
            )
        }

        let nextNode = orderedNodes(nextEntry).first(where: { !isTerminal($0.status) })
        let itemRest = max(0, completedEntry.restSeconds ?? 0)
        let rest: MobilityRestDirective
        if itemRest > 0 {
            rest = .betweenMovements(seconds: itemRest)
        } else if let nextNode {
            rest = restDirective(for: nextNode)
        } else {
            rest = .none
        }
        return transition(
            semantics: semantics,
            entryID: nextEntry.id,
            node: nextNode,
            rest: rest,
            sessionCompleted: false,
            stale: false
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
            semantics: currentEntry?.phaseNodes.isEmpty == false ? .phaseDriven : .sequential,
            nextEntryID: current?.entryID,
            nextPhaseResultID: current?.phaseResultID,
            nextSide: current?.side,
            nextCycleIndex: current?.cycleIndex,
            nextPhaseIndex: current?.phaseIndex,
            restDirective: .none,
            sessionCompleted: false,
            stale: true
        )
    }

    private nonisolated static func transition(
        semantics: MobilityFlowSemantics,
        entryID: UUID,
        node: MobilityFlowNodeSnapshot?,
        rest: MobilityRestDirective,
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
            restDirective: rest,
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

    private nonisolated static func restDirective(
        for node: MobilityFlowNodeSnapshot
    ) -> MobilityRestDirective {
        node.phaseType == .rest
            ? .explicitPhase(seconds: max(0, node.prescribedDurationSeconds))
            : .none
    }

    private nonisolated static func isTerminal(_ status: MobilityResultStatus) -> Bool {
        switch status {
        case .notStarted, .inProgress: false
        case .completed, .partial, .skipped, .stopped: true
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

    private nonisolated static func orderedNodes(
        _ entry: MobilityFlowEntrySnapshot
    ) -> [MobilityFlowNodeSnapshot] {
        entry.phaseNodes.sorted {
            if $0.sideOrder != $1.sideOrder { return $0.sideOrder < $1.sideOrder }
            if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
            if $0.phaseIndex != $1.phaseIndex { return $0.phaseIndex < $1.phaseIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

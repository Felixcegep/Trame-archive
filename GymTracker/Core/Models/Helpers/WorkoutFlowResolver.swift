import Foundation

nonisolated enum WorkoutFlowSemantics: String, Sendable {
    case legacyLinear
    case alternatingRound
}

nonisolated struct WorkoutFlowEntryID: Hashable, Sendable {
    let orderIndex: Int
    let orderedOccurrence: Int
}

nonisolated struct WorkoutFlowSetSnapshot: Hashable, Sendable {
    let id: UUID
    let orderIndex: Int
    let isCompleted: Bool
}

nonisolated struct WorkoutFlowEntrySnapshot: Hashable, Sendable {
    let id: WorkoutFlowEntryID
    let orderIndex: Int
    let supersetGroupID: UUID?
    let prescribedRestSeconds: Int?
    let sets: [WorkoutFlowSetSnapshot]
}

nonisolated struct WorkoutFlowSnapshot: Hashable, Sendable {
    let entries: [WorkoutFlowEntrySnapshot]
}

nonisolated struct WorkoutFlowTarget: Hashable, Sendable {
    let entryID: WorkoutFlowEntryID
    let setID: UUID
}

nonisolated enum WorkoutFlowRestDirective: Hashable, Sendable {
    case none
    case rest(seconds: Int)
}

nonisolated enum WorkoutFlowResolution: Hashable, Sendable {
    case transition(WorkoutTransition)
    case stale(WorkoutTransition)
}

nonisolated struct WorkoutTransition: Hashable, Sendable {
    let semantics: WorkoutFlowSemantics
    let nextEntryID: WorkoutFlowEntryID?
    let nextSetID: UUID?
    let restDirective: WorkoutFlowRestDirective
    let workoutCompleted: Bool
}

nonisolated struct WorkoutFlowContext: Hashable, Sendable {
    let workout: WorkoutFlowSnapshot
    let completedEntryID: WorkoutFlowEntryID
    let completedSetID: UUID?
    let defaultRestSeconds: Int
}

/// Pure selection and rest resolution for the workout behavior that predates
/// execution blocks. It reads only immutable values supplied by its caller.
nonisolated enum WorkoutFlowResolver {
    nonisolated static func currentTarget(in workout: WorkoutFlowSnapshot) -> WorkoutFlowTarget? {
        for entry in orderedEntries(workout) {
            guard firstIncompleteSet(in: entry) != nil else { continue }
            guard let groupID = entry.supersetGroupID else {
                return target(for: entry)
            }
            return alternatingTarget(
                in: orderedEntries(workout).filter { $0.supersetGroupID == groupID }
            )
        }
        return nil
    }

    nonisolated static func resolve(_ context: WorkoutFlowContext) -> WorkoutFlowResolution {
        let entries = orderedEntries(context.workout)
        let next = currentTarget(in: context.workout)
        let completedEntry = entries.first { $0.id == context.completedEntryID }
        let semantics: WorkoutFlowSemantics = completedEntry?.supersetGroupID == nil
            ? .legacyLinear
            : .alternatingRound
        let completedSetIsKnown = context.completedSetID.map { setID in
            completedEntry?.sets.contains { $0.id == setID && $0.isCompleted } == true
        } ?? true

        guard let completedEntry, completedSetIsKnown else {
            return .stale(transition(next: next, semantics: semantics, rest: .none))
        }

        let rest = restDirective(
            after: completedEntry,
            entries: entries,
            hasNextSet: next != nil,
            defaultSeconds: context.defaultRestSeconds
        )
        return .transition(transition(next: next, semantics: semantics, rest: rest))
    }

    private nonisolated static func transition(
        next: WorkoutFlowTarget?,
        semantics: WorkoutFlowSemantics,
        rest: WorkoutFlowRestDirective
    ) -> WorkoutTransition {
        WorkoutTransition(
            semantics: semantics,
            nextEntryID: next?.entryID,
            nextSetID: next?.setID,
            restDirective: rest,
            workoutCompleted: next == nil
        )
    }

    private nonisolated static func restDirective(
        after entry: WorkoutFlowEntrySnapshot,
        entries: [WorkoutFlowEntrySnapshot],
        hasNextSet: Bool,
        defaultSeconds: Int
    ) -> WorkoutFlowRestDirective {
        guard hasNextSet else { return .none }
        guard let groupID = entry.supersetGroupID else {
            return .rest(seconds: max(0, entry.prescribedRestSeconds ?? defaultSeconds))
        }

        let members = entries.filter { $0.supersetGroupID == groupID }
        let completedCount = entry.sets.filter(\.isCompleted).count
        let nextRoundCount = members
            .filter { firstIncompleteSet(in: $0) != nil }
            .map { $0.sets.filter(\.isCompleted).count }
            .min()
        if let nextRoundCount, nextRoundCount < completedCount { return .none }

        let groupRest = members.compactMap(\.prescribedRestSeconds).max()
        return .rest(seconds: max(0, groupRest ?? defaultSeconds))
    }

    private nonisolated static func alternatingTarget(
        in members: [WorkoutFlowEntrySnapshot]
    ) -> WorkoutFlowTarget? {
        members.compactMap { entry -> (WorkoutFlowEntrySnapshot, WorkoutFlowSetSnapshot, Int)? in
            guard let set = firstIncompleteSet(in: entry) else { return nil }
            return (entry, set, entry.sets.filter(\.isCompleted).count)
        }
        .sorted {
            $0.2 == $1.2 ? $0.0.orderIndex < $1.0.orderIndex : $0.2 < $1.2
        }
        .first.map { WorkoutFlowTarget(entryID: $0.0.id, setID: $0.1.id) }
    }

    private nonisolated static func target(for entry: WorkoutFlowEntrySnapshot) -> WorkoutFlowTarget? {
        firstIncompleteSet(in: entry).map { WorkoutFlowTarget(entryID: entry.id, setID: $0.id) }
    }

    private nonisolated static func firstIncompleteSet(
        in entry: WorkoutFlowEntrySnapshot
    ) -> WorkoutFlowSetSnapshot? {
        entry.sets.sorted { $0.orderIndex < $1.orderIndex }.first { !$0.isCompleted }
    }

    private nonisolated static func orderedEntries(
        _ workout: WorkoutFlowSnapshot
    ) -> [WorkoutFlowEntrySnapshot] {
        workout.entries.sorted {
            $0.orderIndex == $1.orderIndex
                ? $0.id.orderedOccurrence < $1.id.orderedOccurrence
                : $0.orderIndex < $1.orderIndex
        }
    }
}

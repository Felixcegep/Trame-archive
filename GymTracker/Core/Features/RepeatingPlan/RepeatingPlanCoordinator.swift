import Foundation

nonisolated enum GuidedTrainingSource: Equatable {
    case fixedPlan(runID: UUID, planID: UUID, name: String)
    case repeatingPlan(runID: UUID, planID: UUID, name: String)
}

nonisolated enum RepeatingPlanCoordinatorError: Error, Equatable {
    case archivedPlan
    case invalidDefinition
    case activationConflict([GuidedTrainingSource])
    case runNotActive
    case runNotPaused
    case runHasActiveOccurrence
    case noSlots
    case invalidCursor
    case invalidSlot(Int)
    case unavailableTemplate(Int)
    case noRepeatableSlot
    case occurrenceNotInRun
    case occurrenceNotInProgress
    case occurrenceAlreadyCompleted
    case workoutHasNoCompletedSets
    case noUndoableOccurrence
    case unsafeUndo
}

nonisolated enum RepeatingPlanCompletionResult: Equatable {
    case completed
    case alreadyCompleted
}

struct RepeatingPlanNextWorkout {
    let run: RepeatingPlanRun
    let slot: RepeatingPlanRunSlot
    let template: WorkoutTemplate
    let slotIndex: Int
    let slotCount: Int
    let cycleIndex: Int
}

struct RepeatingPlanOccurrenceStart {
    let occurrence: RepeatingPlanOccurrence
    let slot: RepeatingPlanRunSlot
    let template: WorkoutTemplate
}

enum RepeatingPlanCoordinator {
    static func activate(
        _ plan: RepeatingPlan,
        fixedPlanRuns: [PlanRun] = [],
        repeatingPlanRuns: [RepeatingPlanRun] = [],
        startedAt: Date = .now
    ) throws -> RepeatingPlanRun {
        guard !plan.isArchived else {
            throw RepeatingPlanCoordinatorError.archivedPlan
        }
        let issues = plan.validationIssues
        guard issues.isEmpty else {
            throw RepeatingPlanCoordinatorError.invalidDefinition
        }

        let conflicts = guidedSourceConflicts(
            fixedPlanRuns: fixedPlanRuns,
            repeatingPlanRuns: repeatingPlanRuns
        )
        guard conflicts.isEmpty else {
            throw RepeatingPlanCoordinatorError.activationConflict(conflicts)
        }

        return RepeatingPlanRun(plan: plan, startedAt: startedAt)
    }

    static func guidedSourceConflicts(
        fixedPlanRuns: [PlanRun],
        repeatingPlanRuns: [RepeatingPlanRun]
    ) -> [GuidedTrainingSource] {
        let fixed = fixedPlanRuns.compactMap { run -> GuidedTrainingSource? in
            guard run.status == .active else { return nil }
            return .fixedPlan(
                runID: run.id,
                planID: run.sourcePlanID,
                name: run.sourcePlanName
            )
        }
        let repeating = repeatingPlanRuns.compactMap { run -> GuidedTrainingSource? in
            guard run.status == .active else { return nil }
            return .repeatingPlan(
                runID: run.id,
                planID: run.sourcePlanID,
                name: run.sourcePlanName
            )
        }
        return (fixed + repeating).sorted(by: guidedSourceOrder)
    }

    static func activeRun(in runs: [RepeatingPlanRun]) -> RepeatingPlanRun? {
        runs
            .filter { $0.status == .active }
            .sorted {
                if $0.startedAt != $1.startedAt {
                    return $0.startedAt > $1.startedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            .first
    }

    static func nextWorkout(in run: RepeatingPlanRun) throws -> RepeatingPlanNextWorkout {
        try requireActive(run)
        let slots = run.orderedSlots
        guard !slots.isEmpty else {
            throw RepeatingPlanCoordinatorError.noSlots
        }
        guard slots.indices.contains(run.currentSlotIndex) else {
            throw RepeatingPlanCoordinatorError.invalidCursor
        }
        let slot = slots[run.currentSlotIndex]
        guard let template = slot.workoutTemplate else {
            throw RepeatingPlanCoordinatorError.unavailableTemplate(run.currentSlotIndex)
        }
        return RepeatingPlanNextWorkout(
            run: run,
            slot: slot,
            template: template,
            slotIndex: run.currentSlotIndex,
            slotCount: slots.count,
            cycleIndex: run.completedCycleCount
        )
    }

    static func startExpected(
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrenceStart {
        let next = try nextWorkout(in: run)
        return try start(
            slotIndex: next.slotIndex,
            kind: .expected,
            continuationMode: .continueAfterSelected,
            in: run,
            at: date
        )
    }

    static func start(
        _ command: RepeatingPlanWorkoutStartCommand,
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrenceStart {
        switch command {
        case .expected:
            return try startExpected(in: run, at: date)
        case .repeatLast:
            return try startRepeat(in: run, at: date)
        case .alternate(let slotIndex, let continuationMode):
            return try startAlternate(
                slotIndex: slotIndex,
                continuationMode: continuationMode,
                in: run,
                at: date
            )
        }
    }

    static func startRepeat(
        slotIndex: Int? = nil,
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrenceStart {
        try requireActive(run)
        let resolvedIndex: Int
        if let slotIndex {
            resolvedIndex = slotIndex
        } else if let latest = run.orderedOccurrences.reversed().first(where: {
            $0.status == .completed && isWorkoutOccurrence($0)
        }) {
            resolvedIndex = latest.selectedSlotIndex ?? latest.expectedSlotIndex
        } else {
            throw RepeatingPlanCoordinatorError.noRepeatableSlot
        }
        return try start(
            slotIndex: resolvedIndex,
            kind: .repeatWorkout,
            continuationMode: .keepExpected,
            in: run,
            at: date
        )
    }

    static func startAlternate(
        slotIndex: Int,
        continuationMode: RepeatingPlanContinuationMode,
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrenceStart {
        try start(
            slotIndex: slotIndex,
            kind: .alternate,
            continuationMode: continuationMode,
            in: run,
            at: date
        )
    }

    @discardableResult
    static func complete(
        _ occurrence: RepeatingPlanOccurrence,
        with workout: Workout,
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanCompletionResult {
        guard occurrence.run === run || run.occurrences.contains(where: { $0 === occurrence }) else {
            throw RepeatingPlanCoordinatorError.occurrenceNotInRun
        }
        if occurrence.status == .completed {
            guard occurrence.completedWorkout?.id == workout.id else {
                throw RepeatingPlanCoordinatorError.occurrenceAlreadyCompleted
            }
            return .alreadyCompleted
        }
        guard occurrence.status == .inProgress else {
            throw RepeatingPlanCoordinatorError.occurrenceNotInProgress
        }
        guard workout.completedSetCount > 0 else {
            throw RepeatingPlanCoordinatorError.workoutHasNoCompletedSets
        }

        occurrence.status = .completed
        occurrence.completedAt = date
        occurrence.completedWorkout = workout
        workout.sourceRepeatingPlanID = run.sourcePlanID
        workout.sourceRepeatingPlanRunID = run.id
        workout.sourceRepeatingPlanOccurrenceID = occurrence.id
        workout.sourceRepeatingPlanName = run.sourcePlanName
        run.currentSlotIndex = occurrence.cursorAfter
        run.completedCycleCount = occurrence.cycleAfter
        run.updatedAt = date
        return .completed
    }

    @discardableResult
    static func discard(
        _ occurrence: RepeatingPlanOccurrence,
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrence {
        guard run.occurrences.contains(where: { $0 === occurrence }) else {
            throw RepeatingPlanCoordinatorError.occurrenceNotInRun
        }
        guard occurrence.status == .inProgress else {
            throw RepeatingPlanCoordinatorError.occurrenceNotInProgress
        }
        run.occurrences.removeAll { $0 === occurrence }
        occurrence.run = nil
        run.updatedAt = date
        return occurrence
    }

    @discardableResult
    static func skip(
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrence {
        try requireActive(run)
        try requireNoActiveOccurrence(in: run)
        let slots = run.orderedSlots
        guard !slots.isEmpty else {
            throw RepeatingPlanCoordinatorError.noSlots
        }
        guard slots.indices.contains(run.currentSlotIndex) else {
            throw RepeatingPlanCoordinatorError.invalidCursor
        }
        let after = advancedCursor(
            from: run.currentSlotIndex,
            cycle: run.completedCycleCount,
            slotCount: slots.count
        )
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: run.completedCycleCount,
            expectedSlotIndex: run.currentSlotIndex,
            selectedSlotIndex: nil,
            kind: .skip,
            continuationMode: .continueAfterSelected,
            status: .skipped,
            cursorBefore: run.currentSlotIndex,
            cursorAfter: after.slotIndex,
            cycleBefore: run.completedCycleCount,
            cycleAfter: after.cycle,
            createdAt: date,
            completedAt: date
        )
        append(occurrence, to: run)
        run.currentSlotIndex = after.slotIndex
        run.completedCycleCount = after.cycle
        run.updatedAt = date
        return occurrence
    }

    @discardableResult
    static func undoLastAdvancement(
        in run: RepeatingPlanRun,
        at date: Date = .now
    ) throws -> RepeatingPlanOccurrence {
        guard run.status == .active || run.status == .paused else {
            throw RepeatingPlanCoordinatorError.unsafeUndo
        }
        guard !run.occurrences.contains(where: { $0.status == .inProgress }) else {
            throw RepeatingPlanCoordinatorError.unsafeUndo
        }
        guard let occurrence = run.orderedOccurrences.last else {
            throw RepeatingPlanCoordinatorError.noUndoableOccurrence
        }
        guard occurrence.kind != .restart else {
            throw RepeatingPlanCoordinatorError.unsafeUndo
        }
        guard occurrence.status == .completed || occurrence.status == .skipped else {
            throw RepeatingPlanCoordinatorError.noUndoableOccurrence
        }
        guard run.currentSlotIndex == occurrence.cursorAfter,
              run.completedCycleCount == occurrence.cycleAfter
        else {
            throw RepeatingPlanCoordinatorError.unsafeUndo
        }

        occurrence.status = .undone
        occurrence.undoneAt = date
        run.currentSlotIndex = occurrence.cursorBefore
        run.completedCycleCount = occurrence.cycleBefore
        run.updatedAt = date
        return occurrence
    }

    static func restart(_ run: RepeatingPlanRun, at date: Date = .now) throws {
        guard run.status == .active || run.status == .paused else {
            throw RepeatingPlanCoordinatorError.runNotActive
        }
        try requireNoActiveOccurrence(in: run)
        guard !run.orderedSlots.isEmpty else {
            throw RepeatingPlanCoordinatorError.noSlots
        }
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: run.completedCycleCount,
            expectedSlotIndex: run.currentSlotIndex,
            selectedSlotIndex: nil,
            kind: .restart,
            continuationMode: .continueAfterSelected,
            status: .completed,
            cursorBefore: run.currentSlotIndex,
            cursorAfter: 0,
            cycleBefore: run.completedCycleCount,
            cycleAfter: 0,
            createdAt: date,
            completedAt: date
        )
        append(occurrence, to: run)
        run.currentSlotIndex = 0
        run.completedCycleCount = 0
        run.updatedAt = date
    }

    static func pause(_ run: RepeatingPlanRun, at date: Date = .now) throws {
        try requireActive(run)
        run.status = .paused
        run.updatedAt = date
    }

    static func resume(_ run: RepeatingPlanRun, at date: Date = .now) throws {
        guard run.status == .paused else {
            throw RepeatingPlanCoordinatorError.runNotPaused
        }
        run.status = .active
        run.updatedAt = date
    }

    static func end(_ run: RepeatingPlanRun, at date: Date = .now) throws {
        guard run.status == .active || run.status == .paused else {
            throw RepeatingPlanCoordinatorError.runNotActive
        }
        try requireNoActiveOccurrence(in: run)
        run.status = .ended
        run.endedAt = date
        run.updatedAt = date
    }

    static func archive(_ run: RepeatingPlanRun, at date: Date = .now) throws {
        guard run.status != .archived else { return }
        try requireNoActiveOccurrence(in: run)
        run.status = .archived
        run.endedAt = run.endedAt ?? date
        run.updatedAt = date
    }

    private static func start(
        slotIndex: Int,
        kind: RepeatingPlanOccurrenceKind,
        continuationMode: RepeatingPlanContinuationMode,
        in run: RepeatingPlanRun,
        at date: Date
    ) throws -> RepeatingPlanOccurrenceStart {
        try requireActive(run)
        try requireNoActiveOccurrence(in: run)
        let slots = run.orderedSlots
        guard !slots.isEmpty else {
            throw RepeatingPlanCoordinatorError.noSlots
        }
        guard slots.indices.contains(run.currentSlotIndex) else {
            throw RepeatingPlanCoordinatorError.invalidCursor
        }
        guard slots.indices.contains(slotIndex) else {
            throw RepeatingPlanCoordinatorError.invalidSlot(slotIndex)
        }
        let selected = slots[slotIndex]
        guard let template = selected.workoutTemplate else {
            throw RepeatingPlanCoordinatorError.unavailableTemplate(slotIndex)
        }

        let after: (slotIndex: Int, cycle: Int)
        if continuationMode == .keepExpected {
            after = (run.currentSlotIndex, run.completedCycleCount)
        } else {
            after = advancedCursor(
                from: slotIndex,
                cycle: run.completedCycleCount,
                slotCount: slots.count
            )
        }
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: run.completedCycleCount,
            expectedSlotIndex: run.currentSlotIndex,
            selectedSlotIndex: slotIndex,
            kind: kind,
            continuationMode: continuationMode,
            status: .inProgress,
            cursorBefore: run.currentSlotIndex,
            cursorAfter: after.slotIndex,
            cycleBefore: run.completedCycleCount,
            cycleAfter: after.cycle,
            createdAt: date,
            startedAt: date
        )
        append(occurrence, to: run)
        run.updatedAt = date
        return RepeatingPlanOccurrenceStart(
            occurrence: occurrence,
            slot: selected,
            template: template
        )
    }

    private static func append(_ occurrence: RepeatingPlanOccurrence, to run: RepeatingPlanRun) {
        occurrence.run = run
        if !run.occurrences.contains(where: { $0 === occurrence }) {
            run.occurrences.append(occurrence)
        }
    }

    private static func advancedCursor(
        from slotIndex: Int,
        cycle: Int,
        slotCount: Int
    ) -> (slotIndex: Int, cycle: Int) {
        let nextIndex = slotIndex + 1
        return nextIndex == slotCount ? (0, cycle + 1) : (nextIndex, cycle)
    }

    private static func requireActive(_ run: RepeatingPlanRun) throws {
        guard run.status == .active else {
            throw RepeatingPlanCoordinatorError.runNotActive
        }
    }

    private static func requireNoActiveOccurrence(in run: RepeatingPlanRun) throws {
        guard !run.occurrences.contains(where: { $0.status == .inProgress }) else {
            throw RepeatingPlanCoordinatorError.runHasActiveOccurrence
        }
    }

    private static func isWorkoutOccurrence(_ occurrence: RepeatingPlanOccurrence) -> Bool {
        switch occurrence.kind {
        case .expected, .repeatWorkout, .alternate:
            return true
        case .skip, .restart:
            return false
        }
    }

    nonisolated private static func guidedSourceOrder(
        _ lhs: GuidedTrainingSource,
        _ rhs: GuidedTrainingSource
    ) -> Bool {
        sourceSortKey(lhs) < sourceSortKey(rhs)
    }

    nonisolated private static func sourceSortKey(_ source: GuidedTrainingSource) -> String {
        switch source {
        case .fixedPlan(let runID, _, _):
            return "0|\(runID.uuidString)"
        case .repeatingPlan(let runID, _, _):
            return "1|\(runID.uuidString)"
        }
    }
}

import Foundation

enum RotationProgramPathBuilder {
    static func build(run: RepeatingPlanRun) -> RotationProgramPathProjection {
        let slots = run.orderedSlots
        let cursorIsValid = slots.indices.contains(run.currentSlotIndex)
        // `completedCycleCount` is the zero-based index of the cycle currently
        // being worked on. Preserve a safe presentation value for corrupt legacy
        // rows, but make that corruption explicit in `warnings` below.
        let currentCycleIndex = max(0, run.completedCycleCount)
        let history = run.orderedOccurrences.map { occurrence in
            makeOccurrence(occurrence, slots: slots)
        }
        let warnings = makeWarnings(run: run, slots: slots, history: history)
        let nextWorkout: RotationProgramPathNextWorkout?
        if cursorIsValid {
            let slot = slots[run.currentSlotIndex]
            nextWorkout = RotationProgramPathNextWorkout(
                slotID: slot.id,
                slotIndex: run.currentSlotIndex,
                workoutName: slot.templateNameSnapshot,
                isTemplateAvailable: slot.workoutTemplate != nil
            )
        } else {
            nextWorkout = nil
        }
        let currentCycleSlots = slots.enumerated().map { index, slot in
            RotationProgramPathSlot(
                id: slot.id,
                slotIndex: index,
                workoutName: slot.templateNameSnapshot,
                isTemplateAvailable: slot.workoutTemplate != nil,
                isCursor: cursorIsValid && index == run.currentSlotIndex,
                occurrenceState: latestCurrentCycleState(
                    for: index,
                    cycleIndex: currentCycleIndex,
                    history: history
                )
            )
        }
        let canStartExpected = run.status == .active
            && cursorIsValid
            && nextWorkout?.isTemplateAvailable == true
            && !history.contains(where: { $0.status == .inProgress })

        return RotationProgramPathProjection(
            runID: run.id,
            sourcePlanID: run.sourcePlanID,
            title: run.sourcePlanName,
            runStatus: run.status,
            currentCycleIndex: currentCycleIndex,
            completedCycleCount: max(0, run.completedCycleCount),
            currentSlotIndex: cursorIsValid ? run.currentSlotIndex : nil,
            slotCount: slots.count,
            nextWorkout: nextWorkout,
            currentCycleSlots: currentCycleSlots,
            history: history,
            primaryAction: canStartExpected
                ? .startExpectedRotationWorkout(runID: run.id)
                : nil,
            warnings: warnings
        )
    }

    private static func makeOccurrence(
        _ occurrence: RepeatingPlanOccurrence,
        slots: [RepeatingPlanRunSlot]
    ) -> RotationProgramPathOccurrence {
        RotationProgramPathOccurrence(
            id: occurrence.id,
            cycleIndex: occurrence.cycleIndex,
            expectedSlot: slotReference(for: occurrence.expectedSlotIndex, slots: slots),
            selectedSlot: occurrence.selectedSlotIndex.map { slotReference(for: $0, slots: slots) },
            kind: occurrence.kind,
            continuationMode: occurrence.continuationMode,
            status: occurrence.status,
            cursorBefore: occurrence.cursorBefore,
            cursorAfter: occurrence.cursorAfter,
            cycleBefore: occurrence.cycleBefore,
            cycleAfter: occurrence.cycleAfter,
            createdAt: occurrence.createdAt,
            startedAt: occurrence.startedAt,
            completedAt: occurrence.completedAt,
            undoneAt: occurrence.undoneAt,
            completedWorkoutID: occurrence.completedWorkout?.id
        )
    }

    private static func slotReference(
        for index: Int,
        slots: [RepeatingPlanRunSlot]
    ) -> RotationProgramPathSlotReference {
        guard slots.indices.contains(index) else {
            return RotationProgramPathSlotReference(
                slotIndex: index,
                workoutName: nil,
                isValid: false
            )
        }
        return RotationProgramPathSlotReference(
            slotIndex: index,
            workoutName: slots[index].templateNameSnapshot,
            isValid: true
        )
    }

    private static func latestCurrentCycleState(
        for slotIndex: Int,
        cycleIndex: Int,
        history: [RotationProgramPathOccurrence]
    ) -> RotationProgramPathSlotOccurrenceState? {
        guard let occurrence = history.reversed().first(where: {
            $0.cycleIndex == cycleIndex
                && isTimelineOccurrence($0)
                && ($0.selectedSlot?.slotIndex ?? $0.expectedSlot.slotIndex) == slotIndex
                && $0.status != .undone
        }) else {
            return nil
        }
        switch occurrence.status {
        case .inProgress:
            return .inProgress
        case .completed:
            return .completed
        case .skipped:
            return .skipped
        case .upcoming, .undone:
            return nil
        }
    }

    /// Restart is a cursor-management audit event, not a performed session. It
    /// remains in history for explainability but must never fill a timeline slot
    /// with a false completed-workout state.
    private static func isTimelineOccurrence(
        _ occurrence: RotationProgramPathOccurrence
    ) -> Bool {
        switch occurrence.kind {
        case .expected, .repeatWorkout, .alternate, .skip:
            return true
        case .restart:
            return false
        }
    }

    private static func makeWarnings(
        run: RepeatingPlanRun,
        slots: [RepeatingPlanRunSlot],
        history: [RotationProgramPathOccurrence]
    ) -> [RotationProgramPathWarning] {
        var warnings: [RotationProgramPathWarning] = []
        if run.completedCycleCount < 0 {
            warnings.append(.invalidCompletedCycleCount(run.completedCycleCount))
        }
        if slots.isEmpty {
            warnings.append(.noSlots)
        } else if !slots.indices.contains(run.currentSlotIndex) {
            warnings.append(.invalidCursor(
                currentSlotIndex: run.currentSlotIndex,
                slotCount: slots.count
            ))
        }

        let duplicateOrders = Dictionary(grouping: slots, by: \.orderIndex)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        warnings.append(contentsOf: duplicateOrders.map(RotationProgramPathWarning.duplicateSlotOrder))
        warnings.append(contentsOf: slots.enumerated().compactMap { index, slot in
            guard slot.workoutTemplate == nil else { return nil }
            return .unavailableTemplate(
                slotID: slot.id,
                slotIndex: index,
                workoutName: slot.templateNameSnapshot
            )
        })

        let inProgressCount = history.count { $0.status == .inProgress }
        if inProgressCount > 1 {
            warnings.append(.multipleInProgressOccurrences(count: inProgressCount))
        }
        warnings.append(contentsOf: history.compactMap { occurrence in
            isValid(occurrence, slotCount: slots.count)
                ? nil
                : .invalidOccurrence(occurrenceID: occurrence.id)
        })
        return warnings
    }

    private static func isValid(
        _ occurrence: RotationProgramPathOccurrence,
        slotCount: Int
    ) -> Bool {
        guard occurrence.cycleIndex >= 0,
              occurrence.cycleBefore >= 0,
              occurrence.cycleAfter >= 0,
              occurrence.expectedSlot.isValid,
              occurrence.selectedSlot?.isValid != false
        else {
            return false
        }
        guard slotCount > 0 else { return false }
        guard (0..<slotCount).contains(occurrence.cursorBefore),
              (0..<slotCount).contains(occurrence.cursorAfter),
              occurrence.cycleIndex == occurrence.cycleBefore
        else {
            return false
        }

        switch occurrence.kind {
        case .expected:
            return occurrence.selectedSlot?.slotIndex == occurrence.expectedSlot.slotIndex
                && occurrence.continuationMode == .continueAfterSelected
                && occurrence.cursorBefore == occurrence.expectedSlot.slotIndex
                && advances(
                    occurrence,
                    from: occurrence.expectedSlot.slotIndex,
                    slotCount: slotCount
                )

        case .repeatWorkout:
            return occurrence.selectedSlot != nil
                && occurrence.continuationMode == .keepExpected
                && occurrence.cursorAfter == occurrence.cursorBefore
                && occurrence.cycleAfter == occurrence.cycleBefore

        case .alternate:
            guard let selected = occurrence.selectedSlot?.slotIndex else { return false }
            if occurrence.continuationMode == .keepExpected {
                return occurrence.cursorAfter == occurrence.cursorBefore
                    && occurrence.cycleAfter == occurrence.cycleBefore
            }
            return advances(occurrence, from: selected, slotCount: slotCount)

        case .skip:
            return occurrence.selectedSlot == nil
                && occurrence.continuationMode == .continueAfterSelected
                && occurrence.cursorBefore == occurrence.expectedSlot.slotIndex
                && advances(
                    occurrence,
                    from: occurrence.expectedSlot.slotIndex,
                    slotCount: slotCount
                )

        case .restart:
            return occurrence.selectedSlot == nil
                && occurrence.continuationMode == .continueAfterSelected
                && occurrence.cursorBefore == occurrence.expectedSlot.slotIndex
                && occurrence.cursorAfter == 0
                && occurrence.cycleAfter == 0
        }
    }

    private static func advances(
        _ occurrence: RotationProgramPathOccurrence,
        from slotIndex: Int,
        slotCount: Int
    ) -> Bool {
        let nextSlotIndex = slotIndex + 1
        let expectedCursorAfter = nextSlotIndex == slotCount ? 0 : nextSlotIndex
        let expectedCycleAfter = nextSlotIndex == slotCount
            ? occurrence.cycleBefore + 1
            : occurrence.cycleBefore
        return occurrence.cursorAfter == expectedCursorAfter
            && occurrence.cycleAfter == expectedCycleAfter
    }
}

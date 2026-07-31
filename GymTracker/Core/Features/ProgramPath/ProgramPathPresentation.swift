import SwiftUI

/// Copy and status styling for the Plan Path surfaces.
///
/// Visible vocabulary is deliberately "plan", never "program". The type names
/// and `program-path-*` accessibility identifiers keep their existing spelling
/// so internal symbols and UI test hooks stay stable.
///
/// Everything here is a pure function of projection values, so the wording can
/// be exercised without a live view hierarchy.
enum ProgramPathPresentation {
    static var screenTitle: String { String(localized: "Plan path") }
    static var entryTitle: String { String(localized: "Plan path") }
    static var entryDetail: String {
        String(localized: "See where you are and what comes next.")
    }

    // MARK: - Session state

    /// Visual treatment for one derived session state. Every state carries a
    /// distinct symbol as well as a tint, so status never depends on color.
    struct StateStyle {
        let title: String
        let systemImage: String
        let tint: Color
        let identifier: String
    }

    /// Title, icon, and tint come from `PlanCalendarDisplayState` so the
    /// program path, the plan calendar, and the training calendar describe the
    /// same state identically. Only the accessibility identifier stays local,
    /// because it names the surface a test is asserting against.
    static func style(for state: PlanCalendarDisplayState) -> StateStyle {
        StateStyle(
            title: state.title,
            systemImage: state.icon,
            tint: state.tint,
            identifier: identifier(for: state)
        )
    }

    private static func identifier(for state: PlanCalendarDisplayState) -> String {
        switch state {
        case .inProgress: "program-path-state-in-progress"
        default: "program-path-state-\(state.rawValue)"
        }
    }

    // MARK: - Fixed plan

    static func runStatusTitle(_ status: PlanRunStatus) -> String {
        switch status {
        case .active: String(localized: "Active")
        case .paused: String(localized: "Paused")
        case .testDayAvailable: String(localized: "Test day ready")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Stopped")
        }
    }

    static func phaseTitle(_ phase: PlanPhaseType) -> String {
        switch phase {
        case .accumulation: String(localized: "Accumulation")
        case .hypertrophy: String(localized: "Hypertrophy")
        case .strength: String(localized: "Strength")
        case .peaking: String(localized: "Peaking")
        case .deload: String(localized: "Deload")
        }
    }

    /// "Block 2 of 4 · Build". Returns `nil` when the run has no resolvable
    /// block, so the header can fall back to the week line rather than print a
    /// placeholder position.
    static func blockPosition(_ position: FixedProgramPathProjection.Position) -> String? {
        guard let block = position.block else { return nil }
        guard let index = position.blockIndex, position.totalBlockCount > 0 else {
            return block.name
        }
        return String(localized: "Block \(index + 1) of \(position.totalBlockCount) · \(block.name)")
    }

    /// "Week 2 of 4". Falls back to the run's week when the projection could
    /// not place the cursor inside the derived week list.
    static func weekPosition(_ position: FixedProgramPathProjection.Position) -> String? {
        guard position.totalWeekCount > 0 else { return nil }
        if let weekPosition = position.weekPosition {
            return String(localized: "Week \(weekPosition + 1) of \(position.totalWeekCount)")
        }
        guard let runWeekIndex = position.runWeekIndex else { return nil }
        return String(localized: "Week \(runWeekIndex + 1) of \(position.totalWeekCount)")
    }

    /// "Session 2 of 2" inside the current week.
    static func sessionPosition(_ position: FixedProgramPathProjection.Position) -> String? {
        guard let index = position.sessionIndex, position.sessionCountInWeek > 0 else {
            return nil
        }
        return String(localized: "Session \(index + 1) of \(position.sessionCountInWeek)")
    }

    static func progressSummary(_ progress: FixedProgramPathProjection.Progress) -> String {
        String(localized: "\(progress.completedSessionCount) of \(progress.totalSessionCount) sessions completed")
    }

    static func weekTitle(_ week: FixedProgramPathProjection.Week) -> String {
        if let name = week.sourceWeekName, !name.isEmpty {
            return String(localized: "Week \(week.runWeekIndex + 1) · \(name)")
        }
        return String(localized: "Week \(week.runWeekIndex + 1)")
    }

    static func currentDeloadTitle() -> String {
        String(localized: "You are in a deload week")
    }

    /// Neutral heading for a deload block inside the timeline, where the row is
    /// describing the plan rather than the user's current position.
    static var deloadWeekTitle: String { String(localized: "Deload week") }

    static func upcomingDeloadTitle(_ deload: FixedProgramPathProjection.Deload) -> String {
        String(localized: "Deload starts in week \(deload.firstRunWeekIndex + 1)")
    }

    /// "Volume −50% · Intensity −10%". Returns `nil` when the block records no
    /// reductions, so the callout stays a plain heading instead of claiming an
    /// adjustment the plan never specified.
    static func deloadReductions(_ block: FixedProgramPathProjection.Block) -> String? {
        // The percentage is formatted before interpolation so the extracted key
        // stays "…−%@" rather than mixing a literal percent sign into a format
        // string, which reads as a malformed specifier.
        var parts: [String] = []
        if let volume = block.deloadVolumeReductionPercent {
            let value = volume.formatted() + "%"
            parts.append(String(localized: "Volume −\(value)"))
        }
        if let intensity = block.deloadIntensityReductionPercent {
            let value = intensity.formatted() + "%"
            parts.append(String(localized: "Intensity −\(value)"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func scheduledDateTitle(_ date: Date?) -> String {
        guard let date else { return String(localized: "Unscheduled") }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func rescheduledDetail(_ session: FixedProgramPathProjection.Session) -> String? {
        guard session.isRescheduled, let original = session.originalScheduledDate else {
            return nil
        }
        return String(localized: "Moved from \(original.formatted(date: .abbreviated, time: .omitted))")
    }

    static func warningMessage(_ warning: FixedProgramPathProjection.Warning) -> String {
        switch warning {
        case .sourcePlanUnavailable:
            String(localized: "The plan behind this run is unavailable. Completed sessions still show what you did.")
        case .sourceWeekUnavailable(let sourceWeekIndex):
            String(localized: "Week \(sourceWeekIndex + 1) of the plan is unavailable, so its name and block are missing.")
        case .cursorUnavailable:
            String(localized: "This run has no current session. Open the schedule to pick what to train next.")
        }
    }

    // MARK: - Rotation

    static func rotationStatusTitle(_ status: RepeatingPlanRunStatus) -> String {
        RepeatingPlanPresentation.runStatusTitle(status)
    }

    /// "Cycle 3 · Workout 2 of 3", or a cycle-only line when the cursor is
    /// invalid. The warning list explains the missing position separately.
    static func rotationPosition(_ projection: RotationProgramPathProjection) -> String {
        guard let slotIndex = projection.currentSlotIndex, projection.slotCount > 0 else {
            return String(localized: "Cycle \(projection.currentCycleNumber)")
        }
        return String(localized: "Cycle \(projection.currentCycleNumber) · Workout \(slotIndex + 1) of \(projection.slotCount)")
    }

    static func completedCyclesSummary(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 cycle completed")
            : String(localized: "\(count) cycles completed")
    }

    static func cycleTitle(_ cycleIndex: Int) -> String {
        String(localized: "Cycle \(cycleIndex + 1)")
    }

    static func slotTitle(_ slotIndex: Int) -> String {
        String(localized: "Workout \(slotIndex + 1)")
    }

    static func occurrenceKindTitle(_ kind: RepeatingPlanOccurrenceKind) -> String {
        switch kind {
        case .expected: String(localized: "Planned workout")
        case .repeatWorkout: String(localized: "Repeated workout")
        case .alternate: String(localized: "Switched workout")
        case .skip: String(localized: "Skipped workout")
        case .restart: String(localized: "Rotation restarted")
        }
    }

    static func occurrenceKindIcon(_ kind: RepeatingPlanOccurrenceKind) -> String {
        switch kind {
        case .expected: AppIcon.checkmarkCircle
        case .repeatWorkout: AppIcon.reset
        case .alternate: AppIcon.relationship
        case .skip: AppIcon.skip
        case .restart: AppIcon.restore
        }
    }

    static func occurrenceStatusTitle(_ status: RepeatingPlanOccurrenceStatus) -> String {
        switch status {
        case .upcoming: String(localized: "Upcoming")
        case .inProgress: String(localized: "In progress")
        case .completed: String(localized: "Completed")
        case .skipped: String(localized: "Skipped")
        case .undone: String(localized: "Undone")
        }
    }

    /// What the recorded decision did to the cursor, in the user's terms.
    /// Undone events say so instead, because their cursor movement was reversed.
    static func occurrenceEffect(_ occurrence: RotationProgramPathOccurrence) -> String {
        if occurrence.status == .undone {
            return String(localized: "Undone · the rotation position was restored")
        }
        switch occurrence.continuationMode {
        case .keepExpected:
            return String(localized: "The expected workout stayed next")
        case .continueAfterSelected:
            return occurrence.didAdvance
                ? String(localized: "The rotation moved on")
                : String(localized: "The rotation position did not change")
        }
    }

    /// "Instead of Squat Day" for an alternate, so a switched session still
    /// names the slot it replaced.
    static func occurrenceSubstitution(_ occurrence: RotationProgramPathOccurrence) -> String? {
        guard occurrence.kind == .alternate,
              let selected = occurrence.selectedSlot,
              selected.slotIndex != occurrence.expectedSlot.slotIndex
        else {
            return nil
        }
        guard let expectedName = occurrence.expectedSlot.workoutName else {
            return String(localized: "Instead of workout \(occurrence.expectedSlot.slotIndex + 1)")
        }
        return String(localized: "Instead of \(expectedName)")
    }

    /// The workout an occurrence actually represents. Snapshots are copied at
    /// record time, so a deleted source workout still reads correctly here.
    static func occurrenceWorkoutName(_ occurrence: RotationProgramPathOccurrence) -> String {
        let reference = occurrence.selectedSlot ?? occurrence.expectedSlot
        if let name = reference.workoutName, !name.isEmpty {
            return name
        }
        return String(localized: "Workout \(reference.slotIndex + 1) is unavailable")
    }

    static func occurrenceTimestamp(_ occurrence: RotationProgramPathOccurrence) -> String {
        let date = occurrence.undoneAt
            ?? occurrence.completedAt
            ?? occurrence.startedAt
            ?? occurrence.createdAt
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func warningMessage(_ warning: RotationProgramPathWarning) -> String {
        switch warning {
        case .noSlots:
            String(localized: "This rotation has no workouts, so there is nothing to train next.")
        case .invalidCursor(let currentSlotIndex, let slotCount):
            String(localized: "The saved rotation position (\(currentSlotIndex + 1)) is outside the \(slotCount) workouts in this rotation.")
        case .invalidCompletedCycleCount(let count):
            String(localized: "The saved cycle count (\(count)) is invalid, so cycle numbers may be wrong.")
        case .duplicateSlotOrder(let orderIndex):
            String(localized: "Two workouts share rotation position \(orderIndex + 1).")
        case .unavailableTemplate(_, let slotIndex, let workoutName):
            String(localized: "\(workoutName) at position \(slotIndex + 1) is no longer available.")
        case .multipleInProgressOccurrences(let count):
            String(localized: "\(count) workouts are recorded as in progress. Finish or discard one before continuing.")
        case .invalidOccurrence:
            String(localized: "A recorded rotation event is inconsistent and was left out of the current position.")
        }
    }
}

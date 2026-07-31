import XCTest
@testable import GymTracker

final class ProgramPathPresentationTests: XCTestCase {
    func testSessionStateStylesExposeDistinctStableCopyAndIdentifiers() {
        let expectations: [(PlanCalendarDisplayState, String, String, String)] = [
            (.completed, "Completed", AppIcon.checkmarkCircle, "program-path-state-completed"),
            (.available, "Ready", AppIcon.circleFill, "program-path-state-available"),
            (.inProgress, "In progress", AppIcon.workout, "program-path-state-in-progress"),
            (.missed, "Missed", AppIcon.warning, "program-path-state-missed"),
            (.upcoming, "Upcoming", AppIcon.circleDashed, "program-path-state-upcoming"),
            (.skipped, "Skipped", AppIcon.skip, "program-path-state-skipped")
        ]

        for (state, title, image, identifier) in expectations {
            let style = ProgramPathPresentation.style(for: state)

            XCTAssertEqual(style.title, title, "Unexpected title for \(state)")
            XCTAssertEqual(style.systemImage, image, "Status must retain a non-color cue for \(state)")
            XCTAssertEqual(style.identifier, identifier, "UI automation hook changed for \(state)")
        }
    }

    func testProgramPathUsesCanonicalPlanCalendarStateStyle() {
        for state in PlanCalendarDisplayState.allCases {
            let style = ProgramPathPresentation.style(for: state)

            XCTAssertEqual(style.title, state.title, "Title drifted for \(state)")
            XCTAssertEqual(style.systemImage, state.icon, "Icon drifted for \(state)")
            XCTAssertEqual(style.tint, state.tint, "Tint drifted for \(state)")
        }

        XCTAssertNotEqual(PlanCalendarDisplayState.skipped.icon, PlanCalendarDisplayState.upcoming.icon)
        XCTAssertFalse(PlanCalendarDisplayState.allCases.contains { $0.tint == .secondary })
    }

    func testFixedRunAndPhaseTitlesCoverEveryPersistedCase() {
        XCTAssertEqual(ProgramPathPresentation.runStatusTitle(.active), "Active")
        XCTAssertEqual(ProgramPathPresentation.runStatusTitle(.paused), "Paused")
        XCTAssertEqual(ProgramPathPresentation.runStatusTitle(.testDayAvailable), "Test day ready")
        XCTAssertEqual(ProgramPathPresentation.runStatusTitle(.completed), "Completed")
        XCTAssertEqual(ProgramPathPresentation.runStatusTitle(.archived), "Stopped")

        XCTAssertEqual(ProgramPathPresentation.phaseTitle(.accumulation), "Accumulation")
        XCTAssertEqual(ProgramPathPresentation.phaseTitle(.hypertrophy), "Hypertrophy")
        XCTAssertEqual(ProgramPathPresentation.phaseTitle(.strength), "Strength")
        XCTAssertEqual(ProgramPathPresentation.phaseTitle(.peaking), "Peaking")
        XCTAssertEqual(ProgramPathPresentation.phaseTitle(.deload), "Deload")
    }

    func testFixedPositionCopyUsesOneBasedIndexesAndSafeFallbacks() {
        let block = FixedProgramPathProjection.Block(
            id: UUID(),
            name: "Build",
            phaseType: .strength,
            orderIndex: 1,
            deloadVolumeReductionPercent: nil,
            deloadIntensityReductionPercent: nil
        )
        let resolved = FixedProgramPathProjection.Position(
            block: block,
            blockIndex: 1,
            totalBlockCount: 4,
            runWeekIndex: 1,
            weekPosition: 1,
            totalWeekCount: 8,
            sessionIndex: 1,
            sessionCountInWeek: 3
        )

        XCTAssertEqual(ProgramPathPresentation.blockPosition(resolved), "Block 2 of 4 · Build")
        XCTAssertEqual(ProgramPathPresentation.weekPosition(resolved), "Week 2 of 8")
        XCTAssertEqual(ProgramPathPresentation.sessionPosition(resolved), "Session 2 of 3")

        let fallback = FixedProgramPathProjection.Position(
            block: block,
            blockIndex: nil,
            totalBlockCount: 0,
            runWeekIndex: 3,
            weekPosition: nil,
            totalWeekCount: 6,
            sessionIndex: nil,
            sessionCountInWeek: 0
        )
        XCTAssertEqual(ProgramPathPresentation.blockPosition(fallback), "Build")
        XCTAssertEqual(ProgramPathPresentation.weekPosition(fallback), "Week 4 of 6")
        XCTAssertNil(ProgramPathPresentation.sessionPosition(fallback))

        let unresolved = FixedProgramPathProjection.Position(
            block: nil,
            blockIndex: nil,
            totalBlockCount: 0,
            runWeekIndex: nil,
            weekPosition: nil,
            totalWeekCount: 0,
            sessionIndex: nil,
            sessionCountInWeek: 0
        )
        XCTAssertNil(ProgramPathPresentation.blockPosition(unresolved))
        XCTAssertNil(ProgramPathPresentation.weekPosition(unresolved))
    }

    func testFixedScheduleAndDeloadCopyDoesNotFabricateDetails() {
        let block = FixedProgramPathProjection.Block(
            id: UUID(),
            name: "Deload",
            phaseType: .deload,
            orderIndex: 0,
            deloadVolumeReductionPercent: 50,
            deloadIntensityReductionPercent: 10
        )
        let deload = FixedProgramPathProjection.Deload(
            block: block,
            runWeekIndices: [3],
            firstRunWeekIndex: 3,
            firstScheduledDate: nil
        )

        XCTAssertEqual(ProgramPathPresentation.progressSummary(.init(completedSessionCount: 2, totalSessionCount: 5)), "2 of 5 sessions completed")
        XCTAssertEqual(ProgramPathPresentation.upcomingDeloadTitle(deload), "Deload starts in week 4")
        XCTAssertEqual(ProgramPathPresentation.deloadReductions(block), "Volume −50% · Intensity −10%")
        XCTAssertNil(ProgramPathPresentation.deloadReductions(.init(
            id: UUID(),
            name: "No reductions",
            phaseType: .deload,
            orderIndex: 0,
            deloadVolumeReductionPercent: nil,
            deloadIntensityReductionPercent: nil
        )))
        XCTAssertEqual(ProgramPathPresentation.scheduledDateTitle(nil), "Unscheduled")
    }

    func testRescheduleDetailRequiresBothProvenanceAndCurrentRescheduleState() {
        let original = Date(timeIntervalSinceReferenceDate: 0)
        let session = makeFixedSession(
            originalScheduledDate: original,
            isRescheduled: true
        )
        XCTAssertEqual(
            ProgramPathPresentation.rescheduledDetail(session),
            "Moved from \(original.formatted(date: .abbreviated, time: .omitted))"
        )

        XCTAssertNil(ProgramPathPresentation.rescheduledDetail(makeFixedSession(
            originalScheduledDate: original,
            isRescheduled: false
        )))
        XCTAssertNil(ProgramPathPresentation.rescheduledDetail(makeFixedSession(
            originalScheduledDate: nil,
            isRescheduled: true
        )))
    }

    func testFixedWarningsKeepRecoveryGuidanceSpecificToTheProjectionFailure() {
        XCTAssertEqual(
            ProgramPathPresentation.warningMessage(.sourcePlanUnavailable),
            "The plan behind this run is unavailable. Completed sessions still show what you did."
        )
        XCTAssertEqual(
            ProgramPathPresentation.warningMessage(.sourceWeekUnavailable(sourceWeekIndex: 2)),
            "Week 3 of the plan is unavailable, so its name and block are missing."
        )
        XCTAssertEqual(
            ProgramPathPresentation.warningMessage(.cursorUnavailable),
            "This run has no current session. Open the schedule to pick what to train next."
        )
    }

    func testRotationPositionAndCycleSummaryUseOneBasedPositionAndPluralization() {
        let positioned = makeRotationProjection(currentCycleIndex: 2, completedCycleCount: 2, currentSlotIndex: 1, slotCount: 3)
        XCTAssertEqual(ProgramPathPresentation.rotationPosition(positioned), "Cycle 3 · Workout 2 of 3")
        XCTAssertEqual(ProgramPathPresentation.completedCyclesSummary(1), "1 cycle completed")
        XCTAssertEqual(ProgramPathPresentation.completedCyclesSummary(2), "2 cycles completed")

        let invalidCursor = makeRotationProjection(currentCycleIndex: 2, completedCycleCount: 2, currentSlotIndex: nil, slotCount: 3)
        XCTAssertEqual(ProgramPathPresentation.rotationPosition(invalidCursor), "Cycle 3")
    }

    func testRotationStatusKindAndOccurrenceStatusCopyCoverEveryPersistedCase() {
        XCTAssertEqual(ProgramPathPresentation.rotationStatusTitle(.active), "Active")
        XCTAssertEqual(ProgramPathPresentation.rotationStatusTitle(.paused), "Paused")
        XCTAssertEqual(ProgramPathPresentation.rotationStatusTitle(.ended), "Ended")
        XCTAssertEqual(ProgramPathPresentation.rotationStatusTitle(.archived), "Archived")

        XCTAssertEqual(ProgramPathPresentation.occurrenceKindTitle(.expected), "Planned workout")
        XCTAssertEqual(ProgramPathPresentation.occurrenceKindTitle(.repeatWorkout), "Repeated workout")
        XCTAssertEqual(ProgramPathPresentation.occurrenceKindTitle(.alternate), "Switched workout")
        XCTAssertEqual(ProgramPathPresentation.occurrenceKindTitle(.skip), "Skipped workout")
        XCTAssertEqual(ProgramPathPresentation.occurrenceKindTitle(.restart), "Rotation restarted")

        XCTAssertEqual(ProgramPathPresentation.occurrenceStatusTitle(.upcoming), "Upcoming")
        XCTAssertEqual(ProgramPathPresentation.occurrenceStatusTitle(.inProgress), "In progress")
        XCTAssertEqual(ProgramPathPresentation.occurrenceStatusTitle(.completed), "Completed")
        XCTAssertEqual(ProgramPathPresentation.occurrenceStatusTitle(.skipped), "Skipped")
        XCTAssertEqual(ProgramPathPresentation.occurrenceStatusTitle(.undone), "Undone")
    }

    func testRotationOccurrenceCopyExplainsOutcomesWithoutInventingWorkoutNames() {
        let alternate = makeOccurrence(
            kind: .alternate,
            continuationMode: .keepExpected,
            status: .completed,
            expectedName: "Squat Day",
            selectedSlotIndex: 1,
            selectedName: "Bench Day"
        )
        XCTAssertEqual(ProgramPathPresentation.occurrenceKindTitle(.alternate), "Switched workout")
        XCTAssertEqual(ProgramPathPresentation.occurrenceKindIcon(.alternate), AppIcon.relationship)
        XCTAssertEqual(ProgramPathPresentation.occurrenceSubstitution(alternate), "Instead of Squat Day")
        XCTAssertEqual(ProgramPathPresentation.occurrenceWorkoutName(alternate), "Bench Day")
        XCTAssertEqual(ProgramPathPresentation.occurrenceEffect(alternate), "The expected workout stayed next")

        let undone = makeOccurrence(
            kind: .expected,
            continuationMode: .continueAfterSelected,
            status: .undone,
            expectedName: nil,
            selectedSlotIndex: nil,
            selectedName: nil
        )
        XCTAssertEqual(ProgramPathPresentation.occurrenceWorkoutName(undone), "Workout 1 is unavailable")
        XCTAssertEqual(ProgramPathPresentation.occurrenceEffect(undone), "Undone · the rotation position was restored")

        let unchanged = makeOccurrence(
            kind: .expected,
            continuationMode: .continueAfterSelected,
            status: .completed,
            expectedName: "Squat Day",
            selectedSlotIndex: nil,
            selectedName: nil,
            didAdvance: false
        )
        XCTAssertEqual(ProgramPathPresentation.occurrenceEffect(unchanged), "The rotation position did not change")
    }

    func testRotationWarningCopyCoversEveryValidationState() {
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.noSlots), "This rotation has no workouts, so there is nothing to train next.")
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.invalidCursor(currentSlotIndex: 3, slotCount: 3)), "The saved rotation position (4) is outside the 3 workouts in this rotation.")
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.invalidCompletedCycleCount(-1)), "The saved cycle count (-1) is invalid, so cycle numbers may be wrong.")
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.duplicateSlotOrder(2)), "Two workouts share rotation position 3.")
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.unavailableTemplate(slotID: UUID(), slotIndex: 1, workoutName: "Bench")), "Bench at position 2 is no longer available.")
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.multipleInProgressOccurrences(count: 2)), "2 workouts are recorded as in progress. Finish or discard one before continuing.")
        XCTAssertEqual(ProgramPathPresentation.warningMessage(.invalidOccurrence(occurrenceID: UUID())), "A recorded rotation event is inconsistent and was left out of the current position.")
    }

    private func makeFixedSession(
        originalScheduledDate: Date?,
        isRescheduled: Bool
    ) -> FixedProgramPathProjection.Session {
        FixedProgramPathProjection.Session(
            id: UUID(),
            plannedWorkoutID: UUID(),
            workoutName: "Upper",
            runWeekIndex: 0,
            sourceWeekIndex: 0,
            workoutIndex: 0,
            scheduledDate: nil,
            originalScheduledDate: originalScheduledDate,
            lastRescheduledAt: nil,
            displayState: .available,
            isRescheduled: isRescheduled,
            isCurrent: false,
            completedWorkoutID: nil,
            action: nil
        )
    }

    private func makeRotationProjection(
        currentCycleIndex: Int,
        completedCycleCount: Int,
        currentSlotIndex: Int?,
        slotCount: Int
    ) -> RotationProgramPathProjection {
        RotationProgramPathProjection(
            runID: UUID(),
            sourcePlanID: UUID(),
            title: "Rotation",
            runStatus: .active,
            currentCycleIndex: currentCycleIndex,
            completedCycleCount: completedCycleCount,
            currentSlotIndex: currentSlotIndex,
            slotCount: slotCount,
            nextWorkout: nil,
            currentCycleSlots: [],
            history: [],
            primaryAction: nil,
            warnings: []
        )
    }

    private func makeOccurrence(
        kind: RepeatingPlanOccurrenceKind,
        continuationMode: RepeatingPlanContinuationMode,
        status: RepeatingPlanOccurrenceStatus,
        expectedName: String?,
        selectedSlotIndex: Int?,
        selectedName: String?,
        didAdvance: Bool = true
    ) -> RotationProgramPathOccurrence {
        RotationProgramPathOccurrence(
            id: UUID(),
            cycleIndex: 0,
            expectedSlot: .init(slotIndex: 0, workoutName: expectedName, isValid: expectedName != nil),
            selectedSlot: selectedSlotIndex.map { .init(slotIndex: $0, workoutName: selectedName, isValid: selectedName != nil) },
            kind: kind,
            continuationMode: continuationMode,
            status: status,
            cursorBefore: 0,
            cursorAfter: didAdvance ? 1 : 0,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: .now,
            startedAt: nil,
            completedAt: nil,
            undoneAt: nil,
            completedWorkoutID: nil
        )
    }
}

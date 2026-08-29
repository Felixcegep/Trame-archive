import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutMobilityLinkServiceTests: XCTestCase {
    func testTemplateLinksCanBeAttachedReplacedAndRemovedIndependently() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let preparation = makeRunnableRoutine(named: "Preparation", in: context)
        let replacement = makeRunnableRoutine(named: "Replacement", in: context)
        let cooldown = makeRunnableRoutine(named: "Cooldown", in: context)
        let template = WorkoutTemplate(name: "Full Body", exercises: [])
        context.insert(template)
        try context.save()

        try WorkoutMobilityLinkService.set(
            preparation,
            for: .beforeWorkout,
            on: template,
            using: context
        )
        try WorkoutMobilityLinkService.set(
            cooldown,
            for: .afterWorkout,
            on: template,
            using: context
        )

        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, preparation.id)
        XCTAssertEqual(template.postWorkoutMobilityRoutine?.id, cooldown.id)

        try WorkoutMobilityLinkService.set(
            replacement,
            for: .beforeWorkout,
            on: template,
            using: context
        )

        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, replacement.id)
        XCTAssertEqual(template.postWorkoutMobilityRoutine?.id, cooldown.id)

        try WorkoutMobilityLinkService.set(
            nil,
            for: .afterWorkout,
            on: template,
            using: context
        )

        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, replacement.id)
        XCTAssertNil(template.postWorkoutMobilityRoutine)
    }

    func testSlotMutationRefreshesSnapshotsWithoutRewritingExistingRunSlot() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let original = makeRunnableRoutine(named: "Original", in: context)
        let replacement = makeRunnableRoutine(named: "Replacement", in: context)
        let template = WorkoutTemplate(
            name: "Upper",
            exercises: [],
            preWorkoutMobilityRoutine: original
        )
        let slot = RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)
        let plan = RepeatingPlan(name: "Rotation", slots: [slot])
        let run = RepeatingPlanRun(plan: plan)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()
        let runSlot = try XCTUnwrap(run.orderedSlots.first)

        try WorkoutMobilityLinkService.set(
            replacement,
            for: .beforeWorkout,
            on: slot,
            using: context
        )

        XCTAssertEqual(slot.preWorkoutMobilityRoutine?.id, replacement.id)
        XCTAssertEqual(slot.preWorkoutMobilityRoutineIDSnapshot, replacement.id)
        XCTAssertEqual(slot.preWorkoutMobilityRoutineNameSnapshot, "Replacement")
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutine?.id, original.id)
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutineIDSnapshot, original.id)
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutineNameSnapshot, "Original")

        try WorkoutMobilityLinkService.set(
            nil,
            for: .beforeWorkout,
            on: slot,
            using: context
        )

        XCTAssertNil(slot.preWorkoutMobilityRoutine)
        XCTAssertNil(slot.preWorkoutMobilityRoutineIDSnapshot)
        XCTAssertNil(slot.preWorkoutMobilityRoutineNameSnapshot)
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutine?.id, original.id)
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutineIDSnapshot, original.id)
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutineNameSnapshot, "Original")
    }

    func testArchivedRoutineIsRejectedWithoutChangingExistingLink() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let existing = makeRunnableRoutine(named: "Existing", in: context)
        let archived = makeRunnableRoutine(named: "Archived", isArchived: true, in: context)
        let template = WorkoutTemplate(
            name: "Lower",
            exercises: [],
            preWorkoutMobilityRoutine: existing
        )
        context.insert(template)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutMobilityLinkService.set(
                archived,
                for: .beforeWorkout,
                on: template,
                using: context
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutMobilityLinkMutationError, .archivedRoutine)
        }
        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, existing.id)
    }

    func testEmptyRoutineIsRejectedWithoutChangingExistingLink() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let existing = makeRunnableRoutine(named: "Existing", in: context)
        let empty = MobilityRoutine(name: "Empty")
        let template = WorkoutTemplate(
            name: "Lower",
            exercises: [],
            preWorkoutMobilityRoutine: existing
        )
        context.insert(empty)
        context.insert(template)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutMobilityLinkService.set(
                empty,
                for: .beforeWorkout,
                on: template,
                using: context
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutMobilityLinkMutationError, .emptyRoutine)
        }
        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, existing.id)
    }

    func testSlotLinkProjectionKeepsUnavailableSnapshotReadable() {
        let template = WorkoutTemplate(name: "Lower", exercises: [])
        let routineID = UUID()
        let slot = RepeatingPlanSlot(
            orderIndex: 0,
            workoutTemplate: template,
            preWorkoutMobilityRoutineIDSnapshot: routineID,
            preWorkoutMobilityRoutineNameSnapshot: "Deleted Preparation"
        )

        let link = WorkoutMobilityLinkService.link(
            for: .beforeWorkout,
            on: slot
        )

        XCTAssertNil(link.routine)
        XCTAssertEqual(link.routineIDSnapshot, routineID)
        XCTAssertEqual(link.routineNameSnapshot, "Deleted Preparation")
        XCTAssertTrue(link.isUnavailable)
    }

    func testChangingTemplateLinksDoesNotRewriteCompletedMobilityTruth() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(name: "Hip opener")
        let completedRoutine = MobilityRoutine(name: "Original Preparation")
        completedRoutine.items = [
            MobilityRoutineItem(
                definition: definition,
                orderIndex: 0,
                targetDurationSeconds: 30,
                side: .left
            )
        ]
        let replacement = makeRunnableRoutine(named: "Replacement Preparation", in: context)
        let template = WorkoutTemplate(
            name: "Lower",
            exercises: [],
            preWorkoutMobilityRoutine: completedRoutine
        )
        context.insert(definition)
        context.insert(completedRoutine)
        context.insert(template)
        try context.save()

        let workoutID = UUID()
        let session = try XCTUnwrap(
            MobilitySessionService.start(
                routine: completedRoutine,
                context: .warmup,
                workoutID: workoutID,
                using: context
            )
        )
        XCTAssertTrue(
            MobilitySessionService.completeCurrent(
                in: session,
                performedDurationSeconds: 41,
                perceivedIntensity: 4,
                discomfortNote: "Left side",
                using: context
            )
        )
        let before = try snapshot(of: session)

        try WorkoutMobilityLinkService.set(
            replacement,
            for: .beforeWorkout,
            on: template,
            using: context
        )
        try WorkoutMobilityLinkService.set(
            nil,
            for: .beforeWorkout,
            on: template,
            using: context
        )

        XCTAssertEqual(try snapshot(of: session), before)
    }

    private func snapshot(of session: MobilitySession) throws -> CompletedSessionSnapshot {
        let entry = try XCTUnwrap(session.orderedEntries.first)
        let result = try XCTUnwrap(entry.orderedResults.first)
        return CompletedSessionSnapshot(
            id: session.id,
            status: session.status,
            name: session.nameSnapshot,
            sourceRoutineID: session.sourceRoutineID,
            sourceRoutineName: session.sourceRoutineName,
            workoutID: session.workoutID,
            context: session.context,
            entryID: entry.id,
            definitionID: entry.definitionIDSnapshot,
            definitionName: entry.definitionNameSnapshot,
            targetDurationSeconds: entry.targetDurationSeconds,
            resultID: result.id,
            resultStatus: result.status,
            prescribedDurationSeconds: result.prescribedDurationSeconds,
            performedDurationSeconds: result.performedDurationSeconds,
            perceivedIntensity: result.perceivedIntensity,
            discomfortNote: result.discomfortNote
        )
    }

    private func makeRunnableRoutine(
        named name: String,
        isArchived: Bool = false,
        in context: ModelContext
    ) -> MobilityRoutine {
        let definition = MobilityDefinition(name: "\(name) movement")
        let routine = MobilityRoutine(name: name, isArchived: isArchived)
        routine.items = [
            MobilityRoutineItem(
                definition: definition,
                orderIndex: 0,
                targetDurationSeconds: 30,
                side: .left
            )
        ]
        context.insert(definition)
        context.insert(routine)
        return routine
    }
}

private struct CompletedSessionSnapshot: Equatable {
    let id: UUID
    let status: MobilitySessionStatus
    let name: String
    let sourceRoutineID: UUID?
    let sourceRoutineName: String?
    let workoutID: UUID?
    let context: MobilitySessionContext
    let entryID: UUID
    let definitionID: UUID
    let definitionName: String
    let targetDurationSeconds: Int?
    let resultID: UUID
    let resultStatus: MobilityResultStatus
    let prescribedDurationSeconds: Int?
    let performedDurationSeconds: Int?
    let perceivedIntensity: Int?
    let discomfortNote: String?
}

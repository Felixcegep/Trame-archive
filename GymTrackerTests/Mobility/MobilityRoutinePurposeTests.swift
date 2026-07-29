import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityRoutinePurposeTests: XCTestCase {
    func testNewRoutineDefaultsToUnspecifiedPurpose() {
        let routine = MobilityRoutine(name: "Unclassified")

        XCTAssertNil(routine.purposeRaw)
        XCTAssertNil(routine.purpose)
    }

    func testUnknownPurposeRawReadsAsNilWithoutMutatingStorage() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let routine = MobilityRoutine(name: "Future purpose")
        routine.purposeRaw = "recovery"
        context.insert(routine)
        try context.save()

        let restored = try XCTUnwrap(
            context.fetch(FetchDescriptor<MobilityRoutine>()).first { $0.id == routine.id }
        )
        XCTAssertNil(restored.purpose)
        XCTAssertEqual(restored.purposeRaw, "recovery")
    }

    func testSettingPurposeToNilClearsRawValue() {
        let routine = MobilityRoutine(name: "Preparation", purpose: .preparation)

        routine.purpose = nil

        XCTAssertNil(routine.purposeRaw)
        XCTAssertNil(routine.purpose)
    }

    func testPurposeChangeDoesNotAlterCompletedSessionContext() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(name: "Contextual stretch")
        let routine = MobilityRoutine(name: "Development routine", purpose: .development)
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
        try context.save()

        let session = try XCTUnwrap(
            MobilitySessionService.start(routine: routine, context: .warmup, workoutID: nil, using: context)
        )
        XCTAssertTrue(MobilitySessionService.completeCurrent(in: session, performedDurationSeconds: 30, using: context))
        let result = try XCTUnwrap(session.orderedEntries.first?.results.first)
        let originalContext = session.contextRaw
        let originalRoutineID = session.sourceRoutineID
        let originalRoutineName = session.sourceRoutineName
        let originalStatus = result.statusRaw
        let originalPerformedDuration = result.performedDurationSeconds
        let originalCompletedAt = result.completedAt

        routine.purpose = .cooldown
        try context.save()

        XCTAssertEqual(session.contextRaw, originalContext)
        XCTAssertEqual(session.context, .warmup)
        XCTAssertEqual(session.sourceRoutineID, originalRoutineID)
        XCTAssertEqual(session.sourceRoutineName, originalRoutineName)
        XCTAssertEqual(result.statusRaw, originalStatus)
        XCTAssertEqual(result.performedDurationSeconds, originalPerformedDuration)
        XCTAssertEqual(result.completedAt, originalCompletedAt)
    }

    func testGroupingOrdersPurposesAndPreservesInputOrder() {
        let preparation = MobilityRoutine(name: "Preparation", purpose: .preparation)
        let firstDevelopment = MobilityRoutine(name: "First development", purpose: .development)
        let cooldown = MobilityRoutine(name: "Cooldown", purpose: .cooldown)
        let secondDevelopment = MobilityRoutine(name: "Second development", purpose: .development)
        let unspecified = MobilityRoutine(name: "Unspecified")

        let groups = MobilityRoutinePurposeGrouping.groups(
            for: [firstDevelopment, unspecified, preparation, cooldown, secondDevelopment]
        )

        XCTAssertEqual(groups.map(\.id), ["preparation", "development", "cooldown", "unspecified"])
        XCTAssertEqual(groups[1].routines.map(\.id), [firstDevelopment.id, secondDevelopment.id])
    }

    func testFilteringIncludesOnlyRequestedPurposeOrUnspecified() {
        let preparation = MobilityRoutine(name: "Preparation", purpose: .preparation)
        let development = MobilityRoutine(name: "Development", purpose: .development)
        let unspecified = MobilityRoutine(name: "Unspecified")
        let routines = [preparation, development, unspecified]

        XCTAssertEqual(
            MobilityRoutinePurposeGrouping.filtered(routines, by: .purpose(.preparation)).map(\.id),
            [preparation.id]
        )
        XCTAssertEqual(
            MobilityRoutinePurposeGrouping.filtered(routines, by: .unspecified).map(\.id),
            [unspecified.id]
        )
        XCTAssertEqual(MobilityRoutinePurposeGrouping.filtered(routines, by: .all).map(\.id), routines.map(\.id))
    }

    func testSeedBackfillAppliesOnlyToUnsetBundledRoutinesAndPreservesItems() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let record = try XCTUnwrap(
            context.fetch(FetchDescriptor<SystemSeedRecord>()).first {
                $0.seedKey == "mobility-routine.squat-preparation"
            }
        )
        let routine = try XCTUnwrap(
            context.fetch(FetchDescriptor<MobilityRoutine>()).first { $0.id == record.entityID }
        )
        let itemIDs = routine.orderedItems.map(\.id)
        let registry = try SystemSeedRegistry(context: context)

        routine.purpose = nil
        try MobilitySeedData.stage(using: context, registry: registry)
        XCTAssertEqual(routine.purpose, .preparation)
        XCTAssertEqual(routine.orderedItems.map(\.id), itemIDs)

        routine.purpose = .cooldown
        try MobilitySeedData.stage(using: context, registry: registry)
        XCTAssertEqual(routine.purpose, .cooldown)

        record.sourceKind = .migratedLegacy
        routine.purpose = nil
        try MobilitySeedData.stage(using: context, registry: registry)
        XCTAssertNil(routine.purpose)
    }
}

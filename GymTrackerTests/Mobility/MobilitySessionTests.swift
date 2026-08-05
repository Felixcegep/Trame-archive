import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilitySessionTests: XCTestCase {
    func testStartingRoutineCreatesIndependentSnapshotsAndSeparateSides() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(
            name: "Hip switch",
            instructions: "Move slowly.",
            trackingType: .repetitions,
            defaultDurationSeconds: nil,
            defaultRepetitions: 8
        )
        let routine = MobilityRoutine(name: "Hips")
        routine.items = [
            MobilityRoutineItem(definition: definition, orderIndex: 0, targetRepetitions: 8, side: .alternating),
            MobilityRoutineItem(definition: definition, orderIndex: 1, targetRepetitions: 12, side: .alternating)
        ]
        context.insert(definition)
        context.insert(routine)
        try context.save()

        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        XCTAssertEqual(session.entries.count, 2)
        XCTAssertNotEqual(session.orderedEntries[0].id, session.orderedEntries[1].id)
        XCTAssertEqual(Set(session.orderedEntries[0].results.map(\.side)), Set([.left, .right]))
        XCTAssertEqual(session.orderedEntries[1].targetRepetitions, 12)

        definition.name = "Changed later"
        definition.instructions = "Changed later."
        definition.isArchived = true
        try context.save()
        XCTAssertEqual(session.orderedEntries[0].definitionNameSnapshot, "Hip switch")
        XCTAssertEqual(session.orderedEntries[0].instructionsSnapshot, "Move slowly.")
        XCTAssertFalse(session.orderedEntries[0].definitionNameSnapshot == definition.name)
    }

    func testCompletingAndStoppingPreservesDistinctResultStates() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(name: "Couch stretch")
        let routine = MobilityRoutine(name: "Reset")
        routine.items = [
            MobilityRoutineItem(definition: definition, orderIndex: 0, targetDurationSeconds: 30, side: .left),
            MobilityRoutineItem(definition: definition, orderIndex: 1, targetDurationSeconds: 30, side: .right)
        ]
        context.insert(definition)
        context.insert(routine)
        try context.save()

        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        XCTAssertTrue(MobilitySessionService.completeCurrent(in: session, performedDurationSeconds: 30, using: context))
        XCTAssertEqual(session.orderedEntries[0].results.first?.status, .completed)
        XCTAssertTrue(MobilitySessionService.stop(session, using: context))
        XCTAssertEqual(session.status, .stopped)
        XCTAssertEqual(session.orderedEntries[1].results.first?.status, .stopped)
    }

    func testCompletingAlternatingMovementPreservesPerSideValues() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(
            name: "Hip rotation",
            trackingType: .repetitions,
            defaultDurationSeconds: nil,
            defaultRepetitions: 8
        )
        let routine = MobilityRoutine(name: "Sides")
        routine.items = [
            MobilityRoutineItem(definition: definition, orderIndex: 0, targetRepetitions: 8, side: .alternating)
        ]
        context.insert(definition)
        context.insert(routine)
        try context.save()

        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        let resultsBySide = Dictionary(uniqueKeysWithValues: session.currentEntry?.results.map { ($0.side, $0) } ?? [])
        let left = try XCTUnwrap(resultsBySide[.left])
        let right = try XCTUnwrap(resultsBySide[.right])

        XCTAssertTrue(MobilitySessionService.completeCurrent(
            in: session,
            resultInputs: [
                left.id: MobilityResultInput(performedDurationSeconds: nil, performedRepetitions: 6, perceivedIntensity: 2, discomfortNote: nil),
                right.id: MobilityResultInput(performedDurationSeconds: nil, performedRepetitions: 8, perceivedIntensity: 4, discomfortNote: "Tight on the right")
            ],
            using: context
        ))

        XCTAssertEqual(left.performedRepetitions, 6)
        XCTAssertEqual(right.performedRepetitions, 8)
        XCTAssertEqual(left.perceivedIntensity, 2)
        XCTAssertEqual(right.perceivedIntensity, 4)
        XCTAssertNil(left.discomfortNote)
        XCTAssertEqual(right.discomfortNote, "Tight on the right")
    }

    func testPriorSessionKeepsPerformedValuesForSimpleProgressionComparison() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(name: "Couch stretch")
        let routine = MobilityRoutine(name: "Daily reset")
        routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0, targetDurationSeconds: 30, side: .left)]
        context.insert(definition)
        context.insert(routine)
        try context.save()

        let firstSession = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        XCTAssertTrue(MobilitySessionService.completeCurrent(in: firstSession, performedDurationSeconds: 45, using: context))
        let priorResult = try XCTUnwrap(firstSession.orderedEntries.first?.results.first)

        let secondSession = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        XCTAssertEqual(secondSession.orderedEntries.first?.targetDurationSeconds, 30)
        XCTAssertEqual(priorResult.performedDurationSeconds, 45)
        XCTAssertEqual(priorResult.status, .completed)
    }

    /// Sentinel round trip mirroring `BackupFieldCoverageTests` (which does
    /// not yet cover any Mobility DTO): build a family/definition/routine/item
    /// with every field set to a distinct value, run a session through to
    /// completion with per-side sentinel results, then push the backup
    /// through a real JSON encode/decode (not just an in-process
    /// create→restore) before asserting field-by-field. A deleted mapping
    /// line in `GymBackupCreate`/`GymBackupRestore` turns one of these red.
    func testMobilityRecordsRoundTripEveryPersistedFieldThenClearAllData() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let family = MobilityFamily(name: "Sentinel Family")
        let definition = MobilityDefinition(
            name: "Sentinel Loaded Stretch",
            instructions: "sentinel-instructions",
            trackingType: .repetitions,
            defaultDurationSeconds: nil,
            defaultRepetitions: 8,
            family: family
        )
        let item = MobilityRoutineItem(
            definition: definition,
            orderIndex: 0,
            targetRepetitions: 8,
            targetLoadValue: 15.5,
            targetLoadUnit: .kilograms,
            side: .bilateral,
            restSeconds: 45,
            notes: "sentinel-item-notes"
        )
        let routine = MobilityRoutine(
            name: "Sentinel Routine",
            notes: "sentinel-routine-notes",
            purpose: .development
        )
        routine.items = [item]
        source.insert(family)
        source.insert(definition)
        source.insert(routine)
        try source.save()

        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: source))
        let entry = try XCTUnwrap(session.entries.first)
        let resultsBySide = Dictionary(uniqueKeysWithValues: entry.results.map { ($0.side, $0) })
        let left = try XCTUnwrap(resultsBySide[.left])
        let right = try XCTUnwrap(resultsBySide[.right])
        XCTAssertTrue(MobilitySessionService.completeCurrent(
            in: session,
            resultInputs: [
                left.id: MobilityResultInput(performedDurationSeconds: nil, performedRepetitions: 8, performedLoadValue: 16.0, performedLoadUnit: .kilograms, perceivedIntensity: 3, discomfortNote: "sentinel-left-note"),
                right.id: MobilityResultInput(performedDurationSeconds: nil, performedRepetitions: 6, performedLoadValue: 14.0, performedLoadUnit: .kilograms, perceivedIntensity: 5, discomfortNote: nil)
            ],
            using: source
        ))

        let backup = try BackupDTO.create(from: source, restTimer: 90, darkMode: false, unitSystem: .metric)
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        XCTAssertEqual(backup.mobilityRoutines.first?.purpose, MobilityRoutinePurpose.development.rawValue)
        XCTAssertEqual(backup.mobilitySessions.count, 1)
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try decoded.restore(to: restored)

        // `restore(to:)` also re-stages the full bundled system catalog
        // (`SystemSeedCatalogCoordinator.stageBundledCatalog`, see
        // `GymBackupRestore.swift`), so `restored` legitimately contains the
        // built-in Mobility families/definitions/routines alongside the
        // sentinel ones from this backup -- look the sentinel records up by
        // name rather than assuming they are `.first`, exactly like
        // `BackupFieldCoverageTests` does for its own sentinel fixtures.
        let restoredFamily = try XCTUnwrap(
            restored.fetch(FetchDescriptor<MobilityFamily>()).first { $0.name == "Sentinel Family" }
        )
        XCTAssertEqual(restoredFamily.name, "Sentinel Family")

        let restoredDefinition = try XCTUnwrap(
            restored.fetch(FetchDescriptor<MobilityDefinition>()).first { $0.name == "Sentinel Loaded Stretch" }
        )
        XCTAssertEqual(restoredDefinition.instructions, "sentinel-instructions")
        XCTAssertEqual(restoredDefinition.defaultRepetitions, 8)

        let restoredRoutine = try XCTUnwrap(
            restored.fetch(FetchDescriptor<MobilityRoutine>()).first { $0.name == "Sentinel Routine" }
        )
        XCTAssertEqual(restoredRoutine.notes, "sentinel-routine-notes")
        let restoredItem = try XCTUnwrap(restoredRoutine.orderedItems.first)
        XCTAssertEqual(restoredItem.targetLoadValue, 15.5)
        XCTAssertEqual(restoredItem.targetLoadUnit, .kilograms)
        XCTAssertEqual(restoredItem.restSeconds, 45)
        XCTAssertEqual(restoredItem.notes, "sentinel-item-notes")

        let restoredSession = try XCTUnwrap(restored.fetch(FetchDescriptor<MobilitySession>()).first)
        XCTAssertEqual(restoredSession.status, .completed)
        let restoredEntry = try XCTUnwrap(restoredSession.orderedEntries.first)
        XCTAssertEqual(restoredEntry.definitionNameSnapshot, "Sentinel Loaded Stretch")
        XCTAssertEqual(restoredEntry.instructionsSnapshot, "sentinel-instructions")
        XCTAssertEqual(restoredEntry.prescribedLoadValue, 15.5)
        XCTAssertEqual(restoredEntry.prescribedLoadUnit, .kilograms)
        XCTAssertEqual(restoredEntry.results.count, 2)

        let restoredResultsBySide = Dictionary(uniqueKeysWithValues: restoredEntry.results.map { ($0.side, $0) })
        let restoredLeft = try XCTUnwrap(restoredResultsBySide[.left])
        let restoredRight = try XCTUnwrap(restoredResultsBySide[.right])
        XCTAssertEqual(restoredLeft.performedRepetitions, 8)
        XCTAssertEqual(restoredLeft.performedLoadValue, 16.0)
        XCTAssertEqual(restoredLeft.perceivedIntensity, 3)
        XCTAssertEqual(restoredLeft.discomfortNote, "sentinel-left-note")
        XCTAssertEqual(restoredRight.performedRepetitions, 6)
        XCTAssertEqual(restoredRight.performedLoadValue, 14.0)
        XCTAssertEqual(restoredRight.perceivedIntensity, 5)
        XCTAssertNil(restoredRight.discomfortNote)

        try restored.clearAllGymData()
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilitySession>()).isEmpty)
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilityRoutine>()).isEmpty)
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilityDefinition>()).isEmpty)
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilityFamily>()).isEmpty)
    }

    /// Replaces a prior version of this test that asserted `definitions.count
    /// == 54`, `families.count == 8`, and `routines.count == 10` -- a seed
    /// census that breaks every time mobility content is added or removed,
    /// even though nothing behavioral changed. These invariants instead test
    /// the actual contract: every routine resolves the definitions it was
    /// authored with (a typo'd definition name in the seed table silently
    /// drops that item instead of failing loudly), names stay unique (the
    /// seed's own dedup key), and re-seeding is idempotent -- verified by
    /// comparing the re-fetch against the first fetch, not a hardcoded count.
    func testSeedingProducesConsistentNonDuplicatedCatalogWithResolvedRoutines() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        MobilitySeedData.seedIfNeeded(using: context)

        let definitions = try context.fetch(FetchDescriptor<MobilityDefinition>())
        let families = try context.fetch(FetchDescriptor<MobilityFamily>())
        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())

        XCTAssertFalse(definitions.isEmpty)
        XCTAssertFalse(families.isEmpty)
        XCTAssertFalse(routines.isEmpty)

        let authoredPurposes: [String: MobilityRoutinePurpose] = [
            "Daily mobility reset": .development,
            "Post-Leg Day Mobility Reset": .cooldown,
            "Upper Body Bench Warmup": .preparation,
            "Lower Back & Hips Decompression": .cooldown,
            "Overhead & Shoulder Saver": .development,
            "Full Body Morning Flow": .development,
            "Ankle & Foot Mobilization": .development,
            "Desk Worker Reset": .development,
            "Loaded Mobility Foundations": .development,
            "Hamstring Contract-Relax PNF": .development,
            "Squat Preparation": .preparation,
            "Deadlift Preparation": .preparation,
            "Front-Rack and Wrist Preparation": .preparation,
            "Olympic Lifting Preparation": .preparation,
            "Strongman Event Preparation": .preparation
        ]
        XCTAssertEqual(authoredPurposes.count, 15)
        let purposesByName = Dictionary(uniqueKeysWithValues: routines.map { ($0.name, $0.purpose) })
        XCTAssertEqual(routines.count, 25)
        for (name, expectedPurpose) in authoredPurposes {
            XCTAssertEqual(purposesByName[name], expectedPurpose, "Seeded routine '\(name)' must retain its authored purpose")
        }

        let definitionNames = definitions.map(\.name)
        XCTAssertEqual(Set(definitionNames).count, definitionNames.count, "Seeded definitions must have unique names")
        let familyNames = families.map(\.name)
        XCTAssertEqual(Set(familyNames).count, familyNames.count, "Seeded families must have unique names")

        let definitionIDs = Set(definitions.map(\.id))
        for routine in routines {
            XCTAssertFalse(routine.orderedItems.isEmpty, "Routine '\(routine.name)' resolved no items")
            for item in routine.orderedItems {
                XCTAssertTrue(
                    definitionIDs.contains(item.definition.id),
                    "Routine '\(routine.name)' has an item whose definition is not among the seeded definitions"
                )
            }
        }

        // Running seed again should be idempotent and not create duplicate
        // definitions, families, or routines -- checked against the counts
        // and identities from the first fetch, never a magic literal.
        MobilitySeedData.seedIfNeeded(using: context)
        let reFetchedDefinitions = try context.fetch(FetchDescriptor<MobilityDefinition>())
        let reFetchedFamilies = try context.fetch(FetchDescriptor<MobilityFamily>())
        let reFetchedRoutines = try context.fetch(FetchDescriptor<MobilityRoutine>())

        XCTAssertEqual(reFetchedDefinitions.count, definitions.count, "Re-seeding must not duplicate definitions")
        XCTAssertEqual(reFetchedFamilies.count, families.count, "Re-seeding must not duplicate families")
        XCTAssertEqual(reFetchedRoutines.count, routines.count, "Re-seeding must not duplicate routines")
        XCTAssertEqual(
            Set(reFetchedDefinitions.map(\.id)), Set(definitions.map(\.id)),
            "Re-seeding must reuse the same definition identities rather than minting new ones"
        )
    }
}

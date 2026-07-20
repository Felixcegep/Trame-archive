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

    func testMobilityRecordsRoundTripThroughBackupAndClearAllData() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let family = MobilityFamily(name: "Hip mobility")
        let definition = MobilityDefinition(name: "90/90", trackingType: .repetitions, defaultDurationSeconds: nil, defaultRepetitions: 8, family: family)
        let routine = MobilityRoutine(name: "Daily reset")
        routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0, targetRepetitions: 8, side: .alternating)]
        source.insert(family)
        source.insert(definition)
        source.insert(routine)
        try source.save()
        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: source))
        XCTAssertTrue(MobilitySessionService.completeCurrent(in: session, performedRepetitions: 8, using: source))

        let backup = try BackupDTO.create(from: source, restTimer: 90, darkMode: false, unitSystem: .metric)
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        XCTAssertEqual(backup.mobilitySessions.count, 1)

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)
        let restoredSession = try XCTUnwrap(restored.fetch(FetchDescriptor<MobilitySession>()).first)
        XCTAssertEqual(restoredSession.status, .completed)
        XCTAssertEqual(restoredSession.orderedEntries.first?.results.count, 2)

        try restored.clearAllGymData()
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilitySession>()).isEmpty)
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilityRoutine>()).isEmpty)
        XCTAssertTrue(try restored.fetch(FetchDescriptor<MobilityDefinition>()).isEmpty)
    }
}

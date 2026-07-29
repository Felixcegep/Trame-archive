import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentPersistenceTests: XCTestCase {
    func testActiveSessionAndPartialSidesSurviveANewContext() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        context.insert(definition)
        try context.save()

        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            day: LocalDay(rawValue: "2026-07-29"),
            using: context
        )
        _ = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: input(for: definition, side: .left, value: 41),
            using: context
        )

        let relaunched = ModelContext(container)
        let restoredSession = try XCTUnwrap(
            relaunched.fetch(FetchDescriptor<MobilityAssessmentSession>()).first
        )
        XCTAssertEqual(restoredSession.status, .active)
        XCTAssertEqual(restoredSession.results.count, 1)
        XCTAssertEqual(restoredSession.results.first?.side, .left)
        XCTAssertNil(restoredSession.results.first { $0.side == .right })
    }

    func testEditingResultReplacesSameSideWithoutCreatingDuplicateHistory() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        context.insert(definition)
        try context.save()
        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            using: context
        )

        let first = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: input(for: definition, side: .left, value: 41),
            using: context
        )
        let edited = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: input(for: definition, side: .left, value: 44),
            using: context
        )

        XCTAssertEqual(first.id, edited.id)
        XCTAssertEqual(session.results.count, 1)
        XCTAssertEqual(edited.numericValue, 44)
    }

    func testStoppingPreservesResultsAndDefinitionEditsDoNotRewriteSnapshots() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        context.insert(definition)
        try context.save()
        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            using: context
        )
        let result = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: input(for: definition, side: .left, value: 41),
            using: context
        )
        let snapshotName = result.definitionNameSnapshot

        definition.name = "Renamed current definition"
        definition.definitionVersion = 2
        try context.save()
        try MobilityAssessmentSessionService.stop(session, using: context)

        XCTAssertEqual(session.status, .stopped)
        XCTAssertEqual(session.results.count, 1)
        XCTAssertEqual(result.definitionNameSnapshot, snapshotName)
        XCTAssertEqual(result.definitionVersionSnapshot, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MobilitySession>()).isEmpty)
    }

    private func input(
        for definition: MobilityAssessmentDefinition,
        side: MobilityAssessmentSide,
        value: Double
    ) -> MobilityAssessmentResultInput {
        MobilityAssessmentResultInput(
            numericValue: value,
            side: side,
            isWarm: false,
            setupKey: definition.defaultSetupKey,
            method: definition.manualMode,
            unit: definition.unit,
            isActiveRange: definition.defaultIsActiveRange,
            day: LocalDay(rawValue: "2026-07-29")
        )
    }
}

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentBackupTests: XCTestCase {
    func testBackupV24RoundTripsDefinitionsSessionsResultsSnapshotsAndSamples() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: source)
        let definition = try XCTUnwrap(
            try MobilityAssessmentCatalogService.definitions(using: source).first
        )
        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            day: LocalDay(rawValue: "2026-07-29"),
            startedAt: Date(timeIntervalSince1970: 100),
            using: source
        )
        let manual = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: MobilityAssessmentResultInput(
                numericValue: 47.5,
                side: definition.supportedSides[0],
                isWarm: false,
                setupKey: definition.defaultSetupKey,
                method: definition.manualMode,
                unit: definition.unit,
                isActiveRange: definition.defaultIsActiveRange,
                day: LocalDay(rawValue: "2026-07-29"),
                source: .manual,
                confidence: .moderate
            ),
            now: Date(timeIntervalSince1970: 110),
            using: source
        )
        let historicalName = manual.definitionNameSnapshot
        try MobilityAssessmentSessionService.complete(
            session,
            completedAt: Date(timeIntervalSince1970: 120),
            using: source
        )

        let sampleSession = MobilityAssessmentSession(
            day: LocalDay(rawValue: "2026-07-28"),
            selectedDefinitionKeys: [definition.catalogueKey],
            startedAt: Date(timeIntervalSince1970: 50),
            createdAt: Date(timeIntervalSince1970: 50),
            updatedAt: Date(timeIntervalSince1970: 60)
        )
        sampleSession.status = .completed
        sampleSession.currentDefinitionIndex = 1
        sampleSession.completedAt = Date(timeIntervalSince1970: 60)
        let deviceResult = MobilityAssessmentResult(
            definition: definition,
            input: MobilityAssessmentResultInput(
                numericValue: 45,
                side: definition.supportedSides[0],
                isWarm: true,
                setupKey: definition.defaultSetupKey,
                method: definition.preferredMode,
                unit: .degrees,
                isActiveRange: definition.defaultIsActiveRange,
                day: LocalDay(rawValue: "2026-07-28"),
                source: .deviceMotion,
                confidence: .high
            ),
            orderIndex: 0,
            createdAt: Date(timeIntervalSince1970: 55),
            updatedAt: Date(timeIntervalSince1970: 55)
        )
        deviceResult.sample = MobilityAssessmentSample(
            sampleCount: 150,
            median: 45,
            minimum: 44.5,
            maximum: 45.5,
            standardDeviation: 0.2,
            offAxisExcessDegrees: 0.8,
            captureDuration: 3
        )
        sampleSession.results = [deviceResult]
        source.insert(sampleSession)
        try source.save()

        definition.name = "Current definition renamed after observation"
        definition.definitionVersion = 2
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        XCTAssertEqual(backup.mobilityAssessmentDefinitions.count, 10)
        XCTAssertEqual(backup.mobilityAssessmentSessions.count, 2)
        let encoded = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: encoded)
        try decoded.validate()

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try decoded.restore(to: restored)
        let sessions = try restored.fetch(FetchDescriptor<MobilityAssessmentSession>())
        XCTAssertEqual(sessions.count, 2)
        let restoredManual = try XCTUnwrap(
            sessions.flatMap(\.results).first { $0.id == manual.id }
        )
        XCTAssertEqual(restoredManual.numericValue, 47.5)
        XCTAssertEqual(restoredManual.definitionNameSnapshot, historicalName)
        XCTAssertEqual(restoredManual.definitionVersionSnapshot, 1)
        XCTAssertEqual(restoredManual.source, .manual)
        XCTAssertNil(restoredManual.sample)

        let restoredDevice = try XCTUnwrap(
            sessions.flatMap(\.results).first { $0.id == deviceResult.id }
        )
        XCTAssertEqual(restoredDevice.source, .deviceMotion)
        XCTAssertEqual(restoredDevice.confidence, .high)
        XCTAssertEqual(restoredDevice.sample?.sampleCount, 150)
        XCTAssertEqual(restoredDevice.sample?.median, 45)
        XCTAssertEqual(restoredDevice.sample?.offAxisExcessDegrees, 0.8)

        let currentDefinition = try XCTUnwrap(
            try MobilityAssessmentCatalogService.definition(
                catalogueKey: definition.catalogueKey,
                using: restored
            )
        )
        XCTAssertNotEqual(currentDefinition.name, "Current definition renamed after observation")
        XCTAssertEqual(currentDefinition.definitionVersion, 1)
    }

    func testV23RestoresWithNoFabricatedAssessmentSessions() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: source)
        let definition = try XCTUnwrap(
            try MobilityAssessmentCatalogService.definitions(using: source).first
        )
        _ = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            using: source
        )
        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let legacy = try replacingJSONValue(
            in: backup,
            at: ["version"],
            with: 23
        )

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try legacy.restore(to: restored)
        XCTAssertTrue(
            try restored.fetch(FetchDescriptor<MobilityAssessmentSession>()).isEmpty
        )
        XCTAssertEqual(
            try restored.fetchCount(FetchDescriptor<MobilityAssessmentDefinition>()),
            10
        )
    }

    func testUnknownAssessmentEnumIsRejectedBeforeExistingDataIsReplaced() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: source)
        let definition = try XCTUnwrap(
            try MobilityAssessmentCatalogService.definitions(using: source).first
        )
        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            using: source
        )
        _ = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: MobilityAssessmentResultInput(
                numericValue: 40,
                side: definition.supportedSides[0],
                isWarm: false,
                setupKey: definition.defaultSetupKey,
                method: definition.manualMode,
                unit: definition.unit,
                isActiveRange: definition.defaultIsActiveRange,
                day: session.day
            ),
            using: source
        )
        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let corrupt = try replacingJSONValue(
            in: backup,
            at: ["mobilityAssessmentSessions", 0, "results", 0, "method"],
            with: "future-unknown-mode"
        )

        let target = try GymTrackerTestStore.makeInMemoryContext()
        let sentinel = MobilityAssessmentSession(
            day: LocalDay(rawValue: "2026-01-01"),
            selectedDefinitionKeys: ["sentinel"]
        )
        target.insert(sentinel)
        try target.save()

        XCTAssertThrowsError(try corrupt.restore(to: target))
        XCTAssertEqual(
            try target.fetch(FetchDescriptor<MobilityAssessmentSession>()).map(\.id),
            [sentinel.id]
        )
    }

    private func replacingJSONValue(
        in backup: BackupDTO,
        at path: [Any],
        with value: Any
    ) throws -> BackupDTO {
        let data = try JSONEncoder().encode(backup)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        try setJSONValue(value, path: ArraySlice(path), object: &object)
        let modified = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(BackupDTO.self, from: modified)
    }

    private func setJSONValue(
        _ value: Any,
        path: ArraySlice<Any>,
        object: inout [String: Any]
    ) throws {
        guard let first = path.first else { return }
        guard let key = first as? String else {
            XCTFail("Expected a dictionary key")
            return
        }
        if path.count == 1 {
            object[key] = value
            return
        }
        if let index = path.dropFirst().first as? Int {
            var array = try XCTUnwrap(object[key] as? [[String: Any]])
            var child = array[index]
            try setJSONValue(
                value,
                path: path.dropFirst(2),
                object: &child
            )
            array[index] = child
            object[key] = array
        } else {
            var child = try XCTUnwrap(object[key] as? [String: Any])
            try setJSONValue(value, path: path.dropFirst(), object: &child)
            object[key] = child
        }
    }
}

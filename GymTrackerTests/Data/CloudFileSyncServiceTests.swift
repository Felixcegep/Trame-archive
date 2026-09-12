import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class CloudFileSyncServiceTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CloudFileSyncServiceTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudFileSync-\(UUID().uuidString).json")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }

    override func tearDownWithError() throws {
        if let suiteName {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        testDefaults = nil
        suiteName = nil
        fileURL = nil
        try super.tearDownWithError()
    }

    func testPushThenManualSyncIsInSync() async throws {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.bodyWeightPromptCadence)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.caffeineBirthdateTimestamp)

        let context = try GymTrackerTestStore.makeInMemoryContext()
        let service = CloudFileSyncService(defaults: testDefaults)
        try service.link(url: fileURL)

        let first = try BackupArchiveFileWriter.encode(
            try BackupDTO.create(
                from: context,
                restTimer: 90,
                darkMode: false,
                unitSystem: .metric
            )
        )
        let second = try BackupArchiveFileWriter.encode(
            try BackupDTO.create(
                from: context,
                restTimer: 90,
                darkMode: false,
                unitSystem: .metric
            )
        )
        XCTAssertEqual(
            CloudFileContentHash.sha256Hex(first),
            CloudFileContentHash.sha256Hex(second),
            "Two exports of the same empty store must hash identically or in-sync cannot be detected."
        )

        let pushed = await service.sync(
            from: context,
            hasActiveWorkout: false,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric,
            request: .keepThisIPhone
        )
        XCTAssertEqual(pushed, .pushed)
        XCTAssertEqual(service.lastOutcome, .pushed)
        XCTAssertNotNil(service.linkedRecord?.lastSyncedHash)

        let again = await service.sync(
            from: context,
            hasActiveWorkout: false,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric,
            request: .manual
        )
        XCTAssertEqual(again, .inSync)
    }

    func testBothSidesChangedReportsConflict() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let service = CloudFileSyncService(defaults: testDefaults)
        try service.link(url: fileURL)

        let pushed = await service.sync(
            from: context,
            hasActiveWorkout: false,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric,
            request: .keepThisIPhone
        )
        XCTAssertEqual(pushed, .pushed)

        try CloudFileIO.write(Data(#"{"version":1,"not":"local"}"#.utf8), to: fileURL)

        let outcome = await service.sync(
            from: context,
            hasActiveWorkout: false,
            restTimer: 45,
            darkMode: true,
            unitSystem: .imperial,
            request: .manual
        )
        XCTAssertEqual(outcome, .conflict)
    }

    func testPullIsSkippedDuringActiveWorkout() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let service = CloudFileSyncService(defaults: testDefaults)
        try service.link(url: fileURL)

        _ = await service.sync(
            from: context,
            hasActiveWorkout: false,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric,
            request: .keepThisIPhone
        )
        let pushedHash = try XCTUnwrap(service.linkedRecord?.lastSyncedHash)

        let other = try BackupArchiveFileWriter.encode(
            BackupDTO(
                version: BackupDTO.currentVersion,
                preferences: PreferencesDTO(
                    darkMode: true,
                    restTimer: 30,
                    unitSystem: UnitSystem.metric.rawValue
                ),
                exercises: [],
                templates: [],
                collections: [],
                workouts: []
            )
        )
        try CloudFileIO.write(other, to: fileURL)
        XCTAssertNotEqual(CloudFileContentHash.sha256Hex(other), pushedHash)

        let skipped = await service.sync(
            from: context,
            hasActiveWorkout: true,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric,
            request: .automatic
        )
        XCTAssertEqual(skipped, .skippedActiveWorkout)
    }

    func testUnlinkClearsRecord() throws {
        let service = CloudFileSyncService(defaults: testDefaults)
        try service.link(url: fileURL)
        XCTAssertTrue(service.isLinked)
        service.unlink()
        XCTAssertFalse(service.isLinked)
        XCTAssertEqual(service.lastOutcome, .unlinked)
    }
}

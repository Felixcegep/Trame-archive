//
//  DataSafetyServiceTests.swift
//  GymTrackerTests
//

import XCTest
import SwiftData
@testable import GymTracker

final class DataSafetyServiceTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "DataSafetyServiceTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDownWithError() throws {
        if let suiteName {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testMetadataDefaultValuesWhenUnset() {
        let service = DataSafetyService(defaults: testDefaults)
        let metadata = service.fetchMetadata()

        XCTAssertTrue(metadata.isStoredLocally)
        XCTAssertEqual(metadata.storageLocationDescription, String(localized: "This iPhone"))
        XCTAssertNil(metadata.lastExportDate)
        XCTAssertNil(metadata.lastRestoreDate)
        XCTAssertFalse(metadata.hasExported)
        XCTAssertFalse(metadata.hasRestoredBeenTested)
        XCTAssertEqual(metadata.backupFormatVersion, "v\(BackupDTO.currentVersion)")
        XCTAssertEqual(metadata.formatVersionNumber, BackupDTO.currentVersion)
        XCTAssertEqual(metadata.formattedLastExportDate(), String(localized: "Never"))
        XCTAssertEqual(metadata.restoreTestedDescription(), String(localized: "Not yet"))
    }

    func testMetadataReadingRecordedTimestamps() {
        let exportTimestamp: Double = 1750000000 // Fixed epoch timestamp
        let restoreTimestamp: Double = 1750003600

        testDefaults.set(exportTimestamp, forKey: DefaultsKey.lastBackupExportTimestamp)
        testDefaults.set(restoreTimestamp, forKey: DefaultsKey.lastBackupRestoreTimestamp)

        let service = DataSafetyService(defaults: testDefaults)
        let metadata = service.fetchMetadata()

        XCTAssertTrue(metadata.hasExported)
        XCTAssertTrue(metadata.hasRestoredBeenTested)
        XCTAssertEqual(metadata.lastExportDate, Date(timeIntervalSince1970: exportTimestamp))
        XCTAssertEqual(metadata.lastRestoreDate, Date(timeIntervalSince1970: restoreTimestamp))

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let expectedExportString = formatter.string(from: Date(timeIntervalSince1970: exportTimestamp))
        let expectedRestoreString = formatter.string(from: Date(timeIntervalSince1970: restoreTimestamp))

        XCTAssertEqual(metadata.formattedLastExportDate(formatter: formatter), expectedExportString)
        XCTAssertEqual(metadata.restoreTestedDescription(formatter: formatter), expectedRestoreString)
    }

    func testRecordExportAndRestoreSuccess() {
        let service = DataSafetyService(defaults: testDefaults)

        let exportDate = Date(timeIntervalSince1970: 1760000000)
        let restoreDate = Date(timeIntervalSince1970: 1760050000)

        service.recordExportSuccess(at: exportDate)
        service.recordRestoreSuccess(at: restoreDate)

        let metadata = service.fetchMetadata()
        XCTAssertEqual(metadata.lastExportDate, exportDate)
        XCTAssertEqual(metadata.lastRestoreDate, restoreDate)
    }

    @MainActor
    func testExportDataAction() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let service = DataSafetyService(defaults: testDefaults)

        let result = try await service.exportData(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )

        XCTAssertEqual(result.backup.version, BackupDTO.currentVersion)
        XCTAssertEqual(result.backup.preferences.restTimer, 90)
        XCTAssertFalse(result.backup.preferences.darkMode)
        XCTAssertEqual(result.backup.preferences.unitSystem, UnitSystem.metric.rawValue)

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        XCTAssertGreaterThan(result.data.count, 0)

        let updatedMetadata = service.fetchMetadata()
        XCTAssertTrue(updatedMetadata.hasExported)
        XCTAssertNotNil(updatedMetadata.lastExportDate)
    }

    func testGymBackupServiceTypealiasEquivalence() {
        let metadata = GymBackupService.fetchMetadata(defaults: testDefaults)
        XCTAssertTrue(metadata.isStoredLocally)
        XCTAssertEqual(metadata.backupFormatVersion, "v\(BackupDTO.currentVersion)")
    }
}

//
//  CloudFileLinkStoreTests.swift
//  GymTrackerTests
//

import XCTest
@testable import GymTracker

final class CloudFileLinkStoreTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CloudFileLinkStoreTests.\(UUID().uuidString)"
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

    func testSaveLoadRoundTrip() {
        let store = CloudFileLinkStore(defaults: testDefaults)
        let syncedAt = Date(timeIntervalSince1970: 1_760_000_000)
        let record = CloudFileLinkRecord(
            bookmarkData: Data("bookmark-bytes".utf8),
            displayName: "Trame Backup.json",
            locationKind: .iCloudDrive,
            lastSyncedHash: "abc123",
            lastSyncedAt: syncedAt
        )

        XCTAssertNil(store.load())
        store.save(record)

        let loaded = store.load()
        XCTAssertEqual(loaded?.bookmarkData, record.bookmarkData)
        XCTAssertEqual(loaded?.displayName, record.displayName)
        XCTAssertEqual(loaded?.locationKind, record.locationKind)
        XCTAssertEqual(loaded?.lastSyncedHash, record.lastSyncedHash)
        XCTAssertEqual(
            loaded?.lastSyncedAt?.timeIntervalSince1970 ?? -1,
            syncedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertNil(loaded?.googleDriveFileID)
        XCTAssertNil(loaded?.googleDriveAccountEmail)
        XCTAssertEqual(loaded?.syncMode, .automatic)
        XCTAssertEqual(loaded?.usesGoogleDriveAPI, false)
    }

    func testGoogleDriveFieldsRoundTrip() {
        let store = CloudFileLinkStore(defaults: testDefaults)
        let record = CloudFileLinkRecord(
            bookmarkData: Data(),
            displayName: "TrameBackup.json",
            locationKind: .googleDrive,
            lastSyncedHash: "drive-hash",
            lastSyncedAt: Date(timeIntervalSince1970: 1_760_000_000),
            googleDriveFileID: "file-123",
            googleDriveAccountEmail: "lifter@example.com",
            syncMode: .manual
        )

        store.save(record)
        let loaded = store.load()
        XCTAssertEqual(loaded?.googleDriveFileID, "file-123")
        XCTAssertEqual(loaded?.googleDriveAccountEmail, "lifter@example.com")
        XCTAssertEqual(loaded?.syncMode, .manual)
        XCTAssertEqual(loaded?.usesGoogleDriveAPI, true)
        XCTAssertEqual(loaded?.bookmarkData, Data())
    }

    func testLegacyJSONDecodesAsAutomaticWithNilDriveIDs() throws {
        struct LegacyRecord: Encodable {
            var bookmarkData: Data
            var displayName: String
            var locationKind: CloudFileLocationKind
            var lastSyncedHash: String?
            var lastSyncedAt: Date?
        }

        let syncedAt = Date(timeIntervalSince1970: 1_760_000_000)
        let data = try JSONEncoder().encode(
            LegacyRecord(
                bookmarkData: Data("bookmark-bytes".utf8),
                displayName: "Trame Backup.json",
                locationKind: .iCloudDrive,
                lastSyncedHash: "abc123",
                lastSyncedAt: syncedAt
            )
        )

        let decoded = try JSONDecoder().decode(CloudFileLinkRecord.self, from: data)
        XCTAssertEqual(decoded.bookmarkData, Data("bookmark-bytes".utf8))
        XCTAssertEqual(decoded.displayName, "Trame Backup.json")
        XCTAssertEqual(decoded.locationKind, .iCloudDrive)
        XCTAssertEqual(decoded.lastSyncedHash, "abc123")
        XCTAssertEqual(
            decoded.lastSyncedAt?.timeIntervalSince1970 ?? -1,
            syncedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertNil(decoded.googleDriveFileID)
        XCTAssertNil(decoded.googleDriveAccountEmail)
        XCTAssertEqual(decoded.syncMode, .automatic)
        XCTAssertFalse(decoded.usesGoogleDriveAPI)
    }

    func testClearRemovesRecord() {
        let store = CloudFileLinkStore(defaults: testDefaults)
        store.save(
            CloudFileLinkRecord(
                bookmarkData: Data("bookmark".utf8),
                displayName: "backup.json",
                locationKind: .googleDrive,
                lastSyncedHash: "hash",
                lastSyncedAt: Date(timeIntervalSince1970: 1_760_000_000)
            )
        )

        XCTAssertNotNil(store.load())
        store.clear()
        XCTAssertNil(store.load())
    }

    func testUpdateLastSyncRewritesHashAndDate() {
        let store = CloudFileLinkStore(defaults: testDefaults)
        store.save(
            CloudFileLinkRecord(
                bookmarkData: Data("bookmark".utf8),
                displayName: "backup.json",
                locationKind: .otherFiles,
                lastSyncedHash: "old-hash",
                lastSyncedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )

        let newDate = Date(timeIntervalSince1970: 1_760_050_000)
        store.updateLastSync(hash: "new-hash", at: newDate)

        let loaded = store.load()
        XCTAssertEqual(loaded?.bookmarkData, Data("bookmark".utf8))
        XCTAssertEqual(loaded?.displayName, "backup.json")
        XCTAssertEqual(loaded?.locationKind, .otherFiles)
        XCTAssertEqual(loaded?.lastSyncedHash, "new-hash")
        XCTAssertEqual(
            loaded?.lastSyncedAt?.timeIntervalSince1970 ?? -1,
            newDate.timeIntervalSince1970,
            accuracy: 0.001
        )
    }
}

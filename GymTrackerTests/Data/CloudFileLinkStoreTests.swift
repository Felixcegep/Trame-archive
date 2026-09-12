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

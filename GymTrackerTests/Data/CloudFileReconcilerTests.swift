//
//  CloudFileReconcilerTests.swift
//  GymTrackerTests
//

import XCTest
@testable import GymTracker

final class CloudFileReconcilerTests: XCTestCase {
    func testEqualHashesAreInSync() {
        let decision = CloudFileReconciler.decide(
            localHash: "aaa",
            remoteHash: "aaa",
            lastSyncedHash: "bbb"
        )
        XCTAssertEqual(decision, .inSync)
    }

    func testRemoteMatchesLastSyncedAndLocalDiffersPushes() {
        let decision = CloudFileReconciler.decide(
            localHash: "local-new",
            remoteHash: "synced",
            lastSyncedHash: "synced"
        )
        XCTAssertEqual(decision, .push)
    }

    func testLocalMatchesLastSyncedAndRemoteDiffersPulls() {
        let decision = CloudFileReconciler.decide(
            localHash: "synced",
            remoteHash: "remote-new",
            lastSyncedHash: "synced"
        )
        XCTAssertEqual(decision, .pull)
    }

    func testBothSidesDifferFromLastSyncedConflicts() {
        let decision = CloudFileReconciler.decide(
            localHash: "local-new",
            remoteHash: "remote-new",
            lastSyncedHash: "synced"
        )
        XCTAssertEqual(decision, .conflict)
    }

    func testNilRemoteHashPushes() {
        let decision = CloudFileReconciler.decide(
            localHash: "local",
            remoteHash: nil,
            lastSyncedHash: "synced"
        )
        XCTAssertEqual(decision, .push)
    }

    func testEmptyRemoteHashPushes() {
        let decision = CloudFileReconciler.decide(
            localHash: "local",
            remoteHash: "",
            lastSyncedHash: "synced"
        )
        XCTAssertEqual(decision, .push)
    }

    func testNilLastSyncedAndDifferentHashesConflict() {
        let decision = CloudFileReconciler.decide(
            localHash: "local",
            remoteHash: "remote",
            lastSyncedHash: nil
        )
        XCTAssertEqual(decision, .conflict)
    }

    func testNilLastSyncedAndEqualHashesAreInSync() {
        let decision = CloudFileReconciler.decide(
            localHash: "same",
            remoteHash: "same",
            lastSyncedHash: nil
        )
        XCTAssertEqual(decision, .inSync)
    }
}

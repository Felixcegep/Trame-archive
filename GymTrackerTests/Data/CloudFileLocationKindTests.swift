//
//  CloudFileLocationKindTests.swift
//  GymTrackerTests
//

import XCTest
@testable import GymTracker

final class CloudFileLocationKindTests: XCTestCase {
    func testICloudDrivePathContainingMobileDocuments() {
        let path = "/Users/felix/Library/Mobile Documents/com~apple~CloudDocs/Trame/backup.json"
        XCTAssertEqual(CloudFileLocationKind.classify(path: path), .iCloudDrive)
        XCTAssertEqual(
            CloudFileLocationKind.classify(url: URL(fileURLWithPath: path)),
            .iCloudDrive
        )
    }

    func testGoogleDrivePathContainingGoogleDrive() {
        let path = "/Users/felix/Library/CloudStorage/GoogleDrive-user@gmail.com/My Drive/Trame/backup.json"
        XCTAssertEqual(CloudFileLocationKind.classify(path: path), .googleDrive)
    }

    func testGoogleDrivePathContainingComGoogleDrive() {
        let path = "/private/var/mobile/Containers/Shared/AppGroup/com.google.drive.fileprovider/backup.json"
        XCTAssertEqual(CloudFileLocationKind.classify(path: path), .googleDrive)
        XCTAssertEqual(
            CloudFileLocationKind.classify(url: URL(fileURLWithPath: path)),
            .googleDrive
        )
    }

    func testGenericFilesPathIsOtherFiles() {
        let path = "/Users/felix/Documents/Trame/backup.json"
        XCTAssertEqual(CloudFileLocationKind.classify(path: path), .otherFiles)
        XCTAssertEqual(
            CloudFileLocationKind.classify(url: URL(fileURLWithPath: path)),
            .otherFiles
        )
    }
}

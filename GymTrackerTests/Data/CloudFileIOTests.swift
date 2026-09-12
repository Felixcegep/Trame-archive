//
//  CloudFileIOTests.swift
//  GymTrackerTests
//

import XCTest
@testable import GymTracker

final class CloudFileIOTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudFileIOTests-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
        try super.tearDownWithError()
    }

    func testWriteThenReadReturnsSameBytes() throws {
        let payload = Data(#"{"version":1,"kind":"portable-backup"}"#.utf8)
        try CloudFileIO.write(payload, to: fileURL)
        let read = try CloudFileIO.read(from: fileURL)
        XCTAssertEqual(read, payload)
    }

    func testWrittenBytesHashMatchesContentHash() throws {
        let payload = Data("portable-backup-bytes".utf8)
        try CloudFileIO.write(payload, to: fileURL)
        let diskBytes = try Data(contentsOf: fileURL)
        let hash = CloudFileContentHash.sha256Hex(diskBytes)

        XCTAssertEqual(diskBytes, payload)
        XCTAssertEqual(hash, CloudFileContentHash.sha256Hex(payload))
        XCTAssertEqual(hash.count, 64)
        XCTAssertEqual(hash, hash.lowercased())
    }

    func testMissingFileReadThrows() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertThrowsError(try CloudFileIO.read(from: fileURL))
    }
}

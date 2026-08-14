import XCTest
@testable import GymTracker

final class StoreRecoveryTests: XCTestCase {
    private let fileManager = FileManager.default
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = fileManager.temporaryDirectory
            .appendingPathComponent("StoreRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? fileManager.removeItem(at: directory)
        }
        directory = nil
        try super.tearDownWithError()
    }

    func testBundleContainsEveryExistingStoreFileAndSidecar() throws {
        let storeURL = directory.appendingPathComponent("GymTracker.store")
        let storeFiles = GymTrackerPreMigrationBackup.storeFileURLs(for: storeURL)
        try Data("store".utf8).write(to: storeFiles[0])
        try Data("wal".utf8).write(to: storeFiles[1])

        let document = try GymTrackerStoreRecovery.makeBundleDocument(
            for: storeURL,
            fileManager: fileManager
        )

        let children = try XCTUnwrap(document.wrapper.fileWrappers)
        XCTAssertEqual(Set(children.keys), Set([storeFiles[0].lastPathComponent, storeFiles[1].lastPathComponent]))
        XCTAssertEqual(children[storeFiles[0].lastPathComponent]?.regularFileContents, Data("store".utf8))
        XCTAssertEqual(children[storeFiles[1].lastPathComponent]?.regularFileContents, Data("wal".utf8))
    }

    func testRemoveStoreDeletesOnlyStoreAndSidecars() throws {
        let storeURL = directory.appendingPathComponent("GymTracker.store")
        let storeFiles = GymTrackerPreMigrationBackup.storeFileURLs(for: storeURL)
        for (index, url) in storeFiles.enumerated() {
            try Data("file-\(index)".utf8).write(to: url)
        }
        let unrelatedURL = directory.appendingPathComponent("keep-me.txt")
        try Data("keep".utf8).write(to: unrelatedURL)

        try GymTrackerStoreRecovery.removeStore(at: storeURL, fileManager: fileManager)

        XCTAssertTrue(storeFiles.allSatisfy { !fileManager.fileExists(atPath: $0.path) })
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedURL.path))
    }

    func testBundleFailsWhenStoreDoesNotExist() {
        let storeURL = directory.appendingPathComponent("missing.store")

        XCTAssertThrowsError(
            try GymTrackerStoreRecovery.makeBundleDocument(for: storeURL, fileManager: fileManager)
        ) { error in
            XCTAssertEqual(error as? GymTrackerStoreRecovery.RecoveryError, .noStoreFiles)
        }
    }

    func testPreMigrationBackupIgnoresAnotherUnpublishedStagingCopy() throws {
        let storeURL = directory.appendingPathComponent("GymTracker.store")
        try Data("complete-store".utf8).write(to: storeURL)

        let finalDirectory = GymTrackerPreMigrationBackup.safetyDirectory(for: storeURL)
            .appendingPathComponent("PreMigration-unrecorded", isDirectory: true)
        let stagingDirectory = GymTrackerPreMigrationBackup.stagingDirectory(
            for: finalDirectory,
            identifier: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        )
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        try Data("partial".utf8).write(
            to: stagingDirectory.appendingPathComponent(storeURL.lastPathComponent)
        )

        let outcome = GymTrackerPreMigrationBackup.backUpIfSchemaVersionChanged(
            storeURL: storeURL,
            currentVersion: .init(3, 0, 0),
            fileManager: fileManager
        )

        XCTAssertEqual(outcome, .backedUp(fromVersion: "unrecorded", location: finalDirectory))
        XCTAssertTrue(fileManager.fileExists(atPath: stagingDirectory.path))
        XCTAssertEqual(
            try Data(contentsOf: finalDirectory.appendingPathComponent(storeURL.lastPathComponent)),
            Data("complete-store".utf8)
        )
        XCTAssertTrue(
            GymTrackerPreMigrationBackup.isCompleteBackup(
                finalDirectory,
                storeURL: storeURL,
                fileManager: fileManager
            )
        )
    }

    func testPreMigrationBackupReplacesIncompletePublishedDirectory() throws {
        let storeURL = directory.appendingPathComponent("GymTracker.store")
        try Data("complete-store".utf8).write(to: storeURL)
        let finalDirectory = GymTrackerPreMigrationBackup.safetyDirectory(for: storeURL)
            .appendingPathComponent("PreMigration-unrecorded", isDirectory: true)
        try fileManager.createDirectory(at: finalDirectory, withIntermediateDirectories: true)
        try Data("manifest-without-store".utf8).write(
            to: finalDirectory.appendingPathComponent(GymTrackerPreMigrationBackup.completionFileName)
        )

        let outcome = GymTrackerPreMigrationBackup.backUpIfSchemaVersionChanged(
            storeURL: storeURL,
            currentVersion: .init(3, 0, 0),
            fileManager: fileManager
        )

        XCTAssertEqual(outcome, .backedUp(fromVersion: "unrecorded", location: finalDirectory))
        XCTAssertEqual(
            try Data(contentsOf: finalDirectory.appendingPathComponent(storeURL.lastPathComponent)),
            Data("complete-store".utf8)
        )
    }
}

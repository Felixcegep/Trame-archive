import Foundation
import SwiftData

/// Copies the on-disk store aside before a container open that may migrate it.
/// A failed migration must never leave the user without a good copy of their
/// history.
///
/// Two properties decide whether this is worth anything, and the first
/// implementation got both wrong:
///
/// 1. **It must copy the store SwiftData actually opens.** The store URL is
///    derived by `ModelConfiguration` from the configuration name and group
///    container, so it is read from `configuration.url` here rather than
///    assumed to be a hardcoded filename in a guessed directory. A hardcoded
///    path that does not match silently finds nothing and backs up nothing.
///
/// 2. **A backup must never be overwritten by a later launch.** Copying on
///    every launch destroys the thing it protects: launch one saves the good
///    store, the migration then corrupts it, and launch two copies the broken
///    store over the last good one. Backups are therefore keyed by the schema
///    version they were taken from and written exactly once per version, and
///    the recorded version only advances after an open actually succeeds.
public enum GymTrackerPreMigrationBackup {
    public enum Outcome: Equatable, Sendable {
        /// No store exists yet, so there is nothing to lose.
        case noStoreToProtect
        /// The store was last opened successfully by this same schema version.
        case alreadyOnCurrentVersion
        case backedUp(fromVersion: String, location: URL)
        /// A pending migration was already captured on an earlier launch. The
        /// earlier copy is kept, because the live store may since have been
        /// damaged by the migration this is protecting against.
        case existingBackupPreserved(fromVersion: String, location: URL)
        case failed(String)

        /// A short phrase for the store-unavailable recovery message.
        public var recoveryDescription: String? {
            switch self {
            case .backedUp(_, let location), .existingBackupPreserved(_, let location):
                return "A copy of your data from before this update is at: \(location.path)"
            case .failed(let message):
                return "No pre-migration copy could be made: \(message)"
            case .noStoreToProtect, .alreadyOnCurrentVersion:
                return nil
            }
        }
    }

    static let safetyDirectoryName = "GymTrackerMigrationSafety"
    static let markerFileName = "OpenedSchemaVersion.txt"

    static func versionString(_ version: Schema.Version) -> String {
        "\(version.major).\(version.minor).\(version.patch)"
    }

    /// The store file plus the SQLite sidecars. A `.store` copied without its
    /// write-ahead log can be missing the most recent committed transactions.
    static func storeFileURLs(for storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        return [name, "\(name)-wal", "\(name)-shm"].map {
            directory.appendingPathComponent($0)
        }
    }

    static func safetyDirectory(for storeURL: URL) -> URL {
        storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(safetyDirectoryName, isDirectory: true)
    }

    static func markerURL(for storeURL: URL) -> URL {
        safetyDirectory(for: storeURL).appendingPathComponent(markerFileName)
    }

    /// Copies the store aside if the last successful open was on a different
    /// schema version than the one about to be used.
    @discardableResult
    public static func backUpIfSchemaVersionChanged(
        storeURL: URL,
        currentVersion: Schema.Version,
        fileManager: FileManager = .default
    ) -> Outcome {
        let current = versionString(currentVersion)

        guard fileManager.fileExists(atPath: storeURL.path) else {
            // A fresh install has nothing to protect. Record the version now so
            // that the *next* schema change is seen as a real migration rather
            // than as an unrecorded one.
            recordSuccessfulOpen(storeURL: storeURL, version: currentVersion, fileManager: fileManager)
            return .noStoreToProtect
        }

        let recorded = readRecordedVersion(storeURL: storeURL, fileManager: fileManager)
        guard recorded != current else { return .alreadyOnCurrentVersion }

        // A store that predates this mechanism has no marker. It still needs
        // protecting — it is exactly the store most likely to be migrated.
        let sourceVersion = recorded ?? "unrecorded"
        let backupDirectory = safetyDirectory(for: storeURL)
            .appendingPathComponent("PreMigration-\(sourceVersion)", isDirectory: true)

        if fileManager.fileExists(atPath: backupDirectory.path) {
            return .existingBackupPreserved(fromVersion: sourceVersion, location: backupDirectory)
        }

        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            for url in storeFileURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
                try fileManager.copyItem(
                    at: url,
                    to: backupDirectory.appendingPathComponent(url.lastPathComponent)
                )
            }
            return .backedUp(fromVersion: sourceVersion, location: backupDirectory)
        } catch {
            // Remove a half-written directory. Leaving it would make the
            // existence check above treat a partial copy as a real backup and
            // suppress every future attempt.
            try? fileManager.removeItem(at: backupDirectory)
            return .failed(error.localizedDescription)
        }
    }

    /// Records the schema version that just opened the store successfully.
    ///
    /// Call this **only** after `ModelContainer` initialization returns. If an
    /// open throws, the marker must stay on the previous version so the next
    /// launch still recognizes the migration as pending and preserves the
    /// backup it already took.
    public static func recordSuccessfulOpen(
        storeURL: URL,
        version: Schema.Version,
        fileManager: FileManager = .default
    ) {
        let directory = safetyDirectory(for: storeURL)
        do {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try versionString(version).write(
                to: markerURL(for: storeURL),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            // A missing marker is safe: the next launch reads it as
            // "unrecorded" and takes a backup it may not have needed.
            print("Could not record opened schema version: \(error)")
        }
    }

    static func readRecordedVersion(
        storeURL: URL,
        fileManager: FileManager = .default
    ) -> String? {
        let url = markerURL(for: storeURL)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let contents = try? String(contentsOf: url, encoding: .utf8)
        let trimmed = contents?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}

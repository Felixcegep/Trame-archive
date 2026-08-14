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
    static let completionFileName = "BackupComplete.txt"

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

    static func stagingDirectory(for backupDirectory: URL, identifier: UUID = UUID()) -> URL {
        backupDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(
                ".\(backupDirectory.lastPathComponent).partial-\(identifier.uuidString)",
                isDirectory: true
            )
    }

    /// A legacy backup predating the completion marker is preserved when its
    /// indispensable main store exists. New backups also carry a manifest;
    /// every named file must still be present before the directory can suppress
    /// another migration copy.
    static func isCompleteBackup(
        _ backupDirectory: URL,
        storeURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let copiedStore = backupDirectory.appendingPathComponent(storeURL.lastPathComponent)
        guard fileManager.fileExists(atPath: copiedStore.path) else { return false }
        let completionURL = backupDirectory.appendingPathComponent(completionFileName)
        guard let data = fileManager.contents(atPath: completionURL.path),
              let manifest = String(data: data, encoding: .utf8) else {
            return true
        }
        let names = manifest.split(whereSeparator: \.isNewline).map(String.init)
        return names.isEmpty == false && names.allSatisfy {
            fileManager.fileExists(atPath: backupDirectory.appendingPathComponent($0).path)
        }
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

        // A fresh install has nothing to lose. The marker is deliberately not
        // written here: only a successful open may record a version, and the
        // open that creates this store has not happened yet.
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return .noStoreToProtect
        }

        let recorded = readRecordedVersion(storeURL: storeURL, fileManager: fileManager)
        guard recorded != current else { return .alreadyOnCurrentVersion }

        // A store that predates this mechanism has no marker. It still needs
        // protecting — it is exactly the store most likely to be migrated.
        let sourceVersion = recorded ?? "unrecorded"
        let backupDirectory = safetyDirectory(for: storeURL)
            .appendingPathComponent("PreMigration-\(sourceVersion)", isDirectory: true)

        if isCompleteBackup(backupDirectory, storeURL: storeURL, fileManager: fileManager) {
            return .existingBackupPreserved(fromVersion: sourceVersion, location: backupDirectory)
        }

        // An empty/partial destination from an older implementation must not
        // suppress protection forever. It contains no usable main store, so
        // replacing it cannot discard a recoverable backup.
        if fileManager.fileExists(atPath: backupDirectory.path) {
            do {
                try fileManager.removeItem(at: backupDirectory)
            } catch {
                // Another process may have removed the same invalid directory
                // after our existence check. Continue only when it is truly
                // gone; any remaining path is still an actionable failure.
                if fileManager.fileExists(atPath: backupDirectory.path) {
                    return .failed(error.localizedDescription)
                }
            }
        }

        // Publish a backup directory only after every existing SQLite file is
        // copied. A process kill during copy can leave the staging directory,
        // but never a destination that a later launch mistakes for complete.
        // App and extension processes may start concurrently. Each writer owns
        // a unique unpublished directory; neither removes another's in-flight
        // copy.
        let stagingDirectory = stagingDirectory(for: backupDirectory)

        do {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            var copiedFileNames: [String] = []
            for url in storeFileURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
                try fileManager.copyItem(
                    at: url,
                    to: stagingDirectory.appendingPathComponent(url.lastPathComponent)
                )
                copiedFileNames.append(url.lastPathComponent)
            }
            guard copiedFileNames.contains(storeURL.lastPathComponent) else {
                throw CocoaError(.fileNoSuchFile)
            }
            try Data(copiedFileNames.sorted().joined(separator: "\n").utf8).write(
                to: stagingDirectory.appendingPathComponent(completionFileName),
                options: .atomic
            )
            try fileManager.moveItem(at: stagingDirectory, to: backupDirectory)
            // Only now that a newer copy exists on disk is it safe to drop the
            // older generations. Pruning before the copy — or on every launch —
            // would reintroduce the failure this whole type guards against.
            pruneBackups(keeping: backupDirectory, in: safetyDirectory(for: storeURL), fileManager: fileManager)
            return .backedUp(fromVersion: sourceVersion, location: backupDirectory)
        } catch {
            // A failed or interrupted staging copy is disposable. Never
            // remove the published destination here: if another invocation
            // completed it first, that is the copy this migration needs.
            try? fileManager.removeItem(at: stagingDirectory)
            if isCompleteBackup(backupDirectory, storeURL: storeURL, fileManager: fileManager) {
                return .existingBackupPreserved(fromVersion: sourceVersion, location: backupDirectory)
            }
            return .failed(error.localizedDescription)
        }
    }

    /// Keeps exactly one pre-migration backup: the one just written.
    ///
    /// Each backup is a full copy of the store, so retaining one per schema
    /// generation would leave a permanent duplicate of the user's entire
    /// history behind after every upgrade, with no way to reclaim the space.
    /// Older generations are also the less useful ones — the store has since
    /// been migrated and used — so the most recent copy is the only one worth
    /// keeping.
    static func pruneBackups(
        keeping survivor: URL,
        in safetyDirectory: URL,
        fileManager: FileManager = .default
    ) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for entry in entries
        where entry.lastPathComponent.hasPrefix("PreMigration-")
            && entry.lastPathComponent != survivor.lastPathComponent {
            do {
                try fileManager.removeItem(at: entry)
            } catch {
                // A backup that cannot be removed is a space problem, never a
                // correctness one. The surviving copy is already written.
                print("Could not prune old pre-migration backup at \(entry.path): \(error)")
            }
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

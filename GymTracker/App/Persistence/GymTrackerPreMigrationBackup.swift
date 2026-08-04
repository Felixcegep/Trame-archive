import Foundation

/// Copies the on-disk store aside before a container open that may migrate it.
/// A failed migration must never be the only copy of a user's history.
/// Returns the backup directory URL, or nil if there was no store to copy.
public enum GymTrackerPreMigrationBackup {
    @discardableResult
    public static func createPreMigrationBackupIfNeeded() -> URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let storeFiles = ["default.store", "default.store-wal", "default.store-shm"]
        let existingStoreFiles = storeFiles.filter { fileManager.fileExists(atPath: appSupportURL.appendingPathComponent($0).path) }

        guard !existingStoreFiles.isEmpty else {
            return nil
        }

        let backupDirURL = appSupportURL.appendingPathComponent("PreMigrationBackup", isDirectory: true)

        do {
            if fileManager.fileExists(atPath: backupDirURL.path) {
                try fileManager.removeItem(at: backupDirURL)
            }
            try fileManager.createDirectory(at: backupDirURL, withIntermediateDirectories: true)

            for file in existingStoreFiles {
                let sourceURL = appSupportURL.appendingPathComponent(file)
                let destinationURL = backupDirURL.appendingPathComponent(file)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }

            print("Pre-migration store backup created at: \(backupDirURL.path)")
            return backupDirURL
        } catch {
            print("Failed to create pre-migration store backup: \(error)")
            return nil
        }
    }
}

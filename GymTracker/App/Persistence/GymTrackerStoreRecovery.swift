import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Handles the narrow recovery path that is available when SwiftData cannot
/// open the store. This intentionally works on files rather than a
/// `ModelContext`: a context is the thing that failed to become available.
enum GymTrackerStoreRecovery {
    enum RecoveryError: LocalizedError, Equatable {
        case noStoreFiles
        case unreadableStoreFile(String)
        case removalFailed(String)

        var errorDescription: String? {
            switch self {
            case .noStoreFiles:
                return String(localized: "storage.recovery.noStoreFiles", defaultValue: "No local store files were found to export.")
            case .unreadableStoreFile(let path):
                return String(localized: "storage.recovery.unreadableStoreFile", defaultValue: "The local store file could not be read: \(path)")
            case .removalFailed(let message):
                return String(localized: "storage.recovery.removalFailed", defaultValue: "The local store could not be removed: \(message)")
            }
        }
    }

    /// Creates a directory `FileDocument` containing every existing file in
    /// the SwiftData store bundle. `storeFileURLs(for:)` is the single owner
    /// of the SQLite sidecar naming convention.
    static func makeBundleDocument(
        for storeURL: URL,
        fileManager: FileManager = .default
    ) throws -> StoreRecoveryBundleDocument {
        let urls = GymTrackerPreMigrationBackup.storeFileURLs(for: storeURL)
            .filter { fileManager.fileExists(atPath: $0.path) }

        guard !urls.isEmpty else { throw RecoveryError.noStoreFiles }

        var files: [String: Data] = [:]
        for url in urls {
            do {
                files[url.lastPathComponent] = try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                throw RecoveryError.unreadableStoreFile(url.path)
            }
        }

        return StoreRecoveryBundleDocument(files: files)
    }

    /// Removes only the persistent store and its SQLite sidecars. Safety
    /// backups and unrelated files in the store directory are deliberately
    /// left untouched so a later restore or support investigation remains
    /// possible.
    static func removeStore(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let urls = GymTrackerPreMigrationBackup.storeFileURLs(for: storeURL)
        let existingURLs = urls.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existingURLs.isEmpty else { throw RecoveryError.noStoreFiles }

        do {
            for url in existingURLs {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw RecoveryError.removalFailed(error.localizedDescription)
        }
    }
}

/// A file-exportable directory package for a failed SwiftData store.
///
/// The package is intentionally not the portable JSON backup. JSON requires
/// SwiftData to fetch the graph, while this document remains available when
/// the graph cannot be opened at all.
struct StoreRecoveryBundleDocument: FileDocument {
    static let contentType = UTType(exportedAs: "com.trame.store-recovery-bundle", conformingTo: .package)
    static var readableContentTypes: [UTType] { [contentType] }
    static var writableContentTypes: [UTType] { [contentType] }

    static let empty = StoreRecoveryBundleDocument(files: [:])

    /// `FileDocument` is `Sendable`, while Foundation's reference-type
    /// `FileWrapper` is not. Keep the document's durable state as immutable,
    /// sendable bytes and materialize wrappers only at the API boundary.
    let files: [String: Data]

    var wrapper: FileWrapper {
        FileWrapper(
            directoryWithFileWrappers: files.mapValues(FileWrapper.init(regularFileWithContents:))
        )
    }

    init(files: [String: Data]) {
        self.files = files
    }

    init(configuration: ReadConfiguration) throws {
        self.files = (configuration.file.fileWrappers ?? [:]).compactMapValues(\.regularFileContents)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        wrapper
    }
}

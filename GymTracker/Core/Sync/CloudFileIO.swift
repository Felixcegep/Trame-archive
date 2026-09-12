import Foundation

/// Coordinated read/write of the linked portable-backup file. iCloud Drive and
/// Google Drive File Providers both require `NSFileCoordinator`; uncoordinated
/// writes corrupt the provider's copy.
nonisolated enum CloudFileIO {
    enum AccessError: LocalizedError, Equatable {
        case coordinationFailed(String)
        case emptyFile
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .coordinationFailed(let message):
                String(localized: "The cloud file could not be read. \(message)")
            case .emptyFile:
                String(localized: "The cloud file is empty.")
            case .writeFailed(let message):
                String(localized: "The cloud file could not be saved. \(message)")
            }
        }
    }

    static func read(from url: URL) throws -> Data {
        try withSecurityScope(url) { scoped in
            var coordinatorError: NSError?
            var readData: Data?
            var readError: Error?
            NSFileCoordinator().coordinate(
                readingItemAt: scoped,
                options: [],
                error: &coordinatorError
            ) { coordinatedURL in
                do {
                    readData = try Data(contentsOf: coordinatedURL)
                } catch {
                    readError = error
                }
            }
            if let coordinatorError {
                throw AccessError.coordinationFailed(coordinatorError.localizedDescription)
            }
            if let readError {
                throw AccessError.coordinationFailed(readError.localizedDescription)
            }
            guard let readData else {
                throw AccessError.emptyFile
            }
            return readData
        }
    }

    static func write(_ data: Data, to url: URL) throws {
        try withSecurityScope(url) { scoped in
            var coordinatorError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(
                writingItemAt: scoped,
                options: .forReplacing,
                error: &coordinatorError
            ) { coordinatedURL in
                do {
                    try data.write(to: coordinatedURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }
            if let coordinatorError {
                throw AccessError.writeFailed(coordinatorError.localizedDescription)
            }
            if let writeError {
                throw AccessError.writeFailed(writeError.localizedDescription)
            }
        }
    }

    static func fileExists(_ url: URL) -> Bool {
        (try? withSecurityScope(url) { FileManager.default.fileExists(atPath: $0.path) }) ?? false
    }

    static func contentModificationDate(of url: URL) -> Date? {
        try? withSecurityScope(url) { scoped in
            let values = try scoped.resourceValues(forKeys: [.contentModificationDateKey])
            return values.contentModificationDate
        }
    }

    /// `startAccessingSecurityScopedResource` returns false for ordinary temp
    /// URLs used in tests; those still proceed.
    static func withSecurityScope<T>(_ url: URL, _ body: (URL) throws -> T) throws -> T {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body(url)
    }
}

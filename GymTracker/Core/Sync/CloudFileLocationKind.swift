import Foundation

/// Where the linked portable-backup file lives, classified from the file URL
/// the system Files picker returned. Used for status copy only; every provider
/// is the same bookmark + file-coordination path.
nonisolated enum CloudFileLocationKind: String, Codable, Equatable, Sendable {
    case iCloudDrive
    case googleDrive
    case otherFiles

    var title: String {
        switch self {
        case .iCloudDrive: String(localized: "iCloud Drive")
        case .googleDrive: String(localized: "Google Drive")
        case .otherFiles: String(localized: "Files")
        }
    }

    /// Path-based classification so tests do not need a live File Provider.
    static func classify(path: String) -> CloudFileLocationKind {
        let lower = path.lowercased()
        if lower.contains("/mobile documents/")
            || lower.contains("com~apple~clouddocs")
            || lower.contains("mobile documents/com~apple~cloud")
            || lower.contains("/library/mobile documents/") {
            return .iCloudDrive
        }
        if lower.contains("googledrive")
            || lower.contains("com.google.drive")
            || lower.contains("com~google~drive")
            || lower.contains("/google drive/") {
            return .googleDrive
        }
        return .otherFiles
    }

    static func classify(url: URL) -> CloudFileLocationKind {
        classify(path: url.path)
    }
}

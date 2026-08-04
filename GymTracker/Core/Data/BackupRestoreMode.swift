import Foundation

/// Explicit mode for restoring a portable backup artifact when sync is enabled.
public enum BackupRestoreMode: String, Codable, Sendable {
    /// Replaces current local and synchronized account graph with the backup contents.
    case replaceCurrentAccountData

    /// Imports template and plan definitions as non-duplicate copies with fresh UUIDs.
    case importAsCopy

    /// Emergency local recovery before starting or completing sync bootstrap.
    case localRecoveryBeforeSyncBootstrap
}

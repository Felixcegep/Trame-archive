import Foundation

/// Three-way compare between this iPhone's portable backup, the linked cloud
/// file, and the last snapshot this installation successfully pushed or pulled.
///
/// KeePass-style: one file is the shared copy. Local SwiftData stays the
/// working store. This decision never mutates either side.
nonisolated enum CloudFileReconcileDecision: Equatable, Sendable {
    /// Local bytes match the linked file. Nothing to write.
    case inSync
    /// This iPhone changed; the linked file still matches the last sync.
    case push
    /// The linked file changed; this iPhone still matches the last sync.
    case pull
    /// Both sides changed since the last successful sync, or an existing file
    /// is being linked against different local data.
    case conflict
}

nonisolated enum CloudFileReconciler {
    /// `remoteHash` is `nil` when the linked file is missing (first create, or
    /// the provider has not materialized it yet). A missing file is a push, not
    /// a conflict: this iPhone still holds the working copy.
    static func decide(
        localHash: String,
        remoteHash: String?,
        lastSyncedHash: String?
    ) -> CloudFileReconcileDecision {
        guard let remoteHash, remoteHash.isEmpty == false else {
            return .push
        }
        if localHash == remoteHash {
            return .inSync
        }
        if let lastSyncedHash, lastSyncedHash.isEmpty == false {
            if remoteHash == lastSyncedHash {
                return .push
            }
            if localHash == lastSyncedHash {
                return .pull
            }
        }
        return .conflict
    }
}

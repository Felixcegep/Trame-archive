import Foundation

/// Defines the iCloud / CloudKit synchronization environment.
///
/// Synchronization is disabled by default in production and TestFlight builds
/// until all schema and outbox compatibility gates are proven.
public enum CloudSyncEnvironment: String, Codable, Sendable {
    case disabled
    case development
    case production
}

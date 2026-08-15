import Foundation
import SwiftData

/// Configures and builds GymTracker's `ModelContainer` instance based on explicit environment settings.
public struct GymTrackerPersistenceConfiguration: Sendable {
    public let cloudEnvironment: CloudSyncEnvironment
    public let cloudContainerIdentifier: String?
    public let isInMemory: Bool

    public init(
        cloudEnvironment: CloudSyncEnvironment = .disabled,
        cloudContainerIdentifier: String? = nil,
        isInMemory: Bool = false
    ) {
        self.cloudEnvironment = cloudEnvironment
        self.cloudContainerIdentifier = cloudContainerIdentifier
        self.isInMemory = isInMemory
    }

    public static let schema = Schema(versionedSchema: GymTrackerCatalogMetadataSchema.self)

    private var cloudKitDatabaseSetting: ModelConfiguration.CloudKitDatabase {
        switch cloudEnvironment {
        case .disabled:
            return .none
        case .development, .production:
            if let identifier = cloudContainerIdentifier, !identifier.isEmpty {
                return .private(identifier)
            } else {
                return .none
            }
        }
    }

    /// The single `ModelConfiguration` the app opens.
    ///
    /// **The store location is deliberately left for SwiftData to derive.** Two
    /// of this initializer's inputs feed that derived URL: the configuration
    /// *name* and `groupContainer`. Every build that has shipped opened its
    /// store through an unnamed configuration with `groupContainer: .automatic`,
    /// because no `ModelConfiguration` was passed at all and those are the
    /// defaults. Naming the configuration or forcing `groupContainer: .none`
    /// silently points the app at a different file on disk, so a user's entire
    /// history appears to vanish on first launch with no error anywhere.
    ///
    /// Do not name this configuration and do not change `groupContainer`
    /// without a migration step that physically moves the existing store. The
    /// two-store split described in `Documentation/Sync/TargetArchitecture.md`
    /// must introduce its *second* store with an explicit `url:`, leaving this
    /// one exactly where it already is.
    ///
    /// `cloudKitDatabase` does not participate in URL derivation, so setting it
    /// explicitly is safe.
    public func makeModelConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: isInMemory,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: cloudKitDatabaseSetting
        )
    }

    /// Creates a fully initialized `ModelContainer` for GymTracker.
    ///
    /// Callers that need the store URL before the open — to copy the store
    /// aside, for instance — should build the configuration with
    /// `makeModelConfiguration()`, read its `url`, and pass it back in here so
    /// exactly one configuration is used for both.
    @MainActor
    public func makeContainer(using configuration: ModelConfiguration? = nil) throws -> ModelContainer {
        try ModelContainer(
            for: Self.schema,
            migrationPlan: GymTrackerSchemaMigrationPlan.self,
            configurations: [configuration ?? makeModelConfiguration()]
        )
    }
}

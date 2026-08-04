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

    /// Creates a fully initialized `ModelContainer` for GymTracker.
    @MainActor
    public func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: GymTrackerCloudCompatibleSchemaV3.self)

        let cloudKitDatabaseSetting: ModelConfiguration.CloudKitDatabase = {
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
        }()

        let mainConfiguration = ModelConfiguration(
            "GymTrackerCloudUserData",
            schema: schema,
            isStoredInMemoryOnly: isInMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: cloudKitDatabaseSetting
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: GymTrackerSchemaMigrationPlan.self,
            configurations: [mainConfiguration]
        )
    }
}

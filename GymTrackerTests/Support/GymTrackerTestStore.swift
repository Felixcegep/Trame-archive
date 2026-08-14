import Foundation
import SwiftData
@testable import GymTracker

/// Builds isolated stores with the full GymTracker schema for persistence
/// tests. Each call returns a new container so test data cannot leak between
/// cases.
@MainActor
enum GymTrackerTestStore {
    /// Schema metadata is immutable for the duration of a test process. Keep
    /// one copy so every isolated container pays only the container-open cost;
    /// sharing a container itself would allow SwiftData state to leak between
    /// tests and is intentionally not supported.
    private static let schema = GymTrackerPersistenceConfiguration.schema

    static func makeInMemoryContext() throws -> ModelContext {
        ModelContext(try makeInMemoryContainer())
    }

    /// A second `ModelContext(container)` call against the returned container
    /// simulates an App Intent or Live Activity executing against the same
    /// persistent store the app-side UI observes, without a disk-backed
    /// fixture — the two contexts see each other's committed saves the same
    /// way two real in-process contexts on `GymTrackerModelContainer.shared`
    /// would.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(configuration: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    static func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        try body(ModelContext(try makeContainer(configuration: ModelConfiguration(url: url))))
    }

    private static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [configuration])
    }
}

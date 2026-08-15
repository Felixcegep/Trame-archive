import Foundation

/// Descriptive provenance for a reusable catalogue definition.
///
/// A source reference is catalogue metadata only. It is deliberately kept
/// separate from performed-workout evidence so a later catalogue refresh
/// cannot change the meaning of historical records.
nonisolated struct CatalogSourceReference: Codable, Hashable, Sendable {
    var sourceID: String
    var label: String?
    var url: String?
    var retrievedAt: Date?
    var contentVersion: String?

    init(
        sourceID: String,
        label: String? = nil,
        url: String? = nil,
        retrievedAt: Date? = nil,
        contentVersion: String? = nil
    ) {
        self.sourceID = sourceID
        self.label = label
        self.url = url
        self.retrievedAt = retrievedAt
        self.contentVersion = contentVersion
    }
}

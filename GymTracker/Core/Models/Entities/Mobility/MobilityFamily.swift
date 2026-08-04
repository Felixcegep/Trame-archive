import Foundation
import SwiftData

@Model
final class MobilityFamily {
    var id: UUID
    var name: String
    var catalogueKey: String? = nil
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .nullify, inverse: \MobilityDefinition.family)
    var definitions: [MobilityDefinition] = []

    init(name: String, id: UUID = UUID(), createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

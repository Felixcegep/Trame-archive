import Foundation
import SwiftData

/// Performed-history sidecar to `MobilityEntry`, matching the ownership-key
/// pattern of `MobilityResultEvidence`. Block identity, kind, round position
/// and side strategy are copied here when a session starts so that later
/// routine edits (renaming a block, changing its kind, deleting it) cannot
/// rewrite what a completed session actually executed.
@Model
final class MobilityEntryEvidence {
    var id: UUID
    @Attribute(.unique) var entryID: UUID
    var blockKeySnapshot: String?
    var blockKindSnapshotRaw: String?
    var blockNameSnapshot: String?
    var blockOrderIndexSnapshot: Int?
    var blockTargetRoundsSnapshot: Int?
    var blockRestSnapshotData: Data?
    /// Which pre-materialized repetition of a round-based block this entry
    /// represents. Always `0` outside a round-based block.
    var roundIndexSnapshot: Int
    var sideStrategySnapshotRaw: String?
    var restPrescriptionSnapshotData: Data?
    var createdAt: Date

    var blockKindSnapshot: MobilityBlockKind? {
        blockKindSnapshotRaw.flatMap(MobilityBlockKind.init(rawValue:))
    }

    var blockRestSnapshot: MobilityRestPrescription? {
        Self.decode(MobilityRestPrescription.self, from: blockRestSnapshotData)
    }

    var sideStrategySnapshot: MobilitySideStrategy? {
        sideStrategySnapshotRaw.flatMap(MobilitySideStrategy.init(rawValue:))
    }

    var restPrescriptionSnapshot: MobilityRestPrescription? {
        Self.decode(MobilityRestPrescription.self, from: restPrescriptionSnapshotData)
    }

    init(
        entryID: UUID,
        blockKeySnapshot: String? = nil,
        blockKindSnapshot: MobilityBlockKind? = nil,
        blockNameSnapshot: String? = nil,
        blockOrderIndexSnapshot: Int? = nil,
        blockTargetRoundsSnapshot: Int? = nil,
        blockRestSnapshot: MobilityRestPrescription? = nil,
        roundIndexSnapshot: Int = 0,
        sideStrategySnapshot: MobilitySideStrategy? = nil,
        restPrescriptionSnapshot: MobilityRestPrescription? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.entryID = entryID
        self.blockKeySnapshot = blockKeySnapshot
        self.blockKindSnapshotRaw = blockKindSnapshot?.rawValue
        self.blockNameSnapshot = blockNameSnapshot
        self.blockOrderIndexSnapshot = blockOrderIndexSnapshot
        self.blockTargetRoundsSnapshot = blockTargetRoundsSnapshot
        self.blockRestSnapshotData = Self.encode(blockRestSnapshot)
        self.roundIndexSnapshot = roundIndexSnapshot
        self.sideStrategySnapshotRaw = sideStrategySnapshot?.rawValue
        self.restPrescriptionSnapshotData = Self.encode(restPrescriptionSnapshot)
        self.createdAt = createdAt
    }

    private static func encode<Value: Encodable>(_ value: Value?) -> Data? {
        value.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

import Foundation
import SwiftData

/// A named container that groups routine items one level deep. `routineID`
/// is an ownership key, not a live relationship, matching the sidecar
/// convention used by `MobilityRoutineItemEvidence`: a block never holds a
/// direct SwiftData relationship into the frozen `MobilityRoutine`/
/// `MobilityRoutineItem` baseline models. There is deliberately no field on
/// this model that could reference another block, so a block can never
/// contain a block; membership is expressed the other way, by
/// `MobilityRoutineItemEvidence.blockKey` pointing at `blockKey` here.
@Model
final class MobilityRoutineBlock {
    var id: UUID
    @Attribute(.unique) var blockKey: String
    var routineID: UUID
    var orderIndex: Int
    var name: String?
    var kindRaw: String
    var targetRounds: Int?
    var restPrescriptionData: Data?
    var createdAt: Date
    var updatedAt: Date

    var kind: MobilityBlockKind {
        get { MobilityBlockKind(rawValue: kindRaw) ?? .straightSequence }
        set { kindRaw = newValue.rawValue }
    }

    var restPrescription: MobilityRestPrescription? {
        get { Self.decode(MobilityRestPrescription.self, from: restPrescriptionData) }
        set { restPrescriptionData = Self.encode(newValue) }
    }

    init(
        blockKey: String,
        routineID: UUID,
        orderIndex: Int,
        name: String? = nil,
        kind: MobilityBlockKind,
        targetRounds: Int? = nil,
        restPrescription: MobilityRestPrescription? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.blockKey = blockKey
        self.routineID = routineID
        self.orderIndex = orderIndex
        self.name = name
        self.kindRaw = kind.rawValue
        self.targetRounds = targetRounds
        self.restPrescriptionData = Self.encode(restPrescription)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func encode<Value: Encodable>(_ value: Value?) -> Data? {
        value.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

import Foundation
import SwiftData

@Model
final class MobilityRoutineItem {
    var id: UUID
    var orderIndex: Int
    var targetDurationSeconds: Int?
    var targetRepetitions: Int?
    var targetLoadValue: Double?
    var targetLoadUnitRaw: String?
    var cycleCount: Int = 1
    var sideRaw: String
    var restSeconds: Int?
    var notes: String?
    var definition: MobilityDefinition
    var routine: MobilityRoutine?
    @Relationship(deleteRule: .cascade, inverse: \MobilityPhasePrescription.routineItem)
    var phases: [MobilityPhasePrescription] = []

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    var targetLoadUnit: MobilityLoadUnit? {
        get { targetLoadUnitRaw.flatMap(MobilityLoadUnit.init(rawValue:)) }
        set { targetLoadUnitRaw = newValue?.rawValue }
    }

    init(
        definition: MobilityDefinition,
        orderIndex: Int,
        targetDurationSeconds: Int? = nil,
        targetRepetitions: Int? = nil,
        targetLoadValue: Double? = nil,
        targetLoadUnit: MobilityLoadUnit? = nil,
        side: MobilitySide = .none,
        restSeconds: Int? = nil,
        notes: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.definition = definition
        self.orderIndex = orderIndex
        self.targetDurationSeconds = targetDurationSeconds
        self.targetRepetitions = targetRepetitions
        self.targetLoadValue = targetLoadValue
        self.targetLoadUnitRaw = targetLoadUnit?.rawValue
        self.sideRaw = side.rawValue
        self.restSeconds = restSeconds
        self.notes = notes
    }
}

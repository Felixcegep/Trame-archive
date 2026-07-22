import Foundation
import SwiftData

@Model
final class MobilityEntry {
    var id: UUID
    var orderIndex: Int
    var definitionIDSnapshot: UUID
    var definitionNameSnapshot: String
    var instructionsSnapshot: String?
    var trackingTypeRaw: String
    var targetDurationSeconds: Int?
    var targetRepetitions: Int?
    var prescribedLoadValue: Double?
    var prescribedLoadUnitRaw: String?
    var cycleCount: Int = 1
    var currentCycleIndex: Int = 0
    var currentPhaseIndex: Int = 0
    var sideRaw: String
    var restSeconds: Int?
    var notesSnapshot: String?
    var timerStartedAt: Date?
    var pausedElapsedSeconds: Int = 0
    var session: MobilitySession?
    @Relationship(deleteRule: .cascade, inverse: \MobilityResult.entry)
    var results: [MobilityResult] = []
    @Relationship(deleteRule: .cascade, inverse: \MobilityPhaseResult.entry)
    var phaseResults: [MobilityPhaseResult] = []

    var trackingType: MobilityTrackingType {
        get { MobilityTrackingType(rawValue: trackingTypeRaw) ?? .duration }
        set { trackingTypeRaw = newValue.rawValue }
    }

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    var prescribedLoadUnit: MobilityLoadUnit? {
        get { prescribedLoadUnitRaw.flatMap(MobilityLoadUnit.init(rawValue:)) }
        set { prescribedLoadUnitRaw = newValue?.rawValue }
    }

    init(
        routineItem: MobilityRoutineItem,
        orderIndex: Int,
        id: UUID = UUID()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.definitionIDSnapshot = routineItem.definition.id
        self.definitionNameSnapshot = routineItem.definition.name
        self.instructionsSnapshot = routineItem.definition.instructions
        self.trackingTypeRaw = routineItem.definition.trackingType.rawValue
        self.targetDurationSeconds = routineItem.targetDurationSeconds ?? routineItem.definition.defaultDurationSeconds
        self.targetRepetitions = routineItem.targetRepetitions ?? routineItem.definition.defaultRepetitions
        self.prescribedLoadValue = routineItem.targetLoadValue
        self.prescribedLoadUnitRaw = routineItem.targetLoadUnitRaw
        self.sideRaw = routineItem.side.rawValue
        self.restSeconds = routineItem.restSeconds
        self.notesSnapshot = routineItem.notes
        self.timerStartedAt = nil
    }

    init(
        definitionIDSnapshot: UUID,
        definitionNameSnapshot: String,
        instructionsSnapshot: String?,
        trackingType: MobilityTrackingType,
        targetDurationSeconds: Int?,
        targetRepetitions: Int?,
        prescribedLoadValue: Double? = nil,
        prescribedLoadUnit: MobilityLoadUnit? = nil,
        side: MobilitySide,
        restSeconds: Int?,
        notesSnapshot: String?,
        timerStartedAt: Date?,
        orderIndex: Int,
        id: UUID
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.definitionIDSnapshot = definitionIDSnapshot
        self.definitionNameSnapshot = definitionNameSnapshot
        self.instructionsSnapshot = instructionsSnapshot
        self.trackingTypeRaw = trackingType.rawValue
        self.targetDurationSeconds = targetDurationSeconds
        self.targetRepetitions = targetRepetitions
        self.prescribedLoadValue = prescribedLoadValue
        self.prescribedLoadUnitRaw = prescribedLoadUnit?.rawValue
        self.sideRaw = side.rawValue
        self.restSeconds = restSeconds
        self.notesSnapshot = notesSnapshot
        self.timerStartedAt = timerStartedAt
    }

    var orderedResults: [MobilityResult] {
        results.sorted { $0.sideRaw < $1.sideRaw }
    }
}

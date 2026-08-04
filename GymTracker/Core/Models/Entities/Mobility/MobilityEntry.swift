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
        self.cycleCount = routineItem.cycleCount
        self.currentCycleIndex = 0
        self.currentPhaseIndex = 0
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

    /// Side-major, then cycle, then authored phase order. This is both the
    /// default immutable snapshot order and the execution order consumed by
    /// `MobilityFlowResolver` for every item that does not alternate sides.
    var orderedPhaseResults: [MobilityPhaseResult] {
        executionOrderedPhaseResults(alternatingSides: false)
    }

    /// `alternatingSides: true` sorts cycle-major instead of side-major so a
    /// `.alternateEachRepetition` item visits the same repetition's left and
    /// right nodes together before advancing, matching
    /// `MobilityFlowResolver`'s traversal for `MobilityFlowSemantics
    /// .sideAlternating`. This is a query parameter, not stored state: side
    /// strategy itself lives in the `MobilityRoutineItemEvidence`/
    /// `MobilityEntryEvidence` sidecars, never as a new stored property on
    /// this frozen baseline model.
    func executionOrderedPhaseResults(alternatingSides: Bool) -> [MobilityPhaseResult] {
        phaseResults.sorted {
            let lhsSide = Self.sideOrder($0.side)
            let rhsSide = Self.sideOrder($1.side)
            if alternatingSides {
                if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
                if lhsSide != rhsSide { return lhsSide < rhsSide }
            } else {
                if lhsSide != rhsSide { return lhsSide < rhsSide }
                if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
            }
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var isPhaseDriven: Bool { phaseResults.isEmpty == false }

    /// Timer state is represented without another persisted flag. An active
    /// execution node with no start instant is paused; accumulated time lives
    /// in `pausedElapsedSeconds` and resumes from a fresh start instant.
    var isTimerPaused: Bool {
        timerStartedAt == nil && hasInProgressEvidence
    }

    var hasInProgressEvidence: Bool {
        phaseResults.contains { $0.status == .inProgress }
            || results.contains { $0.status == .inProgress }
    }

    /// The in-progress row is the durable current-side cursor. There is no
    /// second persisted `currentSide` field because the phase result already
    /// owns side, cycle, phase and status evidence.
    var currentPhaseResult: MobilityPhaseResult? {
        orderedPhaseResults.first { $0.status == .inProgress }
    }

    private static func sideOrder(_ side: MobilitySide) -> Int {
        switch side {
        case .none: 0
        case .left: 1
        case .right: 2
        case .bilateral: 3
        case .alternating: 4
        }
    }
}

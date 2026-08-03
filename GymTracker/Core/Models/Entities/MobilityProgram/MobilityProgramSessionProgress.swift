import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// One planned session occurrence inside a `MobilityProgramRun`, mirroring
/// `PlanWorkoutProgress`'s role for workouts.
@Model
final class MobilityProgramSessionProgress {
    var id: UUID
    /// The authoring `MobilityPlannedSessionDefinition.sessionKey`, resolved
    /// against `MobilityProgramRun.programSnapshot` — never the live
    /// definition — whenever this occurrence is compiled or displayed.
    var sessionKey: String
    var weekIndex: Int
    var dayIndex: Int
    var sameDayOrder: Int
    var isOptional: Bool
    var sessionNameSnapshot: String
    var statusRaw: String
    /// The first known scheduled local day for this occurrence. Immutable
    /// once established, mirroring `PlanWorkoutProgress.originalScheduledDate`.
    var originalScheduledDate: Date?
    var scheduledDate: Date?
    var lastRescheduledAt: Date?
    var startedAt: Date?
    var completedAt: Date?
    /// The `MobilitySession` this occurrence produced when started, as an
    /// ownership key rather than a live relationship (matching
    /// `MobilityRoutineItemEvidence.routineItemID`'s idiom). Set the moment
    /// a session starts; a session that ends `.stopped` is left linked here
    /// only until reconciliation clears it back to `nil` so the occurrence
    /// can be reattempted — the stopped `MobilitySession` itself remains in
    /// Mobility History independently.
    var mobilitySessionID: UUID?
    var run: MobilityProgramRun?

    var status: MobilityProgramSessionStatus {
        get { MobilityProgramSessionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        sessionKey: String,
        weekIndex: Int,
        dayIndex: Int,
        sameDayOrder: Int,
        isOptional: Bool,
        sessionNameSnapshot: String,
        scheduledDate: Date? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.sessionKey = sessionKey
        self.weekIndex = weekIndex
        self.dayIndex = dayIndex
        self.sameDayOrder = sameDayOrder
        self.isOptional = isOptional
        self.sessionNameSnapshot = sessionNameSnapshot
        self.statusRaw = MobilityProgramSessionStatus.pending.rawValue
        self.originalScheduledDate = scheduledDate
        self.scheduledDate = scheduledDate
        self.lastRescheduledAt = nil
        self.startedAt = nil
        self.completedAt = nil
        self.mobilitySessionID = nil
    }

    /// A `.pending` occurrence with a linked, still-active `MobilitySession`
    /// is the one currently being performed. Derived rather than persisted
    /// — see `MobilityProgramSessionStatus`'s doc comment.
    func isInProgress(activeMobilitySessionIDs: Set<UUID>) -> Bool {
        status == .pending && mobilitySessionID.map(activeMobilitySessionIDs.contains) == true
    }
}

#endif

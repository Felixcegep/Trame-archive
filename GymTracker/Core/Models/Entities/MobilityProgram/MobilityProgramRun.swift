import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// One activation of a mobility program, mirroring `PlanRun`'s role for
/// workouts. Mobility program runs are mobility-owned: this never reuses or
/// extends `WorkoutPlan`/`PlanRun`, and a mobility program never compiles
/// into a `WorkoutPlan`.
@Model
final class MobilityProgramRun {
    var id: UUID
    var sourceProgramID: UUID
    var sourceProgramName: String
    var startDate: Date
    var endDate: Date?
    var statusRaw: String
    /// Cursor into the flattened session list, mirroring
    /// `PlanRun.currentWeekIndex`/`currentWorkoutIndex`.
    var currentWeekIndex: Int
    var currentSessionIndex: Int
    /// The whole `MobilityProgramDefinitionPayload`, encoded at activation
    /// time. Every compile for this run reads this frozen copy — never the
    /// live `MobilityProgramDefinitionRecord` — so a later edit to the
    /// source definition cannot rewrite an in-flight or completed run.
    var programSnapshotData: Data
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MobilityProgramSessionProgress.run)
    var sessionProgress: [MobilityProgramSessionProgress] = []
    @Relationship(deleteRule: .cascade, inverse: \MobilityProgressionState.run)
    var progressionStates: [MobilityProgressionState] = []

    var status: MobilityProgramRunStatus {
        get { MobilityProgramRunStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        program: MobilityProgramDefinitionPayload,
        sourceProgramID: UUID,
        startDate: Date = .now,
        id: UUID = UUID(),
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        self.id = id
        self.sourceProgramID = sourceProgramID
        self.sourceProgramName = program.name
        self.startDate = startDate
        self.endDate = nil
        self.statusRaw = MobilityProgramRunStatus.active.rawValue
        self.currentWeekIndex = 0
        self.currentSessionIndex = 0
        self.programSnapshotData = try encoder.encode(program)
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// The frozen program payload captured at activation. `nil` only if the
    /// stored blob is somehow corrupt (never expected in practice, since the
    /// initializer is the only writer of `programSnapshotData`).
    var programSnapshot: MobilityProgramDefinitionPayload? {
        try? JSONDecoder().decode(MobilityProgramDefinitionPayload.self, from: programSnapshotData)
    }

    var orderedSessionProgress: [MobilityProgramSessionProgress] {
        sessionProgress.sorted {
            if $0.weekIndex != $1.weekIndex { return $0.weekIndex < $1.weekIndex }
            if $0.dayIndex != $1.dayIndex { return $0.dayIndex < $1.dayIndex }
            return $0.sameDayOrder < $1.sameDayOrder
        }
    }

    var orderedProgressionStates: [MobilityProgressionState] {
        progressionStates.sorted {
            $0.progressionKey == $1.progressionKey
                ? $0.sideRaw < $1.sideRaw
                : $0.progressionKey < $1.progressionKey
        }
    }
}

#endif

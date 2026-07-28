import Foundation

/// A read-only account of a fixed plan run's position and session history.
///
/// This is deliberately derived from `PlanRun` and its progress rows. It is
/// not a second persisted plan graph, which keeps schedule edits and completed
/// workout snapshots owned by their existing domains.
struct FixedProgramPathProjection: Equatable {
    struct Position: Equatable {
        let block: Block?
        let blockIndex: Int?
        let totalBlockCount: Int
        let runWeekIndex: Int?
        let weekPosition: Int?
        let totalWeekCount: Int
        let sessionIndex: Int?
        let sessionCountInWeek: Int
    }

    struct Progress: Equatable {
        let completedSessionCount: Int
        let totalSessionCount: Int

        var fraction: Double? {
            guard totalSessionCount > 0 else { return nil }
            return Double(completedSessionCount) / Double(totalSessionCount)
        }
    }

    struct Block: Equatable, Identifiable {
        let id: UUID
        let name: String
        let phaseType: PlanPhaseType
        let orderIndex: Int
        let deloadVolumeReductionPercent: Int?
        let deloadIntensityReductionPercent: Int?

        var isDeload: Bool { phaseType == .deload }
    }

    struct Week: Equatable, Identifiable {
        let runWeekIndex: Int
        let sourceWeekIndex: Int
        let sourceWeekName: String?
        let block: Block?
        let sessions: [Session]

        var id: Int { runWeekIndex }
    }

    struct Session: Equatable, Identifiable {
        let id: UUID
        let plannedWorkoutID: UUID
        let workoutName: String
        let runWeekIndex: Int
        let sourceWeekIndex: Int
        let workoutIndex: Int
        let scheduledDate: Date?
        let originalScheduledDate: Date?
        let lastRescheduledAt: Date?
        let displayState: PlanCalendarDisplayState
        let isRescheduled: Bool
        let isCurrent: Bool
        let completedWorkoutID: UUID?
        let action: ProgramPathAction?

        var isReschedulable: Bool {
            switch displayState {
            case .upcoming, .available, .missed:
                true
            case .inProgress, .completed, .skipped:
                false
            }
        }
    }

    struct Deload: Equatable {
        let block: Block
        let runWeekIndices: [Int]
        let firstRunWeekIndex: Int
        let firstScheduledDate: Date?
    }

    enum Warning: Equatable {
        case sourcePlanUnavailable
        case sourceWeekUnavailable(sourceWeekIndex: Int)
        case cursorUnavailable
    }

    let runID: UUID
    let title: String
    let status: PlanRunStatus
    let position: Position
    let progress: Progress
    let weeks: [Week]
    let currentSessionID: UUID?
    let primaryAction: ProgramPathAction?
    let currentDeload: Deload?
    let upcomingDeload: Deload?
    let warnings: [Warning]
}

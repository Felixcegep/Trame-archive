import Foundation

/// Stable navigation input. The destination resolves current persisted
/// evidence when presented rather than carrying a stale projection.
struct WeeklyProgramReviewRoute: Hashable {
    let runID: UUID
    let weekIndex: Int?

    init(runID: UUID, weekIndex: Int? = nil) {
        self.runID = runID
        self.weekIndex = weekIndex
    }
}

/// A read-only account of one occurrence week in a fixed-length plan run.
///
/// The review is rebuilt from run progress, completed workout snapshots, and
/// progression records. It is never persisted as a parallel source of truth.
struct WeeklyProgramReviewProjection: Equatable {
    struct Week: Equatable {
        let runWeekIndex: Int
        let sourceWeekIndex: Int?
        let name: String?
        let blockName: String?
        let phaseType: PlanPhaseType?
        let scheduledDateRange: DateInterval?
    }

    struct SessionSummary: Equatable {
        let plannedCount: Int
        let completedCount: Int
        let inProgressCount: Int
        let skippedCount: Int
        let missedCount: Int
        let availableCount: Int
        let upcomingCount: Int
        let unscheduledCount: Int
    }

    struct Session: Equatable, Identifiable {
        let id: UUID
        let plannedWorkoutID: UUID
        let workoutName: String
        let workoutIndex: Int
        let scheduledDate: Date?
        let originalScheduledDate: Date?
        let lastRescheduledAt: Date?
        let displayState: PlanCalendarDisplayState
        let completedWorkoutID: UUID?

        var isRescheduled: Bool {
            scheduledDate != nil
                && originalScheduledDate != nil
                && scheduledDate != originalScheduledDate
                && lastRescheduledAt != nil
        }
    }

    /// Set comparison is complete only when every session has reliable
    /// prescription evidence. A missing total remains `nil`, never zero.
    struct SetSummary: Equatable {
        let prescribedCount: Int?
        let performedCount: Int
        let sessionsWithPrescriptionEvidence: Int
        let reviewedSessionCount: Int

        var comparisonIsComplete: Bool {
            prescribedCount != nil
                && sessionsWithPrescriptionEvidence == reviewedSessionCount
        }
    }

    struct ProgressionDecision: Equatable, Identifiable {
        let id: UUID
        let workoutID: UUID
        let progressionKey: String
        let exerciseName: String?
        let ruleID: UUID
        let ruleVersion: Int?
        let createdAt: Date
        let resolvedAt: Date?
        let isResolved: Bool
        let outcome: ProgressionDecisionOutcome?
        let proposedLoad: Double?
        let appliedLoad: Double?
    }

    struct Substitution: Equatable, Identifiable {
        let id: String
        let workoutID: UUID
        let originalExerciseID: UUID
        let originalExerciseName: String?
        let selectedExerciseID: UUID
        let selectedExerciseName: String
        let reason: SubstitutionReason?
        let scope: SubstitutionScope?
        let suitability: SubstitutionSuitability?
        let comparability: SubstitutionComparability?
        let progressionPolicy: ProgressionTransferPolicy?
        let confidence: SubstitutionEvidenceConfidence?
        let evaluationVersion: Int?
    }

    struct NextWeek: Equatable {
        struct Session: Equatable, Identifiable {
            let id: UUID
            let name: String
            let workoutIndex: Int
            let scheduledDate: Date?
        }

        let runWeekIndex: Int
        let sourceWeekIndex: Int?
        let name: String?
        let blockName: String?
        let phaseType: PlanPhaseType?
        let deloadVolumeReductionPercent: Int?
        let deloadIntensityReductionPercent: Int?
        let sessions: [Session]

        var isDeload: Bool { phaseType == .deload }
    }

    enum Warning: Equatable {
        case reviewedWeekUnavailable
        case sourcePlanUnavailable
        case sourceWeekUnavailable(sourceWeekIndex: Int)
        case completedSessionMissingWorkout(progressID: UUID)
        case linkedWorkoutNotCompleted(progressID: UUID, workoutID: UUID)
        case incompleteSetPrescription(progressID: UUID)
        case legacySubstitutionEvidence(workoutID: UUID, exerciseID: UUID)
    }

    let runID: UUID
    let planName: String
    let runStatus: PlanRunStatus
    let week: Week
    let sessions: [Session]
    let sessionSummary: SessionSummary
    let setSummary: SetSummary
    let progressionDecisions: [ProgressionDecision]
    let substitutions: [Substitution]
    let nextWeek: NextWeek?
    let warnings: [Warning]
}

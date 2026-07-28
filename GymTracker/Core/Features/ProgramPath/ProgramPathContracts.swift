import Foundation

/// A stable destination for a derived Program Path. The path resolves a run at
/// presentation time, so it never caches mutable run state in navigation.
enum ProgramPathRoute: Hashable {
    case fixedRun(UUID)
    case rotationRun(UUID)
}

/// Intents a Program Path presentation can request from its owning flow.
///
/// The projection deliberately emits values rather than mutating SwiftData.
/// Root navigation and the existing coordinators remain responsible for every
/// workout, History, and scheduling transition.
enum ProgramPathAction: Equatable {
    case startFixedWorkout(runID: UUID, progressID: UUID)
    case resumeWorkout(workoutID: UUID)
    case rescheduleFixedWorkout(runID: UUID, progressID: UUID)
    case openCompletedWorkout(workoutID: UUID)
    case openFixedSchedule(runID: UUID)
    case startExpectedRotationWorkout(runID: UUID)
}

enum ProgramPathSource: Equatable {
    case fixed
    case rotation
}

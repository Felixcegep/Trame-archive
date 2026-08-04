import Foundation

/// The training domain a scheduled occurrence belongs to. Distinct domains
/// intentionally never share one persisted graph; this only labels which
/// domain produced an occurrence in a unified schedule projection.
nonisolated enum TrainingDomain: String, Codable, Hashable, Sendable {
    case workout
    case mobility
    case assessment
}

/// A unified read-only projection over otherwise-independent scheduling
/// graphs (workout plan runs, mobility program runs, assessment sessions) so
/// a calendar or "what's next" surface can lay them out on one timeline
/// without merging their owning domains or persisted types.
///
/// This protocol only establishes the shared shape. Conforming a concrete
/// run/occurrence type — for example a future mobility program run's planned
/// session, alongside the existing `PlanWorkoutProgress` for workouts — is
/// the responsibility of the feature that owns that type.
protocol ScheduledTrainingOccurrence {
    var occurrenceID: UUID { get }
    var scheduledDay: LocalDay { get }
    var sameDayOrder: Int { get }
    var isOptional: Bool { get }
    var displayName: String { get }
    var domain: TrainingDomain { get }
}

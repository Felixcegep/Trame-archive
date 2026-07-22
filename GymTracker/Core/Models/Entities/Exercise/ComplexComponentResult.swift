import Foundation
import SwiftData

/// Immutable-at-workout-start evidence for one ordered component of a
/// `RepPrescription.sequence` set. It deliberately does not reuse set
/// segments: a complex component is a distinct lift outcome, not a short
/// internal effort of one lift.
@Model
final class ComplexComponentResult {
    var id = UUID()
    var orderIndex: Int
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var prescribedRepetitions: Int
    var performedRepetitions: Int
    var outcome: ComplexComponentOutcome
    var liftQuality: LiftQuality?
    var exerciseSet: ExerciseSet?

    init(
        orderIndex: Int,
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        prescribedRepetitions: Int,
        performedRepetitions: Int = 0,
        outcome: ComplexComponentOutcome = .notStarted,
        liftQuality: LiftQuality? = nil
    ) {
        self.orderIndex = orderIndex
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.prescribedRepetitions = max(1, prescribedRepetitions)
        self.performedRepetitions = max(0, performedRepetitions)
        self.outcome = outcome
        self.liftQuality = liftQuality
    }
}

import Foundation
import SwiftData

/// An explicit fallback for a plan prescription. It is not applied
/// automatically and never changes a completed workout's exercise snapshot.
@Model
final class PlannedExerciseAlternative {
    var orderIndex: Int
    var exercise: Exercise
    var plannedExercise: PlannedExercise?

    init(exercise: Exercise, orderIndex: Int) {
        self.exercise = exercise
        self.orderIndex = orderIndex
    }
}

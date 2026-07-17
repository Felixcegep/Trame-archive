import Foundation
import SwiftData

/// A deliberate, user-maintained connection between two library exercises.
/// Variation families remain descriptive; only a substitution relationship can
/// offer a replacement while a workout is in progress.
@Model
final class ExerciseRelationship {
    var type: ExerciseRelationshipType
    var sourceExercise: Exercise?
    var targetExercise: Exercise?

    init(
        sourceExercise: Exercise,
        targetExercise: Exercise,
        type: ExerciseRelationshipType
    ) {
        self.sourceExercise = sourceExercise
        self.targetExercise = targetExercise
        self.type = type
    }
}

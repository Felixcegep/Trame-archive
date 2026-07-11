import Foundation
import SwiftData

extension ModelContext {
    func clearAllGymData() throws {
        try delete(model: ExerciseSet.self)
        try delete(model: ExerciceEntry.self)
        try delete(model: Workout.self)
        try delete(model: WorkoutPlan.self)
        try delete(model: WorkoutTemplate.self)
        try delete(model: TemplateExercise.self)
        try delete(model: ExerciceTemplate.self)
        try save()
    }
}

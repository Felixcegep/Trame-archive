import Foundation
import SwiftData

extension ModelContext {
    func clearAllGymData() throws {
        let workouts = try fetch(FetchDescriptor<Workout>())
        for workout in workouts {
            workout.sourceTemplate = nil
        }
        try save()

        try delete(model: ExerciseSet.self)
        try delete(model: ExerciceEntry.self)
        try delete(model: Workout.self)
        try delete(model: WorkoutCollection.self)
        try delete(model: WorkoutTemplate.self)
        try delete(model: TemplateExercise.self)
        try delete(model: ExerciceTemplate.self)
        try save()
    }
}

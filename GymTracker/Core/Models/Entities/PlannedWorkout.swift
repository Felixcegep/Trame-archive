import Foundation
import SwiftData

@Model
final class PlannedWorkout {
    var id = UUID()
    var name: String
    var orderIndex: Int
    var dayOffset: Int
    var isOptional: Bool = false
    var isTestDay: Bool = false
    var estimatedDurationSeconds: Int?
    var notes: String?
    var week: PlanWeek?
    @Relationship(deleteRule: .nullify)
    var sourceTemplate: WorkoutTemplate?
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plannedWorkout)
    var plannedExercises: [PlannedExercise] = []

    init(
        name: String,
        orderIndex: Int,
        dayOffset: Int,
        isOptional: Bool = false,
        isTestDay: Bool = false,
        estimatedDurationSeconds: Int? = nil,
        notes: String? = nil,
        sourceTemplate: WorkoutTemplate? = nil,
        plannedExercises: [PlannedExercise] = []
    ) {
        self.name = name
        self.orderIndex = orderIndex
        self.dayOffset = dayOffset
        self.isOptional = isOptional
        self.isTestDay = isTestDay
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.notes = notes
        self.sourceTemplate = sourceTemplate
        self.plannedExercises = plannedExercises
    }

    var orderedPlannedExercises: [PlannedExercise] {
        plannedExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    func normalizePlannedExerciseOrder() {
        for (index, exercise) in orderedPlannedExercises.enumerated() {
            exercise.orderIndex = index
        }
        SupersetGrouping.dissolveInvalidGroups(in: orderedPlannedExercises)
    }
}

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
    @Relationship(deleteRule: .cascade, inverse: \PlannedExerciseBlock.plannedWorkout)
    var executionBlocks: [PlannedExerciseBlock] = []

    init(
        name: String,
        orderIndex: Int,
        dayOffset: Int,
        isOptional: Bool = false,
        isTestDay: Bool = false,
        estimatedDurationSeconds: Int? = nil,
        notes: String? = nil,
        sourceTemplate: WorkoutTemplate? = nil,
        plannedExercises: [PlannedExercise] = [],
        executionBlocks: [PlannedExerciseBlock] = []
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
        self.executionBlocks = executionBlocks
    }

    var orderedPlannedExercises: [PlannedExercise] {
        plannedExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var orderedExecutionBlocks: [PlannedExerciseBlock] {
        executionBlocks.sorted { $0.orderIndex < $1.orderIndex }
    }

    func normalizePlannedExerciseOrder() {
        for (index, exercise) in orderedPlannedExercises.enumerated() {
            exercise.orderIndex = index
        }
        SupersetGrouping.dissolveInvalidGroups(in: orderedPlannedExercises)
    }
}

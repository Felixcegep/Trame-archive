import Foundation
@testable import GymTracker

enum ProgramDefinitionFixture {
    static func stage(exerciseID: UUID) -> ProgramDefinitionPayload {
        let volumeSets = (0..<2).map {
            SetPrescriptionDefinition(orderIndex: $0, repetitions: .fixed(8), restSeconds: 90)
        }
        let strengthSets = (0..<4).map {
            SetPrescriptionDefinition(orderIndex: $0, repetitions: .fixed(3), restSeconds: 150)
        }
        let exercise = ProgramExerciseDefinition(
            exerciseID: exerciseID,
            exposureKey: "squat-stage",
            orderIndex: 0,
            plannedSets: [],
            stages: [
                ProgramStageDefinition(stageID: "volume", name: "Volume", plannedSets: volumeSets),
                ProgramStageDefinition(stageID: "strength", name: "Strength", plannedSets: strengthSets)
            ],
            initialStageID: "volume",
            progressionRules: [
                ProgressionRuleDefinition(
                    metric: .load,
                    trigger: .allOf([.atStage("volume"), .allRequiredSetsCompleted]),
                    successAction: .changeStage("strength"),
                    cadence: .nextExerciseOccurrence,
                    scope: .exerciseExposure,
                    applicationMode: .automatic
                )
            ],
            initialLoad: 100
        )
        var definition = make(exercises: [exercise])
        definition.programKey = "stage-program"
        return definition
    }

    static func make(exercises: [ProgramExerciseDefinition]) -> ProgramDefinitionPayload {
        let workout = ProgramWorkoutDefinition(
            orderIndex: 0,
            name: "Training Day",
            dayOffset: 0,
            plannedExercises: exercises
        )
        let week = ProgramWeekDefinition(weekIndex: 0, workouts: [workout])
        let block = ProgramBlockDefinition(orderIndex: 0, name: "Accumulation", weeks: [week])
        return ProgramDefinitionPayload(
            name: "Test Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [block]
        )
    }
}

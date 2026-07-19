import Foundation
import XCTest
@testable import GymTracker

final class ProgramStageTests: XCTestCase {
    func testStageDefinitionCompilesAndSeedsInitialRunState() throws {
        let squat = Exercise(name: "Stage Squat", primaryMuscles: [.quadriceps])
        let definition = ProgramDefinitionFixture.stage(exerciseID: squat.id)

        XCTAssertTrue(ProgramDefinitionValidator.validate(definition, isBuiltIn: true).isEmpty)
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let plannedExercise = try XCTUnwrap(
            plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first
        )
        let configuration = try JSONDecoder().decode(
            ProgramStageConfiguration.self,
            from: try XCTUnwrap(plannedExercise.progressionStagesData)
        )
        XCTAssertEqual(configuration.initialStageID, "volume")
        XCTAssertEqual(plannedExercise.orderedPlannedSets.count, 2)

        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        XCTAssertEqual(run.orderedProgressionStates.first?.currentStageID, "volume")
    }

    func testAMRAPMetricFeedsTrainingMaxFormula() throws {
        var context = FormulaResolutionContext()
        context.completedMetricsByExposure["squat"] = [.amrapRepetitions: 8]
        let formula = ProgressionFormula.clamp(
            value: .add(
                .source(.trainingMax(exposureKey: "squat")),
                .multiply(
                    .source(.completedMetric(exposureKey: "squat", metric: .amrapRepetitions)),
                    .source(.constant(2.5))
                )
            ),
            minimum: 0,
            maximum: 120
        )
        context.trainingMaxByExposure["squat"] = 100

        XCTAssertEqual(try ProgramFormulaResolver.resolve(formula, context: context), 120)
        context.completedMetricsByExposure["squat"] = nil
        XCTAssertThrowsError(try ProgramFormulaResolver.resolve(formula, context: context))
    }

    func testSnapshotPersistsPrescriptionReferenceValueInKilograms() throws {
        let squat = Exercise(
            name: "Reference Squat",
            primaryMuscles: [.quadriceps],
            equipmentType: .barbell
        )
        let exercise = ProgramExerciseDefinition(
            exerciseID: squat.id,
            exposureKey: "reference-squat",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(
                        reference: .init(kind: .trainingMax, exposureKey: "reference-squat"),
                        percentage: 0.8
                    )
                )
            ],
            initialTrainingMax: 200
        )
        let plan = try ProgramDefinitionCompiler.compile(
            ProgramDefinitionFixture.make(exercises: [exercise]),
            exercisesByID: [squat.id: squat]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .imperial)
        let set = try XCTUnwrap(workout.orderedExercises.first?.orderedSets.first)

        XCTAssertEqual(set.prescribedReferenceValue ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(set.prescribedSuggestedLoadType, .lbs)
    }

    func testStageTransitionClearsLoadOnlyWhenDestinationDoesNotCarryIt() throws {
        let stages = [
            ProgramStageDefinition(stageID: "volume", plannedSets: [.init(orderIndex: 0, repetitions: .fixed(8))]),
            ProgramStageDefinition(stageID: "reset", plannedSets: [.init(orderIndex: 0, repetitions: .fixed(5))], carriesLoad: false)
        ]
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .manualApproval,
            successAction: .changeStage("reset"),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(manualApproval: true),
            state: ProgressionEvaluationState(currentLoad: 100, currentStageID: "volume"),
            stageDefinitions: stages
        )

        XCTAssertEqual(result.state.currentStageID, "reset")
        XCTAssertNil(result.state.currentLoad)
    }

    func testStageSnapshotGrowsAndPreservesCompletedSetsWhenShrinking() throws {
        let squat = Exercise(name: "Snapshot Stage Squat", primaryMuscles: [.quadriceps])
        let plan = try ProgramDefinitionCompiler.compile(
            ProgramDefinitionFixture.stage(exerciseID: squat.id),
            exercisesByID: [squat.id: squat]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedExercise = try XCTUnwrap(plannedWorkout.orderedPlannedExercises.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        XCTAssertEqual(entry.orderedSets.count, 2)

        let state = try XCTUnwrap(run.orderedProgressionStates.first)
        state.currentStageID = "strength"
        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric
        )
        XCTAssertEqual(entry.orderedSets.count, 4)

        let completed = entry.orderedSets[3]
        completed.done = true
        state.currentStageID = "volume"
        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric,
            preservingCompletedSets: true
        )
        XCTAssertEqual(entry.orderedSets.count, 3)
        XCTAssertTrue(entry.orderedSets.contains { $0.id == completed.id && $0.done })
    }

    func testValidatorRejectsStageWaveMixAndUnknownStageTargets() {
        let exerciseID = UUID()
        var definition = ProgramDefinitionFixture.stage(exerciseID: exerciseID)
        definition.blocks[0].weeks[0].workouts[0].plannedExercises[0].waves = [
            ProgramWaveDefinition(orderIndex: 0, plannedSets: [.init(orderIndex: 0, repetitions: .fixed(5))])
        ]
        definition.blocks[0].weeks[0].workouts[0].plannedExercises[0].progressionRules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .manualApproval,
                successAction: .changeStage("missing"),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure
            )
        ]

        let issues = ProgramDefinitionValidator.validate(definition, isBuiltIn: true)
        XCTAssertTrue(issues.contains { $0.code == .invalidStage && $0.message.contains("cannot be used") })
        XCTAssertTrue(issues.contains { $0.code == .invalidStage && $0.message.contains("missing stage") })
    }

    func testPlannedExerciseBackupPreservesStageConfiguration() throws {
        let configuration = ProgramStageConfiguration(
            stages: [
                ProgramStageDefinition(
                    stageID: "volume",
                    name: "Volume",
                    plannedSets: [.init(orderIndex: 0, repetitions: .fixed(8))]
                )
            ],
            initialStageID: "volume"
        )
        let data = try JSONEncoder().encode(configuration)
        let dto = PlannedExerciseDTO(
            id: UUID().uuidString,
            exerciseName: "Squat",
            orderIndex: 0,
            role: ExerciseRole.main.rawValue,
            isOptional: false,
            targetSets: 1,
            repRangeMinimum: 8,
            repRangeMaximum: 8,
            suggestedLoad: 100,
            suggestedLoadType: WeightType.kg.rawValue,
            restSeconds: 90,
            targetRPE: nil,
            targetRIR: nil,
            notes: nil,
            progressionRule: ProgressionRule.none.rawValue,
            progressionStagesData: data
        )

        let restored = try JSONDecoder().decode(PlannedExerciseDTO.self, from: JSONEncoder().encode(dto))
        let restoredData = try XCTUnwrap(restored.progressionStagesData)
        XCTAssertEqual(try JSONDecoder().decode(ProgramStageConfiguration.self, from: restoredData), configuration)
    }

}

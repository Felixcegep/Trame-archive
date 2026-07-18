import Foundation
import XCTest
@testable import GymTracker

final class ProgramEngineSimulationTests: XCTestCase {
    func testBeginnerLinearProgressionAddsLoadThenDeloadsAfterThreeFailures() throws {
        let squatID = UUID()
        let definition = ProgramFixtureCatalog.beginnerFiveByFive(exerciseIDs: [
            "squat": squatID,
            "bench": UUID(),
            "row": UUID(),
            "press": UUID(),
            "deadlift": UUID()
        ])
        let exercise = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)
        let rules = exercise.progressionRules
        var state = ProgressionEvaluationState(currentLoad: 100)

        let success = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 5, completedSets: 5),
            state: state
        )
        XCTAssertEqual(success.state.currentLoad, 102.5, accuracy: 0.001)
        state = success.state

        for failure in 1...3 {
            state.failureCount += 1
            let result = try ProgramProgressionEvaluator.evaluate(
                rules: rules,
                performance: ProgressionPerformance(requiredSets: 5, completedSets: 4, didFail: true),
                state: state
            )
            state = result.state
            if failure < 3 {
                XCTAssertEqual(state.currentLoad, 102.5, accuracy: 0.001)
            }
        }
        XCTAssertEqual(state.currentLoad, 92.25, accuracy: 0.001)
    }

    func testDoubleProgressionAdvancesOnlyWhenEverySetReachesTheUpperBound() throws {
        let definition = ProgramFixtureCatalog.doubleProgression(exerciseIDs: ["press": UUID()])
        let rules = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.progressionRules)
        let state = ProgressionEvaluationState(currentLoad: 30)

        let hold = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 2, upperBoundSets: 1),
            state: state
        )
        XCTAssertEqual(hold.state.currentLoad, 30)
        XCTAssertTrue(hold.recommendations.isEmpty)

        let increase = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 2, upperBoundSets: 2),
            state: hold.state
        )
        XCTAssertEqual(increase.state.currentLoad, 32.5, accuracy: 0.001)
        XCTAssertEqual(increase.recommendations.count, 1)
    }

    func testStageProgressionMovesThroughStagesAndStartsDeload() throws {
        let definition = ProgramFixtureCatalog.stageProgression(exerciseIDs: ["squat": UUID()])
        let rules = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.progressionRules)
        var state = ProgressionEvaluationState(currentLoad: 140)

        for expectedStage in ["6x2", "10x1"] {
            state.failureCount += 1
            state = try ProgramProgressionEvaluator.evaluate(
                rules: rules,
                performance: ProgressionPerformance(requiredSets: 3, completedSets: 0, didFail: true),
                state: state
            ).state
            XCTAssertEqual(state.currentStageID, expectedStage)
        }

        state.failureCount += 1
        state = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 0, didFail: true),
            state: state
        ).state
        XCTAssertTrue(state.isDeloading)
    }

    func testVariationAndConditioningProgressIndependently() throws {
        let assisted = UUID()
        let band = UUID()
        let bodyweight = UUID()
        let weighted = UUID()
        let ladder = ProgramFixtureCatalog.bodyweightVariation(exerciseIDs: [
            "assisted": assisted,
            "band": band,
            "bodyweight": bodyweight,
            "weighted": weighted
        ])
        let variationRules = try XCTUnwrap(ladder.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.progressionRules)
        let variation = try ProgramProgressionEvaluator.evaluate(
            rules: variationRules,
            performance: ProgressionPerformance(technicalQualityReached: true),
            state: ProgressionEvaluationState(currentVariationExerciseID: assisted),
            variationLadder: [assisted, band, bodyweight, weighted]
        )
        XCTAssertEqual(variation.state.currentVariationExerciseID, band)

        let conditioning = ProgramFixtureCatalog.conditioningProgression(exerciseIDs: ["plank": UUID(), "carry": UUID()])
        let exercises = try XCTUnwrap(conditioning.blocks.first?.weeks.first?.workouts.first?.plannedExercises)
        let durationRules = try XCTUnwrap(exercises.first?.progressionRules)
        let distanceRules = try XCTUnwrap(exercises.last?.progressionRules)
        let duration = try ProgramProgressionEvaluator.evaluate(
            rules: durationRules,
            performance: ProgressionPerformance(requiredSets: 1, completedSets: 1),
            state: ProgressionEvaluationState()
        )
        let distance = try ProgramProgressionEvaluator.evaluate(
            rules: distanceRules,
            performance: ProgressionPerformance(requiredSets: 1, completedSets: 1),
            state: ProgressionEvaluationState()
        )
        XCTAssertEqual(duration.state.durationOffset, 60)
        XCTAssertEqual(distance.state.distanceOffset, 250)
    }

    func testOlympicQualityRuleRequiresSuccessfulAttempts() throws {
        let rule = ProgressionRuleDefinition(
            metric: .successfulAttempts,
            trigger: .successfulAttemptRatioReached(0.9),
            successAction: .addLoad(2.5),
            failureAction: .reduceLoadPercentage(0.05),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let success = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(successfulAttemptRatio: 1, didFail: false),
            state: ProgressionEvaluationState(currentLoad: 100)
        )
        XCTAssertEqual(success.state.currentLoad, 102.5, accuracy: 0.001)

        let miss = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(successfulAttemptRatio: 0.5, didFail: true),
            state: success.state
        )
        XCTAssertEqual(miss.state.currentLoad, 97.375, accuracy: 0.001)
    }

    func testMixedFixtureContainsIndependentPrescriptionFamilies() throws {
        let definition = ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: [
            "squat": UUID(), "bench": UUID(), "row": UUID(), "plank": UUID(),
            "complex": UUID(), "clean": UUID(), "jerk": UUID()
        ])
        let rows = try ProgramDefinitionPreview.rows(for: definition)
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.role == .topSet } })
        XCTAssertTrue(rows.contains { $0.sets.contains { if case .duration = $0.repetitions { return true }; return false } })
        XCTAssertTrue(rows.contains { $0.sets.contains { if case .sequence = $0.repetitions { return true }; return false } })
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.loadReference == .trainingMax } })
    }

    func testEveryCatalogFixtureValidatesAndPreviews() throws {
        let ids = [
            "squat": UUID(), "bench": UUID(), "row": UUID(), "press": UUID(), "deadlift": UUID(),
            "plank": UUID(), "carry": UUID(), "snatch": UUID(), "pull": UUID(), "complex": UUID(),
            "clean": UUID(), "jerk": UUID(), "assisted": UUID(), "band": UUID(), "bodyweight": UUID(),
            "weighted": UUID()
        ]
        let fixtures = [
            ProgramFixtureCatalog.beginnerFiveByFive(exerciseIDs: ids),
            ProgramFixtureCatalog.doubleProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.stageProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.trainingMaxCycle(exerciseIDs: ids),
            ProgramFixtureCatalog.topSetBackOff(exerciseIDs: ids),
            ProgramFixtureCatalog.bodyweightVariation(exerciseIDs: ids),
            ProgramFixtureCatalog.olympicWeightlifting(exerciseIDs: ids),
            ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: ids),
            ProgramFixtureCatalog.weeklyHeavyLightMedium(exerciseIDs: ids),
            ProgramFixtureCatalog.amrapWave(exerciseIDs: ids),
            ProgramFixtureCatalog.blockPeriodized(exerciseIDs: ids),
            ProgramFixtureCatalog.conditioningProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.waveLoading(exerciseIDs: ids)
        ]

        for fixture in fixtures {
            XCTAssertTrue(ProgramDefinitionValidator.validate(fixture).isEmpty, fixture.name)
            XCTAssertFalse(try ProgramDefinitionPreview.rows(for: fixture).isEmpty, fixture.name)
        }
    }
}

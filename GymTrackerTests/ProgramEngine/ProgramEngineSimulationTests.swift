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
        XCTAssertEqual(success.state.currentLoad ?? .nan, 102.5, accuracy: 0.001)
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
                XCTAssertEqual(state.currentLoad ?? .nan, 102.5, accuracy: 0.001)
            }
        }
        XCTAssertEqual(state.currentLoad ?? .nan, 92.25, accuracy: 0.001)
    }

    func testSuccessfulOccurrenceResetsConsecutiveFailureCountBeforeDeloadEvaluation() throws {
        let deloadRule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .failureCountReached(3),
            successAction: .reduceLoadPercentage(0.1),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let failure = ProgressionPerformance(requiredSets: 3, completedSets: 2, didFail: true)
        let success = ProgressionPerformance(requiredSets: 3, completedSets: 3)

        var state = ProgressionEvaluationState(currentLoad: 100)
        state = ProgramProgressionEvaluator.state(afterRecording: failure, from: state)
        state = ProgramProgressionEvaluator.state(afterRecording: failure, from: state)
        XCTAssertEqual(state.failureCount, 2)

        state = ProgramProgressionEvaluator.state(afterRecording: success, from: state)
        XCTAssertEqual(state.failureCount, 0)

        state = ProgramProgressionEvaluator.state(afterRecording: failure, from: state)
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [deloadRule],
            performance: failure,
            state: state
        )
        XCTAssertEqual(result.state.currentLoad ?? .nan, 100, accuracy: 0.001)
        XCTAssertTrue(result.recommendations.isEmpty)
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
        XCTAssertEqual(increase.state.currentLoad ?? .nan, 32.5, accuracy: 0.001)
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

    func testAssistanceProgressionReducesAssistanceWithoutGoingNegative() throws {
        let rule = ProgressionRuleDefinition(
            metric: .assistance,
            trigger: .allRequiredSetsCompleted,
            successAction: .reduceAssistance(5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: ProgressionEvaluationState(currentLoad: 3)
        )
        XCTAssertEqual(result.state.currentLoad, 0)
    }

    func testReductionActionsRetainSignedOffsetsForFuturePrescriptions() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .repetitions, trigger: .allRequiredSetsCompleted, successAction: .reduceRepetitions(2), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .setCount, trigger: .allRequiredSetsCompleted, successAction: .reduceSets(1), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .duration, trigger: .allRequiredSetsCompleted, successAction: .reduceDuration(15), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .distance, trigger: .allRequiredSetsCompleted, successAction: .reduceDistance(50), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .restDuration, trigger: .allRequiredSetsCompleted, successAction: .reduceRestDuration(10), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .calories, trigger: .allRequiredSetsCompleted, successAction: .reduceCalories(20), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: ProgressionEvaluationState()
        )

        XCTAssertEqual(result.state.repetitionOffset, -2)
        XCTAssertEqual(result.state.setCountOffset, -1)
        XCTAssertEqual(result.state.durationOffset, -15)
        XCTAssertEqual(result.state.distanceOffset, -50)
        XCTAssertEqual(result.state.restDurationOffset, -10)
        XCTAssertEqual(result.state.caloriesOffset, -20)
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
        XCTAssertEqual(success.state.currentLoad ?? .nan, 102.5, accuracy: 0.001)

        let miss = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(successfulAttemptRatio: 0.5, didFail: true),
            state: success.state
        )
        XCTAssertEqual(miss.state.currentLoad ?? .nan, 97.375, accuracy: 0.001)
    }

    func testOlympicFixtureUsesDataDrivenConsecutiveMissLadder() throws {
        let definition = ProgramFixtureCatalog.olympicWeightlifting(exerciseIDs: [
            "snatch": UUID(), "pull": UUID(), "complex": UUID(), "clean": UUID()
        ])
        let rules = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.progressionRules)
        let missedAttempt = ProgressionPerformance(
            requiredSets: 1,
            completedSets: 1,
            successfulAttemptRatio: 0,
            didFail: true
        )
        var state = ProgressionEvaluationState(currentLoad: 100)

        state = ProgramProgressionEvaluator.state(afterRecording: missedAttempt, from: state)
        var result = try ProgramProgressionEvaluator.evaluate(rules: rules, performance: missedAttempt, state: state)
        XCTAssertEqual(result.recommendations.map(\.action), [.repeatPrescription])

        state = ProgramProgressionEvaluator.state(afterRecording: missedAttempt, from: result.state)
        result = try ProgramProgressionEvaluator.evaluate(rules: rules, performance: missedAttempt, state: state)
        XCTAssertEqual(result.recommendations.map(\.action), [.reduceLoadPercentage(0.05)])
        XCTAssertEqual(result.state.currentLoad ?? .nan, 95, accuracy: 0.001)

        state = ProgramProgressionEvaluator.state(afterRecording: missedAttempt, from: result.state)
        result = try ProgramProgressionEvaluator.evaluate(rules: rules, performance: missedAttempt, state: state)
        XCTAssertEqual(result.recommendations.map(\.action), [.endExercise])
    }

    func testCadenceDefersAutomaticStateUntilItsBoundary() throws {
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .allRequiredSetsCompleted,
            successAction: .addLoad(2.5),
            cadence: .nextWeek,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let beforeWeekEnd = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3, weekCompleted: false),
            state: ProgressionEvaluationState(currentLoad: 100),
            automaticCadences: [.nextExerciseOccurrence, .nextWorkout]
        )
        XCTAssertEqual(beforeWeekEnd.state.currentLoad ?? .nan, 100, accuracy: 0.001)
        XCTAssertEqual(beforeWeekEnd.deferredStates.first?.state.currentLoad ?? .nan, 102.5, accuracy: 0.001)

        let atWeekEnd = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3, weekCompleted: true),
            state: ProgressionEvaluationState(currentLoad: 100),
            automaticCadences: [.nextExerciseOccurrence, .nextWorkout, .nextWeek]
        )
        XCTAssertEqual(atWeekEnd.state.currentLoad ?? .nan, 102.5, accuracy: 0.001)
        XCTAssertTrue(atWeekEnd.deferredStates.isEmpty)
    }

    func testDeferredRulesAtTheSameCadenceComposeWithoutDroppingActions() throws {
        let rules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                cadence: .nextWeek,
                scope: .exerciseExposure,
                priority: 2,
                applicationMode: .automatic
            ),
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                cadence: .nextWeek,
                scope: .exerciseExposure,
                priority: 1,
                applicationMode: .automatic
            )
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: ProgressionEvaluationState(currentLoad: 100),
            automaticCadences: [.nextExerciseOccurrence, .nextWorkout]
        )

        XCTAssertEqual(result.state.currentLoad ?? .nan, 100, accuracy: 0.001)
        XCTAssertEqual(result.deferredStates.count, 2)
        XCTAssertEqual(result.deferredStates.map(\.action), [.addLoad(2.5), .addLoad(2.5)])
        XCTAssertEqual(result.deferredStates.compactMap(\.state.currentLoad), [102.5, 105])
    }

    func testHeavyLightMediumAdvancesTheWeeklyExposureOnlyAfterTheWeek() throws {
        let definition = ProgramFixtureCatalog.weeklyHeavyLightMedium(exerciseIDs: ["squat": UUID()])
        let volume = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)
        let rule = try XCTUnwrap(volume.progressionRules.first)
        let before = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(requiredSets: 5, completedSets: 5, weekCompleted: false),
            state: ProgressionEvaluationState(currentLoad: 100),
            automaticCadences: [.nextExerciseOccurrence, .nextWorkout]
        )
        XCTAssertEqual(before.state.currentLoad ?? .nan, 100, accuracy: 0.001)
        // The fixture's rule triggers on weekCompleted, so a mid-week
        // occurrence produces no deferred state at all; the load only moves
        // in the evaluation of the workout that completes the week.
        XCTAssertTrue(before.deferredStates.isEmpty)

        let after = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(requiredSets: 5, completedSets: 5, weekCompleted: true),
            state: ProgressionEvaluationState(currentLoad: 100),
            automaticCadences: [.nextExerciseOccurrence, .nextWorkout, .nextWeek]
        )
        XCTAssertEqual(after.state.currentLoad ?? .nan, 102.5, accuracy: 0.001)
    }

    func testTrainingMaxCycleUpdatesOnlyAtCycleBoundary() throws {
        let rule = ProgressionRuleDefinition(
            metric: .trainingMax,
            trigger: .cycleCompleted,
            successAction: .updateTrainingMax(
                .multiply(
                    .source(.trainingMax(exposureKey: "squat")),
                    .source(.constant(1.05))
                )
            ),
            cadence: .nextCycle,
            scope: .cycle,
            applicationMode: .automatic
        )
        var context = FormulaResolutionContext()
        context.trainingMaxByExposure["squat"] = 200
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(cycleCompleted: true),
            state: ProgressionEvaluationState(trainingMax: 200),
            formulaContext: context,
            automaticCadences: [.nextCycle]
        )
        XCTAssertEqual(result.state.trainingMax ?? .nan, 210, accuracy: 0.001)
        XCTAssertEqual(result.recommendations.first?.scope, .cycle)
    }

    func testWaveAndOlympicFixturesAdvanceFromSuccessfulEvidence() throws {
        let waveDefinition = ProgramFixtureCatalog.waveLoading(exerciseIDs: ["squat": UUID()])
        let waveExercise = try XCTUnwrap(waveDefinition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)
        let waveResult = try ProgramProgressionEvaluator.evaluate(
            rules: waveExercise.progressionRules,
            performance: ProgressionPerformance(requiredSets: 2, completedSets: 2, waveCompleted: true),
            state: ProgressionEvaluationState(currentWaveIndex: 0)
        )
        XCTAssertEqual(waveResult.state.currentWaveIndex, 1)

        let olympic = ProgramFixtureCatalog.olympicWeightlifting(exerciseIDs: [
            "snatch": UUID(), "pull": UUID(), "complex": UUID(), "clean": UUID()
        ])
        let snatch = try XCTUnwrap(olympic.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)
        XCTAssertEqual(snatch.initialTrainingMax, 100)
        let qualityRule = ProgressionRuleDefinition(
            metric: .successfulAttempts,
            trigger: .successfulAttemptRatioReached(0.9),
            successAction: .addLoad(2.5),
            failureAction: .reduceLoadPercentage(0.05),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let success = try ProgramProgressionEvaluator.evaluate(
            rules: [qualityRule],
            performance: ProgressionPerformance(successfulAttemptRatio: 1),
            state: ProgressionEvaluationState(currentLoad: 100)
        )
        XCTAssertEqual(success.state.currentLoad ?? .nan, 102.5, accuracy: 0.001)
    }

    func testMixedFixtureContainsIndependentPrescriptionFamilies() throws {
        let definition = ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: [
            "squat": UUID(), "bench": UUID(), "row": UUID(), "plank": UUID(),
            "complex": UUID(), "clean": UUID(), "jerk": UUID()
        ])
        let rows = try ProgramDefinitionPreview.rows(for: definition)
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.role == .topSet } })
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.generatesAfterSourceCompletion } })
        XCTAssertTrue(rows.contains { $0.sets.contains { if case .duration = $0.repetitions { return true }; return false } })
        XCTAssertTrue(rows.contains { $0.sets.contains { if case .sequence = $0.repetitions { return true }; return false } })
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.loadReference == .trainingMax } })
    }

    func testEveryCatalogFixtureValidatesPreviewsAndCompiles() throws {
        let names = [
            "squat", "bench", "row", "press", "deadlift", "snatch", "pull", "complex",
            "clean", "jerk", "assisted", "band", "bodyweight", "weighted", "plank", "carry"
        ]
        let ids = Dictionary(uniqueKeysWithValues: names.map { ($0, UUID()) })
        let fixtures = ProgramFixtureCatalog.all(exerciseIDs: ids)
        XCTAssertFalse(fixtures.isEmpty)
        // The catalog's contract is that every fixture is unique and
        // individually valid — not a specific headcount that breaks every
        // time a fixture is added.
        XCTAssertEqual(Set(fixtures.map(\.name)).count, fixtures.count)

        for fixture in fixtures {
            XCTAssertTrue(ProgramDefinitionValidator.validate(fixture).isEmpty, fixture.name)
            let rows = try ProgramDefinitionPreview.rows(for: fixture)
            XCTAssertFalse(rows.isEmpty, fixture.name)
            let exercises = Dictionary(uniqueKeysWithValues: ids.map { ($0.value, Exercise(name: $0.key, primaryMuscles: [.quadriceps])) })
            let plan = try ProgramDefinitionCompiler.compile(fixture, exercisesByID: exercises)
            XCTAssertEqual(plan.sourceProgramDefinitionID, fixture.id)
            XCTAssertFalse(plan.orderedWeeks.isEmpty, fixture.name)
        }
    }

    // MARK: - Progression evaluator unit coverage (moved from ProgramEngineTypesTests)

    func testProgressionEvaluatorAppliesLinearSuccessAndFailureActions() throws {
        let rules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )
        ]
        let state = ProgressionEvaluationState(currentLoad: 100)
        let success = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: state
        )
        XCTAssertEqual(success.state.currentLoad, 102.5)
        XCTAssertEqual(success.recommendations.count, 1)
        XCTAssertEqual(success.recommendations.first?.applicationMode, .automatic)
        XCTAssertEqual(success.recommendations.first?.performance.completedSets, 3)

        let failure = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 2, didFail: true),
            state: state
        )
        XCTAssertEqual(failure.state.currentLoad, 100)
        XCTAssertEqual(failure.recommendations.first?.action, .repeatPrescription)
    }

    func testProgressionEvaluatorGeneratesRPERecommendationOnlyWhenAboveTarget() throws {
        let rule = ProgressionRuleDefinition(
            metric: .rpe,
            trigger: .actualRPEAboveTarget(tolerance: 1),
            successAction: .generateRecommendation,
            failureAction: .noChange,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .recommendation
        )

        let aboveTarget = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(targetRPE: 8, actualRPE: 9.5),
            state: ProgressionEvaluationState(currentLoad: 100)
        )
        XCTAssertEqual(aboveTarget.recommendations.count, 1)
        XCTAssertEqual(aboveTarget.recommendations.first?.action, .generateRecommendation)
        XCTAssertEqual(aboveTarget.recommendations.first?.applicationMode, .recommendation)

        let withinTolerance = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(targetRPE: 8, actualRPE: 8.5),
            state: ProgressionEvaluationState(currentLoad: 100)
        )
        XCTAssertTrue(withinTolerance.recommendations.isEmpty)
        XCTAssertEqual(withinTolerance.state.currentLoad, 100)
    }

    func testProgressionEvaluatorSupportsDoubleProgressionRecommendationAndVariationLadder() throws {
        let increaseRule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .allSetsReachedUpperRepBound,
            successAction: .addLoad(5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .recommendation
        )
        let variationRule = ProgressionRuleDefinition(
            metric: .exerciseVariation,
            trigger: .technicalQualityReached,
            successAction: .advanceExerciseVariation,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let firstVariation = UUID()
        let secondVariation = UUID()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [increaseRule, variationRule],
            performance: ProgressionPerformance(requiredSets: 3, upperBoundSets: 3, technicalQualityReached: true),
            state: ProgressionEvaluationState(currentLoad: 30, currentVariationExerciseID: firstVariation),
            variationLadder: [firstVariation, secondVariation]
        )

        XCTAssertEqual(result.state.currentLoad, 30)
        XCTAssertEqual(result.state.currentVariationExerciseID, secondVariation)
        XCTAssertEqual(result.recommendations.count, 2)
        let loadRecommendation = result.recommendations.first { $0.action == .addLoad(5) }
        XCTAssertEqual(loadRecommendation?.applicationMode, .recommendation)
    }

    func testProgressionEvaluatorSupportsTechnicalQualityRatio() throws {
        let rule = ProgressionRuleDefinition(
            metric: .technicalQuality,
            trigger: .successfulAttemptRatioReached(0.9),
            successAction: .advanceExerciseVariation,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let firstVariation = UUID()
        let secondVariation = UUID()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(successfulAttemptRatio: 0.9),
            state: ProgressionEvaluationState(currentVariationExerciseID: firstVariation),
            variationLadder: [firstVariation, secondVariation]
        )

        XCTAssertEqual(result.state.currentVariationExerciseID, secondVariation)
        XCTAssertEqual(result.recommendations.first?.action, .advanceExerciseVariation)
    }

    func testProgressionEvaluatorSupportsDurationDistanceAndRestProgression() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .duration, trigger: .allRequiredSetsCompleted, successAction: .addDuration(10), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .distance, trigger: .allRequiredSetsCompleted, successAction: .addDistance(100), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .restDuration, trigger: .allRequiredSetsCompleted, successAction: .reduceRestDuration(5), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .calories, trigger: .allRequiredSetsCompleted, successAction: .addCalories(25), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 1, completedSets: 1),
            state: ProgressionEvaluationState(durationOffset: 30, distanceOffset: 500, restDurationOffset: 10, caloriesOffset: 100)
        )

        XCTAssertEqual(result.state.durationOffset, 40)
        XCTAssertEqual(result.state.distanceOffset, 600)
        XCTAssertEqual(result.state.restDurationOffset, 5)
        XCTAssertEqual(result.state.caloriesOffset, 125)
    }

    func testProgressionEvaluatorSupportsCalorieThresholds() throws {
        let rule = ProgressionRuleDefinition(
            metric: .calories,
            trigger: .totalCaloriesReached(500),
            successAction: .addCalories(50),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(completedCalories: 525),
            state: ProgressionEvaluationState()
        )
        XCTAssertEqual(result.state.caloriesOffset, 50)
    }

    func testProgressionEvaluatorResetsFailureAndOffsets() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .load, trigger: .manualApproval, successAction: .resetFailureCount, cadence: .nextWorkout, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .load, trigger: .manualApproval, successAction: .resetProgressionOffsets, cadence: .nextWorkout, scope: .exerciseExposure, applicationMode: .automatic)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(manualApproval: true),
            state: ProgressionEvaluationState(repetitionOffset: 2, setCountOffset: 1, durationOffset: 30, distanceOffset: 100, restDurationOffset: 5, caloriesOffset: 100, failureCount: 3)
        )
        XCTAssertEqual(result.state.failureCount, 0)
        XCTAssertEqual(result.state.repetitionOffset, 0)
        XCTAssertEqual(result.state.distanceOffset, 0)
        XCTAssertEqual(result.state.caloriesOffset, 0)
    }

    func testProgressionEvaluatorPersistsRepAndSetVolumeOffsets() throws {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .weekCompleted,
            successAction: .addRepetitions(2),
            failureAction: .addSets(1),
            cadence: .nextWeek,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let state = ProgressionEvaluationState()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(weekCompleted: true),
            state: state
        )
        XCTAssertEqual(result.state.repetitionOffset, 2)
        XCTAssertEqual(result.state.setCountOffset, 0)
    }

    func testProgressionEvaluatorAdvancesWaveAndBlockState() throws {
        // Evaluated separately: advanceBlock deliberately resets the wave
        // index, so a combined evaluation's outcome depends on rule order.
        let waveResult = try ProgramProgressionEvaluator.evaluate(
            rules: [ProgressionRuleDefinition(metric: .load, trigger: .waveCompleted, successAction: .advanceWave, cadence: .nextWave, scope: .exerciseExposure, applicationMode: .automatic)],
            performance: ProgressionPerformance(waveCompleted: true),
            state: ProgressionEvaluationState()
        )
        XCTAssertEqual(waveResult.state.currentWaveIndex, 1)

        let blockResult = try ProgramProgressionEvaluator.evaluate(
            rules: [ProgressionRuleDefinition(metric: .load, trigger: .blockCompleted, successAction: .advanceBlock, cadence: .nextBlock, scope: .exerciseExposure, applicationMode: .automatic)],
            performance: ProgressionPerformance(blockCompleted: true),
            state: ProgressionEvaluationState(currentWaveIndex: 2)
        )
        XCTAssertEqual(blockResult.state.currentBlockIndex, 1)
        XCTAssertEqual(blockResult.state.currentWaveIndex, 0)
    }
}

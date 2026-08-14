import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentMultiTrialInterpreterTests: XCTestCase {
    func testSampleCreationRejectsEmptyAndNonFiniteTrials() {
        XCTAssertNil(MobilityAssessmentSample.create(from: []))
        XCTAssertNil(MobilityAssessmentSample.create(from: [12, .nan, 13]))
        XCTAssertNil(MobilityAssessmentSample.create(from: [12, .infinity]))
        XCTAssertNil(MobilityAssessmentSample.create(from: [-.infinity, 12]))
    }

    func testMultiTrialManualEntryAttachesSampleWithCountAndSpread() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        context.insert(definition)
        try context.save()

        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            using: context
        )

        let input = MobilityAssessmentResultInput(
            numericValue: 41.0,
            side: .left,
            isWarm: false,
            setupKey: definition.defaultSetupKey,
            method: definition.manualMode,
            unit: definition.unit,
            isActiveRange: definition.defaultIsActiveRange,
            day: session.day,
            trials: [40.0, 42.0, 41.0]
        )

        let result = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: input,
            using: context
        )

        let sample = try XCTUnwrap(result.sample)
        XCTAssertEqual(sample.sampleCount, 3)
        XCTAssertEqual(sample.minimum, 40.0)
        XCTAssertEqual(sample.maximum, 42.0)
        XCTAssertEqual(sample.median, 41.0)
        XCTAssertGreaterThan(sample.standardDeviation, 0.0)
    }

    func testMultiTrialInterpreterResolvesClearIncreaseWhenDeltaExceedsSpreadThreshold() throws {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let baseline = makeResultWithTrials(
            definition: definition,
            trials: [40.0, 42.0, 41.0],
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let retest = makeResultWithTrials(
            definition: definition,
            trials: [45.0, 47.0, 46.0],
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        let interpretation = MobilityAssessmentChangeInterpreter.interpret(
            current: retest,
            among: [baseline, retest]
        )

        XCTAssertEqual(
            interpretation,
            .clearIncrease(delta: 5.0, threshold: 2.0)
        )
    }

    func testMultiTrialInterpreterResolvesNoClearChangeWhenDeltaIsBelowSpreadThreshold() throws {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let baseline = makeResultWithTrials(
            definition: definition,
            trials: [40.0, 45.0, 42.0], // median 42, spread 5
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let retest = makeResultWithTrials(
            definition: definition,
            trials: [42.0, 46.0, 44.0], // median 44, spread 4
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        let interpretation = MobilityAssessmentChangeInterpreter.interpret(
            current: retest,
            among: [baseline, retest]
        )

        XCTAssertEqual(
            interpretation,
            .noClearChange(delta: 2.0, threshold: 5.0)
        )
    }

    func testSingleTrialManualEntryReturnsMeasurementUncertain() throws {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let baseline = makeResultWithTrials(
            definition: definition,
            trials: [41.0],
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let retest = makeResultWithTrials(
            definition: definition,
            trials: [47.0],
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        let interpretation = MobilityAssessmentChangeInterpreter.interpret(
            current: retest,
            among: [baseline, retest]
        )

        XCTAssertEqual(interpretation, .measurementUncertain)
    }

    func testWallSquatCriteriaAssessmentReturnsMeasurementUncertain() throws {
        let wallSquatSpec = MobilityAssessmentSeedData.definitions.first { $0.key == "mobility-assessment.wall-squat" }!
        let definition = wallSquatSpec.makeDefinition()

        let baseline = MobilityAssessmentResult(
            definition: definition,
            input: MobilityAssessmentResultInput(
                criteria: .allCriteriaObserved,
                side: .combined,
                isWarm: false,
                setupKey: definition.defaultSetupKey,
                method: definition.manualMode,
                unit: .criteria,
                isActiveRange: definition.defaultIsActiveRange,
                day: LocalDay(rawValue: "2026-07-29")
            ),
            orderIndex: 0,
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let retest = MobilityAssessmentResult(
            definition: definition,
            input: MobilityAssessmentResultInput(
                criteria: .someCriteriaObserved,
                side: .combined,
                isWarm: false,
                setupKey: definition.defaultSetupKey,
                method: definition.manualMode,
                unit: .criteria,
                isActiveRange: definition.defaultIsActiveRange,
                day: LocalDay(rawValue: "2026-07-29")
            ),
            orderIndex: 0,
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        let interpretation = MobilityAssessmentChangeInterpreter.interpret(
            current: retest,
            among: [baseline, retest]
        )

        XCTAssertEqual(interpretation, .measurementUncertain)
    }

    func testKneeToWallDorsiflexionPolarityResolvesIncreaseWithLargerDistance() throws {
        let kneeToWallSpec = MobilityAssessmentSeedData.definitions.first { $0.key == "mobility-assessment.knee-to-wall-dorsiflexion" }!
        let definition = kneeToWallSpec.makeDefinition()

        let baseline = makeResultWithTrials(
            definition: definition,
            trials: [10.0, 11.0, 10.5], // median 10.5, spread 1.0
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let retest = makeResultWithTrials(
            definition: definition,
            trials: [14.0, 15.0, 14.5], // median 14.5, spread 1.0
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        XCTAssertEqual(
            MobilityAssessmentValuePolarity.of("mobility-assessment.knee-to-wall-dorsiflexion"),
            .increasesWithRange
        )

        let interpretation = MobilityAssessmentChangeInterpreter.interpret(
            current: retest,
            among: [baseline, retest]
        )

        XCTAssertEqual(
            interpretation,
            .clearIncrease(delta: 4.0, threshold: 1.0)
        )
    }

    private func makeResultWithTrials(
        definition: MobilityAssessmentDefinition,
        trials: [Double],
        createdAt: Date
    ) -> MobilityAssessmentResult {
        let sorted = trials.sorted()
        let median = sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        let input = MobilityAssessmentResultInput(
            numericValue: median,
            side: definition.supportedSides[0],
            isWarm: false,
            setupKey: definition.defaultSetupKey,
            method: definition.manualMode,
            unit: definition.unit,
            isActiveRange: definition.defaultIsActiveRange,
            day: LocalDay(rawValue: "2026-07-29"),
            trials: trials
        )
        let result = MobilityAssessmentResult(
            definition: definition,
            input: input,
            orderIndex: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        if let sample = MobilityAssessmentSample.create(from: trials, createdAt: createdAt) {
            sample.result = result
            result.sample = sample
        }
        return result
    }
}

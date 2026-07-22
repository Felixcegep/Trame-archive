import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ContextualTrackingAndLoadedMobilityTests: XCTestCase {
    func testTrackingTypeOverrideAndStimulusSnapshot() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(
            name: "Jefferson Curl",
            primaryMuscles: [.hamstrings],
            trackingType: .weightAndReps,
            isCustom: true
        )
        context.insert(exercise)

        let templateItem = TemplateExercise(
            exercise: exercise,
            order: 0,
            targetSets: 3,
            repRangeMinimum: 5,
            repRangeMaximum: 5,
            trackingTypeOverride: .duration
        )
        XCTAssertEqual(templateItem.resolvedTrackingType, .duration)

        let plannedItem = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            targetSets: 3,
            repRangeMinimum: 5,
            repRangeMaximum: 5,
            stimulus: .mobility,
            trackingTypeOverride: .repsOnly
        )
        XCTAssertEqual(plannedItem.resolvedTrackingType, .repsOnly)
        XCTAssertEqual(plannedItem.resolvedStimulus, .mobility)

        let entryFromPlanned = ExerciseEntry(from: plannedItem, orderIndex: 0, usedMetric: .metric)
        XCTAssertEqual(entryFromPlanned.trackingTypeSnapshot, .repsOnly)
        XCTAssertEqual(entryFromPlanned.stimulusSnapshot, .mobility)
    }

    func testTrackingProfileValidator() {
        let exercise = Exercise(name: "Test", primaryMuscles: [.upperChest], trackingType: .weightAndReps, isCustom: true)
        
        let valid = TrackingProfileValidator.validate(stimulus: .mobility, trackingType: .weightAndReps, exercise: exercise)
        if case .failure = valid { XCTFail("Expected success") }

        let invalid = TrackingProfileValidator.validate(stimulus: .hypertrophy, trackingType: .calories, exercise: exercise)
        if case let .failure(error) = invalid {
            XCTAssertEqual(error, TrackingProfileValidationError.invalidCombination(stimulus: .hypertrophy, trackingType: .calories))
        } else {
            XCTFail("Expected failure")
        }
    }

    func testLoadedMobilityPrescriptionAndResult() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let def = MobilityDefinition(name: "Loaded Jefferson Curl", trackingType: .repetitions, defaultDurationSeconds: nil, defaultRepetitions: 5)
        let item = MobilityRoutineItem(
            definition: def,
            orderIndex: 0,
            targetRepetitions: 5,
            targetLoadValue: 10.0,
            targetLoadUnit: .kilograms,
            side: .bilateral
        )
        let routine = MobilityRoutine(name: "Loaded Stretch")
        routine.items = [item]
        context.insert(def)
        context.insert(routine)
        try context.save()

        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        let entry = try XCTUnwrap(session.entries.first)
        XCTAssertEqual(entry.prescribedLoadValue, 10.0)
        XCTAssertEqual(entry.prescribedLoadUnit, .kilograms)

        let resultInput = MobilityResultInput(
            performedDurationSeconds: nil,
            performedRepetitions: 5,
            performedLoadValue: 12.5,
            performedLoadUnit: .kilograms,
            perceivedIntensity: 3,
            discomfortNote: nil
        )
        let resultID = try XCTUnwrap(entry.results.first?.id)
        XCTAssertTrue(MobilitySessionService.completeCurrent(in: session, resultInputs: [resultID: resultInput], using: context))

        let completedResult = try XCTUnwrap(entry.results.first)
        XCTAssertEqual(completedResult.performedLoadValue, 12.5)
        XCTAssertEqual(completedResult.performedLoadUnit, .kilograms)
    }

    func testPNFPhasesPrescriptionAndSnapshot() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let def = MobilityDefinition(name: "Hamstring PNF", trackingType: .duration, defaultDurationSeconds: 20, defaultRepetitions: nil)
        let item = MobilityRoutineItem(
            definition: def,
            orderIndex: 0,
            targetDurationSeconds: 20,
            side: .bilateral
        )
        item.cycleCount = 3
        let p1 = MobilityPhasePrescription(orderIndex: 0, phaseType: .initialStretch, durationSeconds: 20)
        let p2 = MobilityPhasePrescription(orderIndex: 1, phaseType: .contraction, durationSeconds: 6, contractionIntensity: .moderate)
        let p3 = MobilityPhasePrescription(orderIndex: 2, phaseType: .relax, durationSeconds: 3)
        let p4 = MobilityPhasePrescription(orderIndex: 3, phaseType: .deeperStretch, durationSeconds: 20)
        item.phases = [p1, p2, p3, p4]

        let routine = MobilityRoutine(name: "PNF Protocol")
        routine.items = [item]
        context.insert(def)
        context.insert(routine)
        try context.save()

        XCTAssertEqual(item.phases.count, 4)
        XCTAssertEqual(item.cycleCount, 3)
    }
}

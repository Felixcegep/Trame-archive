import XCTest
@testable import GymTracker

final class WorkoutSetCompletionValidatorTests: XCTestCase {
    func testRequiredMetricsRejectNonFiniteAndNonPositiveValues() {
        let cases: [(TrackingType, Float, Float, TimeInterval?, Float?, Double?, WorkoutSetCompletionValidator.InvalidReason)] = [
            (.repsOnly, .nan, 0, nil, nil, nil, .missingRepetitions),
            (.weightAndReps, 5, .infinity, nil, nil, nil, .missingLoad),
            (.duration, 0, 0, -.infinity, nil, nil, .missingDuration),
            (.durationAndDistance, 0, 0, 60, .nan, nil, .missingDistance),
            (.calories, 0, 0, nil, nil, 0, .missingCalories)
        ]

        for (trackingType, repetitions, load, duration, distance, calories, expected) in cases {
            let result = WorkoutSetCompletionValidator.validate(.init(
                trackingType: trackingType,
                repetitions: repetitions,
                load: load,
                duration: duration,
                distance: distance,
                calories: calories,
                completionRule: trackingType == .weightAndReps
                    ? .all([.repetitions, .load])
                    : nil
            ))

            XCTAssertEqual(result.firstInvalidReason, expected, "Unexpected result for \(trackingType)")
        }
    }

    func testFinitePositiveRequiredMetricsRemainValid() {
        XCTAssertTrue(WorkoutSetCompletionValidator.validate(.init(
            trackingType: .weightAndReps,
            repetitions: 5,
            load: 100,
            duration: nil,
            distance: nil,
            calories: nil
        )).isValid)
        XCTAssertTrue(WorkoutSetCompletionValidator.validate(.init(
            trackingType: .durationAndDistance,
            repetitions: 0,
            duration: 300,
            distance: 1_000,
            calories: nil
        )).isValid)
    }
}

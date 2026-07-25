import Foundation
import XCTest
@testable import GymTracker

/// Whole-row selection in Active Workout: tapping an unfinished set row must
/// land on the value the lifter still owes, without writing or inferring one.
@MainActor
final class SetInputFocusSelectionTests: XCTestCase {
    func testEmptySetFocusesTheFirstTrackedField() {
        let set = ExerciseSet(usedMetric: .metric)

        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: set, for: .weightAndReps),
            .repetitions
        )
    }

    func testSetWithRepsFocusesTheMissingLoad() {
        let set = ExerciseSet(repetitions: 8, weight: 0, usedMetric: .metric)

        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: set, for: .weightAndReps),
            .weight
        )
    }

    func testFullySuppliedSetFallsBackToTheFirstField() {
        let set = ExerciseSet(repetitions: 8, weight: 50, usedMetric: .metric)

        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: set, for: .weightAndReps),
            .repetitions
        )
    }

    /// Load never blocks completion, so a required empty value outranks it even
    /// when it appears later in the row.
    func testRequiredValueOutranksAnEarlierOptionalLoad() {
        let set = ExerciseSet(repetitions: 0, weight: 50, usedMetric: .metric)

        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: set, for: .weightAndReps),
            .repetitions
        )
    }

    func testDurationAndDistanceSetsFocusTheirOwnMissingValues() {
        let missingDuration = ExerciseSet(duration: nil, distance: 400, usedMetric: .metric)
        let missingDistance = ExerciseSet(duration: 60, distance: nil, usedMetric: .metric)

        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: missingDuration, for: .durationAndDistance),
            .duration
        )
        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: missingDistance, for: .durationAndDistance),
            .distance
        )
    }

    func testCalorieSetFocusesCalories() {
        let set = ExerciseSet(calories: nil, usedMetric: .metric)

        XCTAssertEqual(
            SetInputCoordinator.firstMissingField(in: set, for: .calories),
            .calories
        )
    }

    /// Choosing focus must not touch performed truth: an untouched value stays
    /// untouched so it keeps presenting as "—" rather than becoming a zero.
    func testChoosingFocusLeavesTheSetUnchanged() {
        let set = ExerciseSet(repetitions: 8, weight: 0, usedMetric: .metric)

        _ = SetInputCoordinator.firstMissingField(in: set, for: .weightAndReps)

        XCTAssertEqual(set.repetitions, 8)
        XCTAssertEqual(set.weight, 0)
        XCTAssertNil(set.duration)
        XCTAssertNil(set.distance)
        XCTAssertNil(set.calories)
        XCTAssertFalse(set.done)
    }
}

import Foundation
import XCTest
@testable import GymTracker

/// The two pure decisions behind adapting set entry to an exercise's tracking
/// type: what the panel calls the values it is collecting, and which durations
/// the timed keypad offers.
@MainActor
final class TrackingTypeInputPresentationTests: XCTestCase {

    // MARK: - Logging orientation

    /// Weight and reps, and calories, name themselves through their value
    /// captions. A phrase repeating them above the same numbers is the
    /// repetition the panel deliberately does not print.
    func testFamiliarTrackingTypesHaveNoOrientationLine() {
        XCTAssertNil(TrackingType.weightAndReps.loggingOrientation)
        XCTAssertNil(TrackingType.calories.loggingOrientation)
    }

    func testTrackingTypesThatChangeTheMeaningOfAFieldAreNamed() {
        for type in [
            TrackingType.repsOnly,
            .weightedBodyweight,
            .assistedBodyweight,
            .duration,
            .durationAndDistance
        ] {
            XCTAssertNotNil(
                type.loggingOrientation,
                "\(type.rawValue) drops or redefines a value field and must say so"
            )
        }
    }

    // MARK: - Duration presets

    func testUnprescribedTimedSetKeepsTheStandardShortlist() {
        XCTAssertEqual(
            DurationKeypad.presets(including: nil),
            DurationKeypad.defaultPresets
        )
        XCTAssertEqual(
            DurationKeypad.presets(including: 0),
            DurationKeypad.defaultPresets
        )
    }

    func testPrescribedHoldAlreadyOnTheGridChangesNothing() {
        XCTAssertEqual(
            DurationKeypad.presets(including: 60),
            DurationKeypad.defaultPresets
        )
    }

    /// The prescribed hold takes the place of the preset furthest from it, so
    /// the target is one press away and the neighbours a lifter would reach for
    /// instead stay on the grid.
    func testPrescribedHoldReplacesTheFurthestPreset() {
        XCTAssertEqual(
            DurationKeypad.presets(including: 40),
            [30, 40, 45, 60, 75, 90]
        )
        XCTAssertEqual(
            DurationKeypad.presets(including: 300),
            [45, 60, 75, 90, 120, 300]
        )
    }

    /// The keypad lays its presets out in a fixed 3 × 2 grid and reads left to
    /// right by duration, so the count and the order are contracts.
    func testPresetsStaySixKeysInAscendingOrder() {
        for target in stride(from: 5.0, through: 300.0, by: 5.0) {
            let presets = DurationKeypad.presets(including: target)
            XCTAssertEqual(presets.count, 6, "target \(target)")
            XCTAssertEqual(presets, presets.sorted(), "target \(target)")
            XCTAssertTrue(presets.contains(target), "target \(target)")
        }
    }
}

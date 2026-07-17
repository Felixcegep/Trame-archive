import XCTest
@testable import GymTracker

final class VolumeCalculatorTests: XCTestCase {
    func testBilateralTotalLoadBaselineMatchesSimpleRepsTimesWeight() {
        let volume = VolumeCalculator.setVolume(
            weight: 100,
            weightType: .kg,
            repetitions: 10,
            semantics: .default,
            in: .kg
        )
        XCTAssertEqual(volume, 1_000, accuracy: 0.01)
    }

    func testUnilateralPerSideDoublesVolume() {
        let semantics = LoggingSemantics(
            laterality: .unilateral,
            repCountingStyle: .perSide,
            weightEntryStyle: .totalLoad,
            loadUnitCount: 1
        )
        let volume = VolumeCalculator.setVolume(
            weight: 50,
            weightType: .kg,
            repetitions: 10,
            semantics: semantics,
            in: .kg
        )
        XCTAssertEqual(volume, 1_000, accuracy: 0.01)
    }

    func testPerLoadUnitDoublesVolume() {
        let semantics = LoggingSemantics(
            laterality: .bilateral,
            repCountingStyle: .total,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        let volume = VolumeCalculator.setVolume(
            weight: 50,
            weightType: .kg,
            repetitions: 10,
            semantics: semantics,
            in: .kg
        )
        XCTAssertEqual(volume, 1_000, accuracy: 0.01)
    }

    func testCombinedUnilateralPerSideAndPerLoadUnitQuadruplesVolume() {
        // e.g. a dumbbell Bulgarian split squat: reps logged for one leg,
        // weight logged per dumbbell.
        let semantics = LoggingSemantics(
            laterality: .unilateral,
            repCountingStyle: .perSide,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        let volume = VolumeCalculator.setVolume(
            weight: 25,
            weightType: .kg,
            repetitions: 10,
            semantics: semantics,
            in: .kg
        )
        XCTAssertEqual(volume, 1_000, accuracy: 0.01)
    }

    func testConvertsWeightUnitBeforeApplyingMultipliers() {
        let semantics = LoggingSemantics(
            laterality: .bilateral,
            repCountingStyle: .total,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        let volumeInLbs = VolumeCalculator.setVolume(
            weight: 50,
            weightType: .kg,
            repetitions: 10,
            semantics: semantics,
            in: .lbs
        )
        let expected = UnitConversion.weight(50, from: .kg, to: .lbs) * 10 * 2
        XCTAssertEqual(volumeInLbs, expected, accuracy: 0.01)
    }
}

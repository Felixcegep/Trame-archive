import XCTest
@testable import GymTracker

@MainActor
final class WorkoutLoadRoundingTests: XCTestCase {
    func testBarbellKilogramsToPoundsRoundsToFivePoundGrid() {
        let exercise = makeExercise(equipment: .barbell, resistance: .externalWeight, plateLoaded: true)

        XCTAssertEqual(
            WorkoutLoadRounding.converted(50, from: .kg, to: .lbs, for: exercise),
            110,
            accuracy: 0.001
        )
    }

    func testSameUnitConversionPreservesTypedPrecision() {
        let exercise = makeExercise(equipment: .barbell, resistance: .externalWeight, plateLoaded: true)

        XCTAssertEqual(
            WorkoutLoadRounding.converted(2.5, from: .kg, to: .kg, for: exercise),
            2.5,
            accuracy: 0.001
        )
    }

    func testCableAndWeightedBodyweightUseTheirEquipmentGrid() {
        let cable = makeExercise(equipment: .cable, resistance: .machine, plateLoaded: false)
        let weightedBodyweight = makeExercise(equipment: .bodyweight, resistance: .weightedBodyweight, plateLoaded: false)

        XCTAssertEqual(
            WorkoutLoadRounding.converted(50, from: .kg, to: .lbs, for: cable),
            110,
            accuracy: 0.001
        )
        XCTAssertEqual(
            WorkoutLoadRounding.converted(20, from: .kg, to: .lbs, for: weightedBodyweight),
            45,
            accuracy: 0.001
        )
    }

    func testUnknownEquipmentLeavesCrossUnitPrecisionUnchanged() {
        let exercise = makeExercise(equipment: .other, resistance: .externalWeight, plateLoaded: false)
        let converted = UnitConversion.weight(50, from: .kg, to: .lbs)

        XCTAssertEqual(
            WorkoutLoadRounding.converted(50, from: .kg, to: .lbs, for: exercise),
            converted,
            accuracy: 0.001
        )
    }

    func testNormalizerRoundsWhenIncrementIsSuppliedAndPreservesLegacyNilBehavior() {
        let roundedSet = ExerciseSet(weight: 50, usedMetric: .metric)
        XCTAssertTrue(WorkoutSetInputNormalizer.synchronize(
            roundedSet,
            to: .imperial,
            loadIncrement: 5
        ))
        XCTAssertEqual(roundedSet.weight, 110, accuracy: 0.001)

        let unroundedSet = ExerciseSet(weight: 50, usedMetric: .metric)
        XCTAssertTrue(WorkoutSetInputNormalizer.synchronize(
            unroundedSet,
            to: .imperial,
            loadIncrement: nil
        ))
        XCTAssertEqual(
            unroundedSet.weight,
            UnitConversion.weight(50, from: .kg, to: .lbs),
            accuracy: 0.001
        )
    }

    func testStepperIncrementProducesAStableCoarseGrid() {
        let exercise = makeExercise(equipment: .barbell, resistance: .externalWeight, plateLoaded: true)
        let increment = WorkoutLoadRounding.stepperIncrement(for: exercise, unit: .lbs)

        XCTAssertEqual(increment, 5, accuracy: 0.001)
        XCTAssertEqual((0..<3).map { 110 + Double($0) * increment }, [110, 115, 120])
    }

    private func makeExercise(
        equipment: EquipmentType,
        resistance: ResistanceType,
        plateLoaded: Bool
    ) -> Exercise {
        Exercise(
            name: "Rounding Fixture",
            primaryMuscles: [.middleChest],
            equipmentType: equipment,
            resistanceType: resistance,
            isPlateLoaded: plateLoaded
        )
    }
}

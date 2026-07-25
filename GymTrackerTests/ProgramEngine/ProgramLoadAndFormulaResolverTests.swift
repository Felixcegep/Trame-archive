import Foundation
import XCTest
@testable import GymTracker

/// Pure unit coverage for `ProgramLoadResolver`, `EquipmentLoadRounding`, and
/// `ProgramFormulaResolver` — split out of the former ProgramEngineTypesTests
/// grab-bag so load/formula resolution has a single, clearly-named home.
final class ProgramLoadAndFormulaResolverTests: XCTestCase {

    func testLoadResolverExplainsTrainingMaxAndRoundsForEquipment() throws {
        var context = LoadResolutionContext()
        context.trainingMaxByExposure["squat"] = 108
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: LoadReference(kind: .trainingMax, exposureKey: "squat"),
                percentage: 0.85,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )

        XCTAssertEqual(result.referenceValue, 108)
        XCTAssertEqual(result.unroundedLoad ?? 0, 91.8, accuracy: 0.0001)
        XCTAssertEqual(result.prescribedLoad ?? 0, 92.5, accuracy: 0.0001)
        XCTAssertTrue(result.explanation.contains("85%"))
        XCTAssertTrue(result.explanation.contains("92.5"))
    }

    func testEquipmentDefaultsRoundInTheWorkoutUnitAndPreserveBodyweight() {
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                91.8,
                equipment: .barbell,
                resistance: .externalWeight,
                isPlateLoaded: true,
                unit: .kg
            )?.prescribedLoad ?? 0,
            92.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                31.1,
                equipment: .dumbbell,
                resistance: .externalWeight,
                isPlateLoaded: false,
                unit: .kg
            )?.prescribedLoad ?? 0,
            32,
            accuracy: 0.001
        )
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                83.2,
                equipment: .cable,
                resistance: .machine,
                isPlateLoaded: false,
                unit: .lbs
            )?.prescribedLoad ?? 0,
            85,
            accuracy: 0.001
        )
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                37.4,
                equipment: .bodyweight,
                resistance: .assistedBodyweight,
                isPlateLoaded: false,
                unit: .kg
            )?.prescribedLoad ?? 0,
            37.5,
            accuracy: 0.001
        )
        XCTAssertNil(EquipmentLoadRounding.round(
            37.4,
            equipment: .bodyweight,
            resistance: .bodyweight,
            isPlateLoaded: false,
            unit: .kg
        ))
    }

    func testLoadResolverSupportsTopSetBackOffAndMissingReferences() throws {
        var context = LoadResolutionContext()
        context.completedTopSetByExposure["bench-strength"] = 150
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: LoadReference(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )
        XCTAssertEqual(result.prescribedLoad ?? 0, 135, accuracy: 0.0001)

        XCTAssertThrowsError(try ProgramLoadResolver.resolve(
            LoadPrescription(reference: LoadReference(kind: .trainingMax, exposureKey: "deadlift"), percentage: 0.8),
            context: context
        )) { error in
            XCTAssertEqual(error as? LoadResolutionError, .missingReference(.trainingMax))
        }
    }

    func testLoadResolverSupportsActualOneRepMaxReference() throws {
        var context = LoadResolutionContext()
        context.actualOneRepMaxByExposure["clean"] = 120
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: .init(kind: .exerciseOneRepMax, exposureKey: "clean"),
                percentage: 1.1,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )
        // 120 × 1.1 = 132.0; the nearest 2.5 increment is 132.5, not 130.
        XCTAssertEqual(result.prescribedLoad ?? 0, 132.5, accuracy: 0.0001)
    }

    func testFormulaResolverSupportsCrossExposureAndSafeDivision() throws {
        var context = FormulaResolutionContext()
        context.trainingMaxByExposure["squat"] = 200
        context.valuesByExposure["offset"] = 5
        let formula: ProgressionFormula = .round(
            .add(
                .multiply(.source(.trainingMax(exposureKey: "squat")), .source(.constant(0.85))),
                .source(.anotherExposure(exposureKey: "offset"))
            ),
            rule: .nearestIncrement(2.5)
        )
        XCTAssertEqual(try ProgramFormulaResolver.resolve(formula, context: context), 175)
        XCTAssertThrowsError(try ProgramFormulaResolver.resolve(
            .divide(.source(.constant(10)), .source(.constant(0))),
            context: context
        )) { error in
            XCTAssertEqual(error as? FormulaResolutionError, .divisionByZero)
        }
    }
}

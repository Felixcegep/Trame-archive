import Foundation
import XCTest
@testable import GymTracker

/// Pure plate-loading math: calculating a per-side plate breakdown for a
/// target weight, manually composing/removing plates, and grouping plates
/// for the diagram. No persistence involved.
@MainActor
final class PlateMathTests: XCTestCase {
    func testPlateCalculatorUsesDescendingPerSidePlatesFor215Pounds() {
        let calculation = PlateCalculation(
            target: 215,
            barWeight: 45,
            plates: [55, 45, 35, 25, 10, 5, 2.5]
        )

        XCTAssertEqual(calculation.plates, [55, 25, 5])
        XCTAssertEqual(calculation.totalWeight, 215, accuracy: 0.001)
        XCTAssertEqual(calculation.perSideWeight, 107.5, accuracy: 0.001)
        XCTAssertEqual(calculation.remainingWeight, 0, accuracy: 0.001)
    }

    func testPlateCalculatorKeepsBareBarAndClosestLoadStatesDeterministic() {
        let bare = PlateCalculation(target: 45, barWeight: 45, plates: [55, 25, 5])
        XCTAssertEqual(bare.plates, [])
        XCTAssertEqual(bare.totalWeight, 45)

        let closest = PlateCalculation(target: 212.5, barWeight: 45, plates: [55, 25, 5])
        XCTAssertGreaterThan(closest.remainingWeight, 0)
        XCTAssertLessThan(closest.totalWeight, 212.5)
    }

    func testManualPlateCompositionPreservesChosenDenominationsAndOrder() {
        var composition = PlateLoadComposition()
        composition.add(25)
        composition.add(20)
        composition.add(15)

        XCTAssertEqual(composition.plates, [25, 20, 15])
        XCTAssertEqual(composition.totalWeight(barWeight: 20), 140)

        composition.remove(20)
        XCTAssertEqual(composition.plates, [25, 15])
        XCTAssertEqual(composition.totalWeight(barWeight: 20), 100)
    }

    func testManualPlateCompositionRemovesOnlyOneMatchingPlate() {
        var composition = PlateLoadComposition(plates: [25, 25, 10])

        composition.remove(25)

        XCTAssertEqual(composition.plates, [25, 10])
        XCTAssertEqual(composition.totalWeight(barWeight: 20), 90)
    }

    func testPlateDiagramGroupsLargeRepeatedLoadsWithoutChangingTheirMeaning() {
        let plates = Array(repeating: Float(25), count: 20)

        let items = PlateDiagramLayout.items(for: plates)

        XCTAssertEqual(items, [DiagramPlate(weight: 25, count: 20, occurrence: 0)])
    }

    func testPlateDiagramKeepsNormalAndMixedManualLoadsInOrder() {
        let normal = PlateDiagramLayout.items(for: [25, 25, 10, 2.5])
        XCTAssertEqual(normal.map(\.weight), [25, 25, 10, 2.5])
        XCTAssertTrue(normal.allSatisfy { $0.count == 1 })

        let largeMixed = PlateDiagramLayout.items(for: [25, 25, 20, 20, 15, 15, 10, 10, 5])
        XCTAssertEqual(largeMixed.map(\.weight), [25, 20, 15, 10, 5])
        XCTAssertEqual(largeMixed.map(\.count), [2, 2, 2, 2, 1])
    }

    func testDefaultPlateCatalogIncludesFiftyFivePoundAndTwentyFiveKilogramPlates() {
        XCTAssertEqual(Constants.Barbell.imperialPlates.first, 55)
        XCTAssertTrue(Constants.Barbell.imperialPlates.contains(55))
        XCTAssertEqual(Constants.Barbell.metricPlates.first, 25)
        XCTAssertTrue(Constants.Barbell.metricPlates.contains(25))
        XCTAssertEqual(EquipmentPresets.standardImperialPlatePairsLbs.first, 55.0)
    }
}

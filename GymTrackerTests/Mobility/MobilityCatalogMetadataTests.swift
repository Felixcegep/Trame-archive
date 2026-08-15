import Foundation
import XCTest
@testable import GymTracker

final class MobilityCatalogMetadataTests: XCTestCase {
    func testMobilityMetadataPreservesLosslessSourceTaxonomy() {
        let definition = MobilityDefinition(name: "Catalog Movement")
        let metadata = CatalogDefinitionMetadata(
            definitionID: definition.id,
            definitionKind: .mobilityDefinition,
            catalogueKey: "stretch.catalog-movement"
        )
        metadata.sourceReferences = [CatalogSourceReference(sourceID: "free-exercise-db")]
        metadata.categoryRaw = "Stretching"
        metadata.difficultyRaw = "All Levels"
        metadata.equipmentLabels = ["Bodyweight / Mat"]
        metadata.primaryMuscleLabels = ["hamstrings"]
        metadata.secondaryMuscleLabels = ["calves"]
        metadata.sanskritName = "Adho Mukha Svanasana"
        metadata.metValue = 2.5
        metadata.benefitsText = "Improves mobility."
        metadata.imageURLString = "https://example.com/movement.jpg"
        metadata.svgURLString = "https://example.com/movement.svg"

        XCTAssertEqual(metadata.definitionID, definition.id)
        XCTAssertEqual(metadata.definitionKind, .mobilityDefinition)
        XCTAssertEqual(metadata.sourceReferences, [CatalogSourceReference(sourceID: "free-exercise-db")])
        XCTAssertEqual(metadata.difficultyRaw, "All Levels")
        XCTAssertEqual(metadata.equipmentLabels, ["Bodyweight / Mat"])
        XCTAssertEqual(metadata.metValue, 2.5)
        XCTAssertEqual(metadata.svgURLString, "https://example.com/movement.svg")
    }
}

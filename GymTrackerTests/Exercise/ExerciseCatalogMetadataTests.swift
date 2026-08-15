import Foundation
import XCTest
@testable import GymTracker

final class ExerciseCatalogMetadataTests: XCTestCase {
    func testExerciseMetadataStartsAbsentOrEmptyWithoutChangingExerciseShape() {
        let exercise = Exercise(name: "Catalog Exercise", primaryMuscles: [.quadriceps])
        let metadata = CatalogDefinitionMetadata(
            definitionID: exercise.id,
            definitionKind: .exercise,
            catalogueKey: "exercise.catalog-exercise"
        )

        XCTAssertEqual(metadata.definitionID, exercise.id)
        XCTAssertEqual(metadata.definitionKind, .exercise)
        XCTAssertNil(metadata.sourceReferencesData)
        XCTAssertTrue(metadata.sourceReferences.isEmpty)
        XCTAssertTrue(metadata.muscleGroups.isEmpty)
        XCTAssertTrue(metadata.anatomicalTargetMuscles.isEmpty)
        XCTAssertTrue(metadata.anatomicalSynergistMuscles.isEmpty)
        XCTAssertNil(metadata.descriptionText)
        XCTAssertTrue(metadata.instructionSteps.isEmpty)
        XCTAssertNil(metadata.liftosaurSlug)
    }

    func testExerciseMetadataPreservesTypedSourcesAndLosslessLabels() {
        let source = CatalogSourceReference(
            sourceID: "liftosaur",
            label: "Liftosaur",
            url: "https://liftosaur.com/exercise/example",
            contentVersion: "2026-08"
        )
        let metadata = CatalogDefinitionMetadata(
            definitionID: UUID(),
            definitionKind: .exercise,
            catalogueKey: "exercise.catalog-exercise"
        )
        metadata.sourceReferences = [source]
        metadata.muscleGroups = ["Legs"]
        metadata.anatomicalTargetMuscles = ["Vastus medialis"]
        metadata.anatomicalSynergistMuscles = ["Gluteus maximus"]
        metadata.descriptionText = "A catalog description."
        metadata.instructionSteps = ["Set up", "Perform"]
        metadata.liftosaurSlug = "catalog-exercise"

        XCTAssertEqual(metadata.sourceReferences, [source])
        XCTAssertEqual(metadata.muscleGroups, ["Legs"])
        XCTAssertEqual(metadata.anatomicalTargetMuscles, ["Vastus medialis"])
        XCTAssertEqual(metadata.anatomicalSynergistMuscles, ["Gluteus maximus"])
        XCTAssertEqual(metadata.instructionSteps, ["Set up", "Perform"])
        XCTAssertEqual(metadata.liftosaurSlug, "catalog-exercise")
    }
}

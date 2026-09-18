import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class OlympicWeightliftingCatalogTests: XCTestCase {
    func testBundledBarbellOlympicLiftsAuthorWeightliftingDiscipline() throws {
        let catalog = try CatalogResourceDecoder.decodeBundled()
        let byName = Dictionary(uniqueKeysWithValues: catalog.exercises.map { ($0.name, $0) })

        let required = [
            "Snatch": "Arraché",
            "Clean": "Épaulé",
            "Clean and Jerk": "Épaulé-jeté",
            "Power Snatch": "Arraché puissance",
            "Power Clean": "Épaulé puissance",
            "Hang Snatch": "Arraché en suspension",
            "Hang Clean": "Épaulé en suspension",
            "Muscle Snatch": "Arraché force",
            "Muscle Clean": "Épaulé force",
            "Split Jerk": "Jeté en fente",
            "Power Jerk": "Jeté puissance",
            "Push Jerk": "Jeté force",
            "Block Snatch": "Arraché des plots",
            "Block Clean": "Épaulé des plots",
            "Snatch Deadlift": "Soulevé de terre arraché",
            "Behind The Neck Jerk": "Jeté nuque",
            "Jerk Balance": "Chute de jeté",
            "High-Hang Clean": "Épaulé suspension haute"
        ]

        for (name, frenchName) in required {
            let exercise = try XCTUnwrap(byName[name], "Missing bundled exercise \(name)")
            XCTAssertEqual(exercise.sportDiscipline, SportDiscipline.olympicWeightlifting.rawValue, name)
            XCTAssertEqual(exercise.frenchName, frenchName, name)
            XCTAssertTrue(
                exercise.tags.contains(where: { $0.caseInsensitiveCompare("olympic-weightlifting") == .orderedSame }),
                name
            )
        }

        let kettlebellSnatch = try XCTUnwrap(byName["Kettlebell Snatch"])
        let axle = try XCTUnwrap(byName["Axle Clean and Press"])
        XCTAssertNil(kettlebellSnatch.sportDiscipline)
        XCTAssertFalse(kettlebellSnatch.tags.contains("olympic-weightlifting"))
        XCTAssertEqual(axle.sportDiscipline, SportDiscipline.strongman.rawValue)
    }

    func testCopenhagenPlankIsAnAdductorHoldNotWeightlifting() throws {
        let catalog = try CatalogResourceDecoder.decodeBundled()
        let plank = try XCTUnwrap(catalog.exercises.first { $0.name == "Copenhagen Plank" })

        XCTAssertEqual(plank.frenchName, "Planche de Copenhague")
        XCTAssertEqual(plank.laterality, "Unilateral")
        XCTAssertEqual(plank.trackingType, "duration")
        XCTAssertEqual(plank.movementPattern, "antiLateralFlexion")
        XCTAssertNil(plank.sportDiscipline)
        XCTAssertFalse(plank.tags.contains("olympic-weightlifting"))
        XCTAssertTrue(plank.searchAliases.contains("copenhagen adduction"))
    }

    func testInstallerWritesFrenchNamesLateralityAndNewLifts() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let catalog = try CatalogResourceDecoder.decodeBundled()
        _ = try CatalogMetadataInstaller.seedDefinitions(
            catalog,
            in: context,
            registry: SystemSeedRegistry(context: context)
        )
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let snatch = try XCTUnwrap(exercises.first { $0.name == "Snatch" })
        let pushJerk = try XCTUnwrap(exercises.first { $0.name == "Push Jerk" })
        let plank = try XCTUnwrap(exercises.first { $0.name == "Copenhagen Plank" })

        XCTAssertEqual(snatch.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(snatch.frenchName, "Arraché")
        XCTAssertEqual(pushJerk.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(pushJerk.frenchName, "Jeté force")
        XCTAssertEqual(plank.frenchName, "Planche de Copenhague")
        XCTAssertEqual(plank.laterality, .unilateral)
        XCTAssertNotEqual(plank.sportDiscipline, .olympicWeightlifting)
    }

    func testSeedTemplatesAuthorWeightliftingAndCopenhagenPlank() {
        let templates = ExerciseCatalogSeedData.templates()
        let snatch = templates.first { $0.name == "Snatch" }
        let muscleClean = templates.first { $0.name == "Muscle Clean" }
        XCTAssertEqual(snatch?.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(snatch?.frenchName, "Arraché")
        XCTAssertEqual(muscleClean?.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(muscleClean?.frenchName, "Épaulé force")

        let plank = ExerciseSeedData.templates().first { $0.name == "Copenhagen Plank" }
        XCTAssertEqual(plank?.frenchName, "Planche de Copenhague")
        XCTAssertEqual(plank?.laterality, .unilateral)
        XCTAssertEqual(plank?.repCountingStyle, .perSide)
        XCTAssertNotEqual(plank?.sportDiscipline, .olympicWeightlifting)
    }
}

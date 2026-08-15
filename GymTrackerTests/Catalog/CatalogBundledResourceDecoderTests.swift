import Foundation
import XCTest
@testable import GymTracker

final class CatalogBundledResourceDecoderTests: XCTestCase {
    func testBundledCatalogsDecodeExpectedCounts() throws {
        let catalog = try CatalogResourceDecoder.decodeBundled()

        XCTAssertEqual(catalog.exercises.count, 471)
        XCTAssertEqual(catalog.mobilityDefinitions.count, 255)
        XCTAssertEqual(catalog.programs.count, 82)
        XCTAssertEqual(catalog.programs.first?.stableKey, "the5314b")
    }

    func testDecoderStripsBOMNormalizesKeysAndStableValues() throws {
        let exercises = Data("\u{FEFF}[{\"Name\":\"Demo\",\"SeedKey\":\" Exercise.Demo \",\"Sources\":[\" Liftosaur \"]}]".utf8)
        let mobility = Data("[{\"NAME\":\"Move\",\"SEED_KEY\":\"Stretch.Move\",\"MET\":2.5}]".utf8)
        let programs = Data("[{\"NAME\":\"Plan\",\"SLUG\":\"DbPpl\",\"URL\":\"https://example.com/plan\"}]".utf8)

        let catalog = try CatalogResourceDecoder.decode(exercises: exercises, mobility: mobility, programs: programs)

        XCTAssertEqual(catalog.exercises[0].stableKey, "exercise.demo")
        XCTAssertEqual(catalog.exercises[0].sources, ["liftosaur"])
        XCTAssertEqual(catalog.mobilityDefinitions[0].stableKey, "stretch.move")
        XCTAssertEqual(catalog.programs[0].stableKey, "dbppl")
    }

    func testValidationRejectsDuplicateNormalizedStableKeys() {
        let exercises = Data("[{\"name\":\"A\",\"seed_key\":\"Demo\"},{\"name\":\"B\",\"seedKey\":\"demo\"}]".utf8)
        let mobility = Data("[]".utf8)
        let programs = Data("[]".utf8)

        XCTAssertThrowsError(try CatalogResourceDecoder.decode(exercises: exercises, mobility: mobility, programs: programs)) { error in
            XCTAssertEqual(error as? CatalogResourceValidationError, .duplicateStableKey(kind: "exercise", key: "demo"))
        }
    }

    func testValidationRejectsInvalidURLs() {
        let exercises = Data("[{\"name\":\"A\",\"seed_key\":\"demo\",\"image_url\":\"not a url\"}]".utf8)

        XCTAssertThrowsError(try CatalogResourceDecoder.decode(exercises: exercises, mobility: Data("[]".utf8), programs: Data("[]".utf8))) { error in
            XCTAssertEqual(error as? CatalogResourceValidationError, .invalidURL(kind: "exercise", key: "demo", field: "imageURL", value: "not a url"))
        }
    }

    func testValidationRejectsNonFiniteMET() {
        let mobility = Data("[{\"name\":\"Move\",\"seed_key\":\"move\",\"met\":\"NaN\"}]".utf8)

        XCTAssertThrowsError(try CatalogResourceDecoder.decode(exercises: Data("[]".utf8), mobility: mobility, programs: Data("[]".utf8))) { error in
            XCTAssertEqual(error as? CatalogResourceValidationError, .nonFiniteMET(key: "move"))
        }
    }
}

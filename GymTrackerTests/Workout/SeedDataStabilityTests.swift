import Foundation
import SwiftData
import XCTest
@testable import GymTracker

/// Seed identity is load-bearing: `SystemSeedRegistry` derives seed keys from
/// these templates and `GymBackupRestore` reseeds the catalogue from them, so a
/// silent rename or removal re-identifies exercises on installs that already
/// have them.
///
final class SeedDataStabilityTests: XCTestCase {
    func testExerciseSeedDataKeysAreUniqueAndStable() {
        let templates = ExerciseSeedData.templates()
        let names = templates.map(\.name)
        let uniqueNames = Set(names)

        let duplicates = Dictionary(grouping: names, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        XCTAssertEqual(
            names.count,
            uniqueNames.count,
            "Exercise seed templates contain duplicate names: \(duplicates)"
        )

        XCTAssertGreaterThanOrEqual(
            templates.count,
            40,
            "Exercise seed catalog dropped unexpectedly."
        )

        let actualKeys = templates
            .map { SystemSeedKey.make(namespace: "exercise", legacyName: $0.name) }
            .sorted()
        XCTAssertEqual(
            actualKeys,
            ExpectedExerciseSeedKeys.all,
            "Exercise seed identities changed. Review the migration/version and deprecation plan before updating ExpectedExerciseSeedKeys."
        )
    }

    func testSeededExerciseNamesAreTrimmedAndNonEmpty() {
        for name in ExerciseSeedData.templates().map(\.name) {
            XCTAssertFalse(name.isEmpty, "A seeded exercise has an empty name")
            XCTAssertEqual(
                name,
                name.trimmingCharacters(in: .whitespacesAndNewlines),
                "Seeded exercise name '\(name)' has surrounding whitespace, which changes its seed key"
            )
        }
    }
}

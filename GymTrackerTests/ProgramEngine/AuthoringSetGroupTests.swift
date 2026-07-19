import XCTest
@testable import GymTracker

final class AuthoringSetGroupTests: XCTestCase {
    func testAuthoringSetGroupsExpandAllPrescriptionShapesDeterministically() throws {
        let groups = [
            AuthoringSetGroupDefinition(count: 2, reps: 5),
            AuthoringSetGroupDefinition(count: 1, repRange: [8, 12]),
            AuthoringSetGroupDefinition(count: 1, amrap: [3, nil]),
            AuthoringSetGroupDefinition(count: 1, durationSeconds: 45)
        ]
        var expanded: [SetPrescriptionDefinition] = []
        for (index, group) in groups.enumerated() {
            expanded += try group.expand(path: "fixture/e0/g\(index)", startingAt: expanded.count)
        }

        XCTAssertEqual(expanded.count, 5)
        XCTAssertEqual(expanded.map(\.orderIndex), [0, 1, 2, 3, 4])
        XCTAssertEqual(expanded[0].repetitions, .fixed(5))
        XCTAssertEqual(expanded[2].repetitions, .range(minimum: 8, maximum: 12))
        XCTAssertEqual(expanded[3].repetitions, .amrap(minimum: 3, maximum: nil))
        XCTAssertEqual(expanded[3].role, .amrap)
        XCTAssertEqual(expanded[4].repetitions, .duration(seconds: 45))
        XCTAssertEqual(
            expanded.map(\.id),
            try groups.enumerated().flatMap { index, group in
                try group.expand(
                    path: "fixture/e0/g\(index)",
                    startingAt: groups.prefix(index).reduce(0) { $0 + $1.count }
                ).map(\.id)
            }
        )
    }

    func testAuthoringLoadExpandsReferencesOffsetsBoundsAndRounding() {
        let load = AuthoringLoadDefinition(
            reference: .trainingMax,
            of: "squat",
            percent: 0.85,
            offset: 2.5,
            percentOffset: 0.025,
            min: 20,
            max: 200,
            round: 2.5
        ).expand()

        XCTAssertEqual(load.reference, LoadReference(kind: .trainingMax, exposureKey: "squat"))
        XCTAssertEqual(load.percentage, 0.85)
        XCTAssertEqual(load.absoluteOffset, 2.5)
        XCTAssertEqual(load.percentageOffset, 0.025)
        XCTAssertEqual(load.minimum, 20)
        XCTAssertEqual(load.maximum, 200)
        XCTAssertEqual(load.rounding, .nearestIncrement(2.5))
    }

    func testAuthoringSetGroupRejectsAmbiguousRepetitionPrescription() {
        XCTAssertThrowsError(try AuthoringSetGroupDefinition(
            count: 1,
            reps: 5,
            repRange: [5, 8]
        ).expand(path: "fixture/e0/g0", startingAt: 0)) { error in
            XCTAssertEqual(error as? ProgramLibraryImportError, .invalidSetGroup("fixture/e0/g0"))
        }
    }
}

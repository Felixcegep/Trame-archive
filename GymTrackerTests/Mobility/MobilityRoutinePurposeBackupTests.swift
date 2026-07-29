import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityRoutinePurposeBackupTests: XCTestCase {
    func testBackupVersionIsMobilityRoutinePurposeVersion() {
        XCTAssertEqual(BackupDTO.mobilityRoutinePurposeVersion, 22)
        XCTAssertEqual(BackupDTO.currentVersion, BackupDTO.mobilityRoutinePurposeVersion)
    }

    func testRoutinePurposesRoundTripThroughBackup() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        for (name, purpose) in [
            ("Preparation", MobilityRoutinePurpose.preparation),
            ("Development", .development),
            ("Post-workout", .cooldown),
            ("Unspecified", nil)
        ] {
            source.insert(MobilityRoutine(name: name, purpose: purpose))
        }
        try source.save()

        let encoded = try JSONEncoder().encode(
            BackupDTO.create(from: source, restTimer: 90, darkMode: false, unitSystem: .metric)
        )
        let backup = try JSONDecoder().decode(BackupDTO.self, from: encoded)
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let purposes = Dictionary(uniqueKeysWithValues: try restored.fetch(FetchDescriptor<MobilityRoutine>()).map {
            ($0.name, $0.purpose)
        })
        XCTAssertEqual(purposes["Preparation"]!, .preparation)
        XCTAssertEqual(purposes["Development"]!, .development)
        XCTAssertEqual(purposes["Post-workout"]!, .cooldown)
        XCTAssertNil(purposes["Unspecified"]!)
    }

    func testLegacyPurposeKeyIsIgnoredButV22UnknownValueIsRejected() throws {
        let routine = MobilityRoutineDTO(
            id: UUID().uuidString,
            name: "Legacy routine",
            notes: nil,
            isArchived: false,
            createdAt: .now,
            updatedAt: .now,
            items: [],
            purpose: "recovery"
        )

        let legacy = backup(version: 21, routines: [routine])
        XCTAssertNoThrow(try legacy.validate())
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try legacy.restore(to: restored)
        let restoredRoutine = try XCTUnwrap(
            restored.fetch(FetchDescriptor<MobilityRoutine>()).first { $0.name == "Legacy routine" }
        )
        XCTAssertNil(restoredRoutine.purposeRaw)

        let current = backup(version: BackupDTO.currentVersion, routines: [routine])
        XCTAssertThrowsError(try current.validate()) { error in
            guard case .invalidIdentifier("mobility routine purpose") = error as? BackupValidationError else {
                return XCTFail("Expected an invalid mobility routine purpose, got \(error)")
            }
        }
    }

    private func backup(version: Int, routines: [MobilityRoutineDTO]) -> BackupDTO {
        BackupDTO(
            version: version,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            mobilityRoutines: routines
        )
    }
}

import XCTest
@testable import GymTracker

final class StrengthBackupValidatorTests: XCTestCase {
    func testBaseSetValidationRejectsImpossibleNumericEvidence() throws {
        let invalidSets = [
            makeSet(repetitions: -.leastNonzeroMagnitude),
            makeSet(repetitions: .infinity),
            makeSet(weight: -.leastNonzeroMagnitude),
            makeSet(weight: .nan),
            makeSet(duration: -.leastNonzeroMagnitude),
            makeSet(duration: .infinity)
        ]

        for set in invalidSets {
            XCTAssertThrowsError(try StrengthBackupValidator.validateBaseSet(set))
        }

        XCTAssertNoThrow(try StrengthBackupValidator.validateBaseSet(makeSet()))
    }

    func testWorkoutValidationRejectsUnknownStatusWithoutArchiveFallback() throws {
        let backup = makeBackup(workouts: [makeWorkout(status: "future", endTime: Date())])

        XCTAssertThrowsError(try backup.validate()) { error in
            guard case .invalidIdentifier("workout status") = error as? BackupValidationError else {
                return XCTFail("Expected an invalid workout status error, got \(error)")
            }
        }
        XCTAssertThrowsError(try CurrentBackupArchive(adapting: backup)) { error in
            guard case .invalidIdentifier("workout status") = error as? BackupValidationError else {
                return XCTFail("Expected archive conversion to reject the raw status, got \(error)")
            }
        }
    }

    func testWorkoutValidationRejectsInconsistentLifecycleAndMultipleActiveWorkouts() throws {
        let inconsistentWorkouts = [
            makeWorkout(status: WorkoutStatus.active.rawValue, endTime: Date()),
            makeWorkout(status: WorkoutStatus.completed.rawValue, endTime: nil)
        ]

        for workout in inconsistentWorkouts {
            XCTAssertThrowsError(try makeBackup(workouts: [workout]).validate()) { error in
                guard case .invalidIdentifier("workout lifecycle") = error as? BackupValidationError else {
                    return XCTFail("Expected a workout lifecycle error, got \(error)")
                }
            }
        }

        let activeWorkouts = [
            makeWorkout(status: WorkoutStatus.active.rawValue, endTime: nil),
            makeWorkout(status: WorkoutStatus.active.rawValue, endTime: nil)
        ]
        XCTAssertThrowsError(try makeBackup(workouts: activeWorkouts).validate()) { error in
            guard case .invalidIdentifier("active workout") = error as? BackupValidationError else {
                return XCTFail("Expected a single-active-workout error, got \(error)")
            }
        }
    }

    private func makeBackup(workouts: [WorkoutDTO]) -> BackupDTO {
        BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(
                darkMode: false,
                restTimer: 90,
                unitSystem: UnitSystem.metric.rawValue
            ),
            exercises: [],
            templates: [],
            collections: [],
            workouts: workouts
        )
    }

    private func makeWorkout(status: String, endTime: Date?) -> WorkoutDTO {
        WorkoutDTO(
            id: UUID().uuidString,
            status: status,
            name: "Workout",
            notes: nil,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            endTime: endTime,
            restEndDate: nil,
            pausedRemainingTime: nil,
            sourceTemplateName: nil,
            sourcePlanID: nil,
            sourcePlanRunID: nil,
            sourcePlanBlockID: nil,
            sourcePlanWeekID: nil,
            sourcePlannedWorkoutID: nil,
            sourcePlanName: nil,
            exercises: []
        )
    }

    private func makeSet(
        repetitions: Float = 0,
        weight: Float = 0,
        duration: TimeInterval? = nil
    ) -> ExerciseSetDTO {
        ExerciseSetDTO(
            orderIndex: 0,
            weightType: WeightType.kg.rawValue,
            distanceType: DistanceType.meters.rawValue,
            repetition: repetitions,
            weight: weight,
            duration: duration,
            distance: nil,
            done: false,
            rpe: nil,
            setType: SetType.normal.rawValue,
            usedMetric: UnitSystem.metric.rawValue
        )
    }
}

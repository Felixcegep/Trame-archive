import XCTest
@testable import GymTracker

final class TrainingJourneyDisciplineDistributionTests: XCTestCase {
    func testClassifiedEntriesExposeCountsProportionsAndEvidence() {
        let strength = entry(discipline: .powerlifting)
        let olympic = entry(discipline: .olympicWeightlifting)
        let workout = completedWorkout(entries: [strength, olympic])

        let distribution = TrainingJourneyDisciplineDistribution.project(workouts: [workout])

        XCTAssertEqual(distribution.totalEntryCount, 2)
        XCTAssertEqual(distribution.classifiedEntryCount, 2)
        XCTAssertEqual(distribution.unknownEntryCount, 0)
        XCTAssertEqual(distribution.slices.count, 2)
        XCTAssertEqual(distribution.slices.map(\.entryCount), [1, 1])
        XCTAssertEqual(distribution.slices.map(\.proportion), [0.5, 0.5])
        XCTAssertEqual(distribution.slices.flatMap(\.evidence).count, 2)
        XCTAssertTrue(distribution.slices.allSatisfy { $0.evidence.count == 1 })
        XCTAssertTrue(distribution.slices.allSatisfy { $0.evidenceIDs.count == 1 })
    }

    func testMissingSnapshotStaysUnknownEvenWhenLiveExerciseIsReclassified() {
        let exercise = Exercise(name: "Legacy lift", primaryMuscles: [.upperChest], isCustom: true)
        exercise.sportDiscipline = .strongman
        let legacyEntry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        legacyEntry.sportDisciplineSnapshotRaw = nil

        let distribution = TrainingJourneyDisciplineDistribution.project(
            workouts: [completedWorkout(entries: [legacyEntry])]
        )

        XCTAssertEqual(distribution.totalEntryCount, 1)
        XCTAssertEqual(distribution.classifiedEntryCount, 0)
        XCTAssertEqual(distribution.unknownEntryCount, 1)
        XCTAssertEqual(distribution.slices.map(\.discipline), [nil])
        XCTAssertEqual(distribution.slices.first?.recordKinds, [])
    }

    func testFrozenSnapshotSurvivesCatalogueReclassification() {
        let exercise = Exercise(name: "Reclassified lift", primaryMuscles: [.upperChest], isCustom: true)
        exercise.sportDiscipline = .powerlifting
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sportDisciplineSnapshotRaw = SportDiscipline.bodybuilding.rawValue
        exercise.sportDiscipline = .strongman

        let distribution = TrainingJourneyDisciplineDistribution.project(
            workouts: [completedWorkout(entries: [entry])]
        )

        XCTAssertEqual(distribution.slices.first?.discipline, .bodybuilding)
        XCTAssertEqual(distribution.unknownEntryCount, 0)
    }

    func testIncompatibleStrongmanMetricPoliciesRemainSeparateSlices() {
        let carry = entry(discipline: .strongman, eventFamily: .carry)
        let hold = entry(discipline: .strongman, eventFamily: .hold)
        let distribution = TrainingJourneyDisciplineDistribution.project(
            workouts: [completedWorkout(entries: [carry, hold])]
        )

        XCTAssertEqual(distribution.slices.count, 2)
        XCTAssertNotEqual(distribution.slices[0].recordKinds, distribution.slices[1].recordKinds)
        XCTAssertEqual(
            Set(distribution.slices.flatMap(\.recordKinds)),
            Set([SportRecordKind.loadDistance, .loadDuration])
        )
    }

    func testIncompleteWorkoutsDoNotContributeToHistoricalDistribution() {
        let completed = completedWorkout(entries: [entry(discipline: .bodybuilding)])
        let active = Workout(name: "Still logging")
        active.exercises = [entry(discipline: .strongman)]

        let distribution = TrainingJourneyDisciplineDistribution.project(workouts: [completed, active])

        XCTAssertEqual(distribution.totalEntryCount, 1)
        XCTAssertEqual(distribution.slices.first?.discipline, .bodybuilding)
    }

    private func entry(
        discipline: SportDiscipline,
        eventFamily: StrongmanEventFamily? = nil
    ) -> ExerciseEntry {
        let exercise = Exercise(name: "Historical evidence", primaryMuscles: [.upperChest], isCustom: true)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sportDisciplineSnapshotRaw = discipline.rawValue
        entry.strongmanEventFamilySnapshotRaw = eventFamily?.rawValue
        return entry
    }

    private func completedWorkout(entries: [ExerciseEntry]) -> Workout {
        let workout = Workout(name: "Completed history", endTime: Date(timeIntervalSince1970: 1_700_000_000))
        workout.exercises = entries
        return workout
    }
}

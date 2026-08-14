import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SetPrefillPrecedenceTests: XCTestCase {
    func testAutofillWritesOnlyAnUnfilledUnprescribedSetOnce() throws {
        let fixture = try makeFixture()
        let previous = WorkoutTestFixture.previousSet(order: 0, reps: 8, weight: 50)

        XCTAssertTrue(fixture.viewModel.autofillPreviousPerformanceIfUnfilled(previous, to: fixture.set, in: fixture.entry))
        XCTAssertEqual(fixture.set.repetitions, 8)
        XCTAssertEqual(
            fixture.set.weight,
            UnitConversion.weight(50, from: .lbs, to: .kg),
            accuracy: 0.001
        )

        fixture.set.repetitions = 0
        fixture.set.weight = 0
        XCTAssertFalse(fixture.viewModel.autofillPreviousPerformanceIfUnfilled(previous, to: fixture.set, in: fixture.entry))
        XCTAssertEqual(fixture.set.repetitions, 0)
        XCTAssertEqual(fixture.set.weight, 0)
    }

    func testAutofillRefusesCompletedFilledAndPrescribedSets() throws {
        for configure in [
            { (set: ExerciseSet) in set.done = true },
            { (set: ExerciseSet) in set.repetitions = 5 },
            { (set: ExerciseSet) in set.prescribedRepetitions = 6 }
        ] {
            let fixture = try makeFixture()
            configure(fixture.set)
            let previous = WorkoutTestFixture.previousSet(order: 0, reps: 8, weight: 50)
            XCTAssertFalse(fixture.viewModel.autofillPreviousPerformanceIfUnfilled(previous, to: fixture.set, in: fixture.entry))
        }
    }

    func testUnfilledAndPrescriptionPredicatesCoverEveryTrackedMetric() {
        let set = ExerciseSet(usedMetric: .metric)
        XCTAssertTrue(SetRowPreparation.isUnfilled(set, for: .repsOnly))
        set.repetitions = 1
        XCTAssertFalse(SetRowPreparation.isUnfilled(set, for: .repsOnly))

        let prescriptions: [(ExerciseSet) -> Void] = [
            { $0.prescribedSetType = .normal }, { $0.prescribedRepetitions = 1 },
            { $0.prescribedRepRangeMinimum = 1 }, { $0.prescribedRepRangeMaximum = 2 },
            { $0.prescribedSuggestedLoad = 10 }, { $0.prescribedCalories = 10 },
            { $0.prescriptionDefinitionData = Data([1]) }
        ]
        for prescribe in prescriptions {
            let candidate = ExerciseSet(usedMetric: .metric)
            prescribe(candidate)
            XCTAssertTrue(SetRowPreparation.hasPrescription(candidate))
        }
    }

    private func makeFixture() throws -> (viewModel: ActiveWorkoutViewModel, entry: ExerciseEntry, set: ExerciseSet) {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let set = ExerciseSet(usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Prefill")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()
        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        return (ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context), entry, set)
    }
}

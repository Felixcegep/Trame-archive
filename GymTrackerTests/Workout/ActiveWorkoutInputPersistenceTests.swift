import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ActiveWorkoutInputPersistenceTests: XCTestCase {
    func testRapidKeypadEditsStayInMemoryUntilTheCoalescedFlush() throws {
        let fixture = try makeFixture()

        fixture.viewModel.commitTypedValue("1", field: .repetitions, in: fixture.set)
        fixture.viewModel.commitTypedValue("12", field: .repetitions, in: fixture.set)
        fixture.viewModel.commitTypedValue("123", field: .repetitions, in: fixture.set)

        XCTAssertEqual(fixture.set.repetitions, 123)
        let beforeFlush = try fetchSet(in: ModelContext(fixture.container), id: fixture.set.id)
        XCTAssertEqual(beforeFlush.repetitions, 0)

        XCTAssertTrue(fixture.viewModel.flushPendingTypedInputSave())

        let afterFlush = try fetchSet(in: ModelContext(fixture.container), id: fixture.set.id)
        XCTAssertEqual(afterFlush.repetitions, 123)
    }

    func testImmediatePersistenceBoundaryAbsorbsPendingKeypadInput() throws {
        let fixture = try makeFixture()

        fixture.viewModel.commitTypedValue("42", field: .weight, in: fixture.set)
        fixture.viewModel.persistChanges()

        let reloaded = try fetchSet(in: ModelContext(fixture.container), id: fixture.set.id)
        XCTAssertEqual(reloaded.weight, 42)
    }

    func testRapidDecimalWeightEntryWithBackspacePersistsFinalValueAfterCoalescing() async throws {
        let fixture = try makeFixture()
        let coordinator = SetInputCoordinator()
        let keys: [KeypadKey] = [.digit(1), .decimal, .digit(2), .backspace, .digit(5)]
        var committedTexts: [String] = []

        for key in keys {
            let text = try XCTUnwrap(coordinator.applyKey(key, decimalSeparator: "."))
            committedTexts.append(text)
            fixture.viewModel.commitTypedValue(text, field: .weight, in: fixture.set)
        }

        XCTAssertEqual(committedTexts, ["1", "1.", "1.2", "1.", "1.5"])
        XCTAssertEqual(fixture.set.weight, Float(1.5), accuracy: 0.0001)

        let beforeDebounce = try fetchSet(in: ModelContext(fixture.container), id: fixture.set.id)
        XCTAssertEqual(beforeDebounce.weight, 0, accuracy: 0.0001)

        try await Task.sleep(for: .milliseconds(300))

        let afterDebounce = try fetchSet(in: ModelContext(fixture.container), id: fixture.set.id)
        XCTAssertEqual(afterDebounce.weight, Float(1.5), accuracy: 0.0001)
    }

    func testSetCompletionCommitsPendingInputAndCompletionTogether() throws {
        let fixture = try makeFixture()

        fixture.viewModel.commitTypedValue("8", field: .repetitions, in: fixture.set)
        fixture.viewModel.commitTypedValue("50", field: .weight, in: fixture.set)

        guard case .completed = fixture.viewModel.completeSet(fixture.set, in: fixture.entry) else {
            return XCTFail("Expected the valid set to complete.")
        }

        let reloaded = try fetchSet(in: ModelContext(fixture.container), id: fixture.set.id)
        XCTAssertEqual(reloaded.repetitions, 8)
        XCTAssertEqual(reloaded.weight, 50)
        XCTAssertTrue(reloaded.done)
    }

    private func makeFixture() throws -> Fixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = Exercise(name: "Persistence Lift", primaryMuscles: [.upperChest])
        let set = ExerciseSet(repetitions: 0, weight: 0, done: false, orderIndex: 0, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Input Persistence")
        workout.exercises = [entry]

        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        return Fixture(
            container: container,
            viewModel: ActiveWorkoutViewModel(workoutVM: viewModel, modelContext: context),
            entry: entry,
            set: set
        )
    }

    private func fetchSet(in context: ModelContext, id: UUID) throws -> ExerciseSet {
        try XCTUnwrap(
            context.fetch(FetchDescriptor<ExerciseSet>()).first { $0.id == id }
        )
    }
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let viewModel: ActiveWorkoutViewModel
    let entry: ExerciseEntry
    let set: ExerciseSet
}

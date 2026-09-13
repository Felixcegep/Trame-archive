import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class OlympicAttemptLoggingTests: XCTestCase {
    func testLastCompletedSetAlwaysAsksForEffort() throws {
        let fixture = try makeFixture(prescribedRPE: nil)
        let active = ActiveWorkoutViewModel(workoutVM: fixture.viewModel, modelContext: fixture.context)

        XCTAssertEqual(active.lastCompletedSetAwaitingEffort?.id, fixture.completed.id)
    }

    func testOlympicEntrySummarizesMadeMissedAndUnratedAttempts() throws {
        let exercise = Exercise(name: "Snatch", primaryMuscles: [.gluteMaximus])
        exercise.sportDiscipline = .olympicWeightlifting
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let made = ExerciseSet(repetitions: 1, weight: 80, done: true, liftQuality: .excellent, orderIndex: 0, usedMetric: .metric)
        let missed = ExerciseSet(repetitions: 1, weight: 85, done: true, liftQuality: .missed, orderIndex: 1, usedMetric: .metric)
        let unrated = ExerciseSet(repetitions: 1, weight: 90, done: true, orderIndex: 2, usedMetric: .metric)
        entry.sets = [made, missed, unrated]

        XCTAssertTrue(entry.usesOlympicAttemptLogging)
        XCTAssertEqual(entry.olympicAttemptSummary, "1 made · 1 missed · 1 unrated")
        XCTAssertTrue(entry.hasUnansweredOlympicQuality)
        XCTAssertTrue(entry.hasUnansweredEffort)
    }

    func testRefreshDerivedOlympicQualityUpdatesParentBeforeCompletion() {
        let set = ExerciseSet(repetitions: 2, weight: 80, usedMetric: .metric)
        set.ensureComplexComponents(for: [
            ComplexComponentSnapshot(exerciseID: UUID(), exerciseNameSnapshot: "Clean", prescribedRepetitions: 1),
            ComplexComponentSnapshot(exerciseID: UUID(), exerciseNameSnapshot: "Jerk", prescribedRepetitions: 1)
        ])
        set.complexComponents[0].outcome = .completed
        set.complexComponents[0].liftQuality = .acceptable
        set.complexComponents[1].outcome = .missed
        set.complexComponents[1].liftQuality = .missed

        set.refreshDerivedOlympicQuality()

        XCTAssertEqual(set.olympicAttemptOutcome, .missed)
        XCTAssertEqual(set.liftQuality, .missed)
        XCTAssertFalse(set.done)
    }

    func testCatalogSeedAssignsOlympicDisciplineFromWeightliftingTags() {
        let templates = ExerciseCatalogSeedData.templates()
        let snatch = templates.first { $0.name == "Snatch" }
        let hangSnatch = templates.first { $0.name == "Hang Snatch" }

        XCTAssertEqual(snatch?.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(hangSnatch?.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(snatch?.resolvedSportDiscipline, .olympicWeightlifting)
        XCTAssertTrue(snatch?.sportCapabilityProfile.supportsAttemptOutcomes == true)
    }

    func testBundledCatalogSeedWritesOlympicDisciplineOntoSnatch() throws {
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
        let cleanAndJerk = try XCTUnwrap(exercises.first { $0.name == "Clean and Jerk" })
        XCTAssertEqual(snatch.sportDiscipline, .olympicWeightlifting)
        XCTAssertEqual(cleanAndJerk.sportDiscipline, .olympicWeightlifting)
    }

    private func makeFixture(prescribedRPE: Double?) throws -> Fixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = Exercise(name: "Effort Lift", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.prescribedRPE = prescribedRPE
        let completed = ExerciseSet(repetitions: 5, weight: 60, done: true, orderIndex: 0, usedMetric: .metric)
        completed.prescribedRPE = prescribedRPE
        let remaining = ExerciseSet(repetitions: 0, weight: 0, done: false, orderIndex: 1, usedMetric: .metric)
        entry.sets = [completed, remaining]
        let workout = Workout(name: "Effort Workout")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()
        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        return Fixture(context: context, completed: completed, viewModel: viewModel)
    }
}

@MainActor
private struct Fixture {
    let context: ModelContext
    let completed: ExerciseSet
    let viewModel: WorkoutViewModel
}

import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutIntegrityTests: XCTestCase {
    func testDeletingWorkoutCascadesEntriesAndSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let workout = makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        context.delete(workout)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciceEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciceTemplate>()).count, 1)
    }

    func testOrphanCleanupDeletesUnownedEntriesAndSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetition: 8, weight: 50, usedMetric: .metric)]
        context.insert(exercise)
        context.insert(entry)
        try context.save()

        let result = try DataMaintenanceService.cleanupOrphans(using: context)

        XCTAssertEqual(result.deletedExercises, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciceEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
    }

    func testPreviousPerformanceUsesLatestCompletedWorkoutAndStoredIdentity() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let olderWorkout = makeWorkout(with: exercise, reps: 8, weight: 100)
        olderWorkout.status = .completed
        olderWorkout.startTime = Date.now.addingTimeInterval(-86_400)
        olderWorkout.endTime = olderWorkout.startTime.addingTimeInterval(3_600)
        context.insert(exercise)
        context.insert(olderWorkout)
        try context.save()

        let performance = try ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: exercise, before: .now)

        XCTAssertEqual(performance?.completedSetCount, 1)
        XCTAssertEqual(performance?.sets.first?.repetitions, 8)
        XCTAssertEqual(performance?.sets.first?.weight, 100)
        XCTAssertEqual(performance?.sets.first?.weightType, .kg)
    }

    func testUnitConversionPreservesEquivalentLoad() {
        XCTAssertEqual(UnitConversion.weight(100, from: .kg, to: .lbs), 220.462_26, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.weight(220.462_26, from: .lbs, to: .kg), 100, accuracy: 0.001)
    }

    func testRestTimerControllerTransitionsThroughPauseAndResume() {
        let controller = RestTimerController()
        let endDate = Date.now.addingTimeInterval(90)

        controller.start(until: endDate)
        XCTAssertEqual(controller.endDate, endDate)
        XCTAssertTrue(controller.isVisible)

        controller.pause(remaining: 45)
        XCTAssertEqual(controller.pausedRemaining, 45)
        XCTAssertNil(controller.endDate)

        controller.extendPaused(by: 15)
        XCTAssertEqual(controller.pausedRemaining, 60)

        controller.cancel()
        XCTAssertFalse(controller.isVisible)
    }

    func testDoubleProgressionIncreasesOnlyAfterAllRequiredSetsReachCeiling() {
        let performance = PreviousExercisePerformance(
            workoutDate: .now,
            sets: [
                PreviousSetPerformance(orderIndex: 0, repetitions: 12, weight: 100, weightType: .lbs, duration: nil, distance: nil, distanceType: .miles, setType: .normal),
                PreviousSetPerformance(orderIndex: 1, repetitions: 12, weight: 100, weightType: .lbs, duration: nil, distance: nil, distanceType: .miles, setType: .normal),
                PreviousSetPerformance(orderIndex: 2, repetitions: 12, weight: 100, weightType: .lbs, duration: nil, distance: nil, distanceType: .miles, setType: .normal)
            ]
        )

        let recommendation = DoubleProgressionEngine.recommend(
            from: performance,
            requiredSets: 3,
            repCeiling: 12,
            increment: 5
        )

        XCTAssertEqual(recommendation?.decision, .increase)
        XCTAssertEqual(recommendation?.recommendedLoad, 105)
        XCTAssertTrue(recommendation?.explanation.contains("105 lbs recommended") == true)
    }

    func testBackupRoundTripsProgressionRuleAndRecommendationSnapshot() throws {
        let source = try makeContext()
        let exercise = makeExercise()
        let templateExercise = TemplateExercise(
            exercise: exercise,
            order: 0,
            progressionRule: .none
        )
        let template = WorkoutTemplate(
            name: "Progression Template",
            exercises: [exercise],
            templateExercises: [templateExercise]
        )
        let workout = makeWorkout(with: exercise)
        let entry = try XCTUnwrap(workout.exercises.first)
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 105
        entry.recommendedUnit = .lbs
        entry.recommendationPriorLoad = 100
        entry.recommendationRequiredSets = 3
        entry.recommendationRepCeiling = 12
        entry.recommendationCompletedSets = 3
        entry.recommendationPriorWorkoutDate = Date(timeIntervalSince1970: 1_700_000_000)
        source.insert(exercise)
        source.insert(template)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)
        let restored = try makeContext()
        try decoded.restore(to: restored)

        let restoredTemplate = try XCTUnwrap(
            restored.fetch(FetchDescriptor<WorkoutTemplate>())
                .first { $0.name == "Progression Template" }
        )
        XCTAssertEqual(
            restoredTemplate.orderedTemplateExercises.first?.progressionRule,
            ProgressionRule.none
        )

        let restoredEntry = try XCTUnwrap(
            restored.fetch(FetchDescriptor<Workout>()).first?.orderedExercises.first
        )
        XCTAssertEqual(restoredEntry.recommendedDecision, .increase)
        XCTAssertEqual(restoredEntry.recommendedLoad, 105)
        XCTAssertEqual(restoredEntry.recommendedUnit, .lbs)
        XCTAssertEqual(restoredEntry.recommendationPriorLoad, 100)
        XCTAssertEqual(restoredEntry.recommendationRequiredSets, 3)
        XCTAssertEqual(restoredEntry.recommendationRepCeiling, 12)
        XCTAssertEqual(restoredEntry.recommendationCompletedSets, 3)
        XCTAssertEqual(
            restoredEntry.recommendationPriorWorkoutDate,
            Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            ExerciceTemplate.self,
            ExerciceEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeExercise() -> ExerciceTemplate {
        ExerciceTemplate(name: "Bench Press", PrimaryMuscle: [.upperChest])
    }

    private func makeWorkout(
        with exercise: ExerciceTemplate,
        reps: Float = 8,
        weight: Float = 50
    ) -> Workout {
        let set = ExerciseSet(repetition: reps, weight: weight, done: true, usedMetric: .metric)
        let entry = ExerciceEntry(exercice: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(nom: "Test Workout", endTime: .now)
        workout.exercises = [entry]
        return workout
    }
}

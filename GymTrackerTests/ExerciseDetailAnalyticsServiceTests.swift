import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ExerciseDetailAnalyticsServiceTests: XCTestCase {
    func testEmptyHistoryReturnsEmptyAnalyticsWithoutCrashing() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertNil(analytics.unit)
        XCTAssertNil(analytics.latestSession)
        XCTAssertNil(analytics.sessionComparison)
        XCTAssertNil(analytics.bestLoadSet)
        XCTAssertNil(analytics.bestRepetitionSet)
        XCTAssertTrue(analytics.bestSetsByRepRange.isEmpty)
        XCTAssertNil(analytics.estimatedOneRepMax)
        XCTAssertEqual(analytics.weeklyVolume.count, 8)
        XCTAssertTrue(analytics.weeklyVolume.allSatisfy { $0.totalVolume == 0 })
        XCTAssertTrue(analytics.notes.isEmpty)
    }

    func testActiveWorkoutsAreExcludedFromEveryMetric() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)

        // A completed reference session plus a still-active workout that
        // would otherwise dominate every PR if it were counted.
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(10),
            sets: [(8, 100, .kg, .normal)],
            in: context
        )
        let active = Workout(name: "Active", endTime: nil)
        let activeEntry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        activeEntry.sets = [ExerciseSet(repetitions: 12, weight: 999, done: true, usedMetric: .metric)]
        active.exercises = [activeEntry]
        context.insert(active)
        try context.save()
        XCTAssertEqual(active.status, .active)

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertEqual(analytics.bestLoadSet?.weight, 100)
        XCTAssertEqual(analytics.latestSession?.workoutDate, daysAgo(10))
    }

    func testWarmUpSetsNeverProduceAStrengthPR() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(5),
            sets: [
                (10, 200, .kg, .warmup),
                (8, 100, .kg, .normal)
            ],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertEqual(analytics.bestLoadSet?.weight, 100)
        XCTAssertEqual(analytics.bestRepetitionSet?.repetitions, 8)
        XCTAssertNotEqual(analytics.bestLoadSet?.weight, 200)
    }

    func testMixedUnitHistoryConvertsBeforeComparingLoads() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        // Older session recorded in lbs; the true heaviest set once converted.
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(20),
            sets: [(5, 240, .lbs, .normal)],
            in: context
        )
        // Latest session recorded in kg with a lighter absolute number that is
        // nonetheless lighter after conversion (240 lb ≈ 108.9 kg).
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(2),
            sets: [(5, 100, .kg, .normal)],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertEqual(analytics.unit, .kg)
        let bestLoad = try XCTUnwrap(analytics.bestLoadSet)
        XCTAssertEqual(bestLoad.weight, UnitConversion.weight(240, from: .lbs, to: .kg), accuracy: 0.01)

        let comparison = try XCTUnwrap(analytics.sessionComparison)
        XCTAssertEqual(comparison.previousBestLoad, UnitConversion.weight(240, from: .lbs, to: .kg), accuracy: 0.01)
        XCTAssertEqual(comparison.latestBestLoad, 100, accuracy: 0.01)
        XCTAssertEqual(comparison.bestLoadTrend, .decreased)
    }

    func testSingleSessionHistorySkipsComparisonButPopulatesOtherMetrics() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(3),
            sets: [(8, 100, .kg, .normal)],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertNil(analytics.sessionComparison)
        XCTAssertNotNil(analytics.latestSession)
        XCTAssertEqual(analytics.bestLoadSet?.weight, 100)
        XCTAssertNotNil(analytics.estimatedOneRepMax)
    }

    func testEstimatedOneRepMaxUsesTheEpleyFormula() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(1),
            sets: [(5, 100, .kg, .normal)],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        let expected: Float = 100 * (1 + 5 / 30)
        let estimatedLoad = try XCTUnwrap(analytics.estimatedOneRepMax?.estimatedLoad)
        XCTAssertEqual(estimatedLoad, expected, accuracy: 0.01)
    }

    func testBestSetsByRepRangeBucketEachHistoricalSetSeparately() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(15),
            sets: [
                (3, 140, .kg, .normal),
                (10, 90, .kg, .normal),
                (20, 40, .kg, .normal)
            ],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertEqual(analytics.bestSetsByRepRange.count, 3)
        let byRange = Dictionary(uniqueKeysWithValues: analytics.bestSetsByRepRange.map { ($0.rangeName, $0.bestSet.weight) })
        XCTAssertEqual(byRange["1–5"], 140)
        XCTAssertEqual(byRange["6–12"], 90)
        XCTAssertEqual(byRange["13+"], 40)
    }

    func testAssistedBodyweightExcludesLoadMetricsButKeepsRepetitionPR() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Assisted Pull-up",
            primaryMuscles: [.latissimusDorsi],
            trackingType: .assistedBodyweight
        )
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(4),
            sets: [(12, 20, .kg, .normal)],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertNil(analytics.bestLoadSet)
        XCTAssertNil(analytics.estimatedOneRepMax)
        XCTAssertTrue(analytics.bestSetsByRepRange.isEmpty)
        XCTAssertEqual(analytics.bestRepetitionSet?.repetitions, 12)
    }

    func testNotesAreOrderedChronologically() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(30),
            sets: [(8, 90, .kg, .normal)],
            comment: "Felt slow off the chest.",
            in: context
        )
        insertCompletedWorkout(
            exercise: exercise,
            date: daysAgo(5),
            sets: [(8, 95, .kg, .normal)],
            comment: "New grip width felt strong.",
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        XCTAssertEqual(analytics.notes.map(\.text), [
            "Felt slow off the chest.",
            "New grip width felt strong."
        ])
    }

    func testWeeklyVolumeSeriesHasExactlyEightWeeksSummedInTheAnchorUnit() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        context.insert(exercise)
        // Two sessions on the same calendar day (well clear of any week
        // boundary) must combine into the current, most-recent bucket.
        insertCompletedWorkout(
            exercise: exercise,
            date: referenceDate.addingTimeInterval(-3_600),
            sets: [(10, 50, .kg, .normal)],
            in: context
        )
        insertCompletedWorkout(
            exercise: exercise,
            date: referenceDate.addingTimeInterval(-7_200),
            sets: [(10, 50, .kg, .normal)],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate, weekCount: 8)

        XCTAssertEqual(analytics.weeklyVolume.count, 8)
        let lastWeekVolume = try XCTUnwrap(analytics.weeklyVolume.last?.totalVolume)
        XCTAssertEqual(lastWeekVolume, 1_000, accuracy: 0.01)
        XCTAssertEqual(analytics.weeklyVolume.dropLast().reduce(Float(0)) { $0 + $1.totalVolume }, 0)
    }

    func testPerLoadUnitExerciseDoublesVolumeButNotEstimatedOneRepMax() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Dumbbell Bench Press",
            primaryMuscles: [.middleChest],
            equipmentType: .dumbbell,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        context.insert(exercise)
        insertCompletedWorkout(
            exercise: exercise,
            date: referenceDate.addingTimeInterval(-3_600),
            sets: [(10, 50, .kg, .normal)],
            in: context
        )
        try context.save()

        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate, weekCount: 8)

        // 10 reps × 50 kg per dumbbell × 2 dumbbells = 1,000 total volume.
        let lastWeekVolume = try XCTUnwrap(analytics.weeklyVolume.last?.totalVolume)
        XCTAssertEqual(lastWeekVolume, 1_000, accuracy: 0.01)

        // A load PR / estimated 1RM stays the per-hand number, not doubled.
        XCTAssertEqual(analytics.bestLoadSet?.weight, 50)
        XCTAssertEqual(analytics.estimatedOneRepMax?.sourceWeight, 50)
    }

    // MARK: - Fixtures

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysAgo(_ days: Int) -> Date {
        referenceDate.addingTimeInterval(-Double(days) * 86_400)
    }

    private func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
    }

    @discardableResult
    private func insertCompletedWorkout(
        exercise: Exercise,
        date: Date,
        sets: [(reps: Float, weight: Float, unit: WeightType, type: SetType)],
        comment: String? = nil,
        in context: ModelContext
    ) -> Workout {
        let workout = Workout(name: "Session", endTime: date.addingTimeInterval(3_600))
        workout.startTime = date
        let entry = ExerciseEntry(comment: comment, exercise: exercise, usedMetric: .metric)
        entry.sets = sets.enumerated().map { index, set in
            let exerciseSet = ExerciseSet(
                repetitions: set.reps,
                weight: set.weight,
                done: true,
                setType: set.type,
                orderIndex: index,
                usedMetric: .metric
            )
            exerciseSet.weightType = set.unit
            return exerciseSet
        }
        workout.exercises = [entry]
        context.insert(workout)
        return workout
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}

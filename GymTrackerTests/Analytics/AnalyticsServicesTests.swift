import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class AnalyticsServicesTests: XCTestCase {
    func testTrainingConsistencyAnalytics() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let refDate = Date(timeIntervalSince1970: 1_700_000_000)

        // Workout 1: 1 week ago
        let w1 = Workout(name: "Workout 1", endTime: refDate.addingTimeInterval(-7 * 86_400))
        w1.startTime = refDate.addingTimeInterval(-7 * 86_400)
        context.insert(w1)

        // Workout 2: 5 weeks ago
        let w2 = Workout(name: "Workout 2", endTime: refDate.addingTimeInterval(-35 * 86_400))
        w2.startTime = refDate.addingTimeInterval(-35 * 86_400)
        context.insert(w2)

        try context.save()

        let service = TrainingConsistencyAnalyticsService(modelContext: context)
        let analytics = try service.analytics(referenceDate: refDate, weekCount: 8)

        XCTAssertEqual(analytics.weeklyFrequency.count, 8)
        XCTAssertGreaterThanOrEqual(analytics.recentFourWeeksWorkoutCount, 1)
        XCTAssertNotNil(analytics.takeawayText)
    }

    func testExerciseProgressAnalyticsServiceGroupsByIdentityAndSourceRef() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        context.insert(exercise)

        let w1 = Workout(name: "Workout 1", endTime: Date(timeIntervalSince1970: 1_700_000_000))
        w1.startTime = Date(timeIntervalSince1970: 1_700_000_000)

        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let set1 = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        entry.sets = [set1]
        w1.exercises = [entry]

        context.insert(w1)
        try context.save()

        let service = ExerciseProgressAnalyticsService(modelContext: context)
        let series = try service.series(dateRange: .allTime, referenceDate: Date(timeIntervalSince1970: 1_700_000_000), displayWeightType: .kg)

        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series.first?.name, "Bench Press")
        XCTAssertEqual(series.first?.loadPoints.first?.value, 100)
        XCTAssertEqual(series.first?.loadPoints.first?.source.workoutID, w1.id)
    }

    func testPersonalRecordAnalyticsServiceReturnsSourceReference() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.upperChest])
        context.insert(exercise)

        let w1 = Workout(name: "Leg Day", endTime: Date(timeIntervalSince1970: 1_700_000_000))
        w1.startTime = Date(timeIntervalSince1970: 1_700_000_000)

        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let set1 = ExerciseSet(repetitions: 5, weight: 140, done: true, usedMetric: .metric)
        entry.sets = [set1]
        w1.exercises = [entry]

        context.insert(w1)
        try context.save()

        let service = PersonalRecordAnalyticsService(modelContext: context)
        let records = try service.personalRecords(dateRange: .allTime, referenceDate: Date(timeIntervalSince1970: 1_700_000_000), displayWeightType: .kg)

        XCTAssertFalse(records.isEmpty)
        XCTAssertTrue(records.contains { $0.exerciseName == "Squat" && $0.value == 140 })
        XCTAssertEqual(records.first?.source.workoutID, w1.id)
    }

    func testObservedWorkoutProjectionsMatchFetchBackedServices() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let exercise = Exercise(name: "Observed Bench", primaryMuscles: [.upperChest])
        let workout = Workout(name: "Observed Workout", endTime: referenceDate)
        workout.startTime = referenceDate.addingTimeInterval(-86_400)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)]
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let observed = [workout]
        let fetchedConsistency = try TrainingConsistencyAnalyticsService(modelContext: context)
            .analytics(referenceDate: referenceDate, weekCount: 8)
        let observedConsistency = TrainingConsistencyAnalyticsService.analytics(
            workouts: observed,
            referenceDate: referenceDate,
            weekCount: 8
        )
        XCTAssertEqual(observedConsistency, fetchedConsistency)

        let fetchedRecords = try PersonalRecordAnalyticsService(modelContext: context)
            .personalRecords(referenceDate: referenceDate)
        let observedRecords = PersonalRecordAnalyticsService.personalRecords(
            workouts: observed,
            referenceDate: referenceDate
        )
        XCTAssertEqual(observedRecords, fetchedRecords)

        let fetchedSeries = try ExerciseProgressAnalyticsService(modelContext: context)
            .series(referenceDate: referenceDate)
        let observedSeries = ExerciseProgressAnalyticsService.series(
            workouts: observed,
            referenceDate: referenceDate
        )
        XCTAssertEqual(observedSeries, fetchedSeries)
    }

    func testPersonalRecordsIgnoreWarmupsAndCompareLoadsInDisplayUnits() throws {
        let exercise = Exercise(name: "Mixed-unit squat", primaryMuscles: [.quadriceps])
        let older = Workout(name: "Older", endTime: Date(timeIntervalSince1970: 1_000))
        older.startTime = Date(timeIntervalSince1970: 900)
        let olderEntry = ExerciseEntry(exercise: exercise, usedMetric: .imperial)
        let pounds = ExerciseSet(repetitions: 5, weight: 240, done: true, usedMetric: .imperial)
        pounds.weightType = .lbs
        olderEntry.sets = [pounds]
        older.exercises = [olderEntry]

        let latest = Workout(name: "Latest", endTime: Date(timeIntervalSince1970: 2_000))
        latest.startTime = Date(timeIntervalSince1970: 1_900)
        let latestEntry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let warmup = ExerciseSet(repetitions: 5, weight: 200, done: true, setType: .warmup, usedMetric: .metric)
        let kilograms = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        latestEntry.sets = [warmup, kilograms]
        latest.exercises = [latestEntry]

        let records = PersonalRecordAnalyticsService.personalRecords(
            workouts: [older, latest],
            displayWeightType: .kg
        )
        let maxWeight = try XCTUnwrap(records.first { $0.kind == "Max Weight" })
        XCTAssertEqual(maxWeight.value, UnitConversion.weight(240, from: .lbs, to: .kg), accuracy: 0.01)
        XCTAssertEqual(maxWeight.unit, WeightType.kg.rawValue)
        XCTAssertEqual(maxWeight.source.setID, pounds.id)
    }

    func testExerciseProgressExcludesWarmupAndNonFiniteValues() {
        let exercise = Exercise(name: "Progress squat", primaryMuscles: [.quadriceps])
        let workout = Workout(name: "Session", endTime: Date(timeIntervalSince1970: 2_000))
        workout.startTime = Date(timeIntervalSince1970: 1_000)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let warmup = ExerciseSet(repetitions: 5, weight: 200, done: true, setType: .warmup, usedMetric: .metric)
        let working = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        let invalid = ExerciseSet(repetitions: .nan, weight: 900, done: true, usedMetric: .metric)
        entry.sets = [warmup, working, invalid]
        workout.exercises = [entry]

        let series = ExerciseProgressAnalyticsService.series(workouts: [workout], displayWeightType: .kg)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].loadPoints.map(\.value), [100])
        XCTAssertEqual(series[0].volumePoints.map(\.value), [500])
        XCTAssertEqual(series[0].repsPoints.map(\.value), [5])
    }

    func testExerciseProgressDoesNotTreatLegacyWeightAsLoadForRepsOnlyExercise() {
        let exercise = Exercise(name: "Legacy push-up", primaryMuscles: [.upperChest])
        exercise.trackingType = .repsOnly
        let workout = Workout(name: "Session", endTime: Date(timeIntervalSince1970: 2_000))
        workout.startTime = Date(timeIntervalSince1970: 1_000)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.trackingTypeSnapshot = .repsOnly
        entry.sets = [ExerciseSet(repetitions: 20, weight: 100, done: true, usedMetric: .metric)]
        workout.exercises = [entry]

        let series = ExerciseProgressAnalyticsService.series(workouts: [workout], displayWeightType: .kg)

        XCTAssertTrue(series[0].loadPoints.isEmpty)
        XCTAssertTrue(series[0].volumePoints.isEmpty)
        XCTAssertEqual(series[0].repsPoints.map(\.value), [20])
    }

    func testStrongmanLoadConventionsProduceIndependentRecordsAndProgressSeries() {
        let exercise = Exercise(name: "Strongman Medley", primaryMuscles: [.trapezius])
        let workout = Workout(name: "Convention day", endTime: Date(timeIntervalSince1970: 2_000))
        workout.startTime = Date(timeIntervalSince1970: 1_000)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let total = ExerciseSet(repetitions: 2, weight: 200, done: true, usedMetric: .metric)
        total.strongmanLoadConvention = .total
        let perHand = ExerciseSet(repetitions: 4, weight: 110, done: true, usedMetric: .metric)
        perHand.strongmanLoadConvention = .perHand
        entry.sets = [total, perHand]
        workout.exercises = [entry]

        let records = PersonalRecordAnalyticsService.personalRecords(
            workouts: [workout],
            displayWeightType: .kg
        )
        let series = ExerciseProgressAnalyticsService.series(
            workouts: [workout],
            displayWeightType: .kg
        )

        XCTAssertEqual(records.filter { $0.kind == "Max Weight" }.map(\.value).sorted(), [110, 200])
        XCTAssertEqual(records.filter { $0.kind == "Best Set Volume" }.map(\.value).sorted(), [400, 440])
        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series.flatMap(\.loadPoints).map(\.value).sorted(), [110, 200])
    }

    func testDistancePolicyRejectsNonFiniteHistoricalValues() {
        XCTAssertNil(WorkoutDistancePolicy.meters(storedValue: .nan, storedUnit: .kilometers))
        XCTAssertNil(WorkoutDistancePolicy.meters(storedValue: .infinity, storedUnit: .miles))
        XCTAssertNil(WorkoutDistancePolicy.displayMeasurement(
            storedValue: -.infinity,
            storedUnit: .meters,
            system: .metric
        ))
    }
}

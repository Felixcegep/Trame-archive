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
}

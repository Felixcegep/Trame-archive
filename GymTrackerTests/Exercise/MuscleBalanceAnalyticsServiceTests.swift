import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MuscleBalanceAnalyticsServiceTests: XCTestCase {
    func testCountsPrimaryAndSecondaryWorkingSetsAndExcludesWarmups() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
            secondaryMuscles: [.frontDeltoid]
        )
        context.insert(exercise)
        insertWorkout(
            exercise: exercise,
            date: referenceDate,
            setTypes: [.warmup, .normal, .normal],
            in: context
        )
        try context.save()

        let analytics = try MuscleBalanceAnalyticsService(modelContext: context)
            .analytics(referenceDate: referenceDate)
        let currentWeek = try XCTUnwrap(analytics.weeks.last)

        XCTAssertEqual(currentWeek.count(for: .chest), 2)
        XCTAssertEqual(currentWeek.count(for: .deltoids), 1)
    }

    func testNonStandardSetsDoNotContributeToMuscleBalance() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        context.insert(exercise)
        insertWorkout(exercise: exercise, date: referenceDate, setTypes: [.normal, .normal], in: context)
        let workout = try XCTUnwrap(try context.fetch(FetchDescriptor<Workout>()).first)
        workout.orderedExercises[0].orderedSets[0].setMethod = .cluster
        try context.save()

        let analytics = try MuscleBalanceAnalyticsService(modelContext: context)
            .analytics(referenceDate: referenceDate)

        XCTAssertEqual(analytics.weeks.last?.count(for: .chest), 1)
    }

    func testActiveWorkoutsDoNotContributeToBalance() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Deadlift", primaryMuscles: [.hamstrings])
        context.insert(exercise)
        insertWorkout(exercise: exercise, date: referenceDate, setTypes: [.normal], in: context)

        let active = Workout(name: "Active")
        active.startTime = referenceDate
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetitions: 8, weight: 100, done: true, usedMetric: .metric)]
        active.exercises = [entry]
        context.insert(active)
        try context.save()

        let analytics = try MuscleBalanceAnalyticsService(modelContext: context)
            .analytics(referenceDate: referenceDate)
        XCTAssertEqual(analytics.weeks.last?.count(for: .hamstrings), 1)
    }

    func testLowerRecentWorkCreatesAnEstimatedImbalanceCallout() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Deadlift", primaryMuscles: [.hamstrings])
        context.insert(exercise)
        insertWorkout(exercise: exercise, date: weeksAgo(6), setTypes: [.normal, .normal, .normal], in: context)
        insertWorkout(exercise: exercise, date: weeksAgo(5), setTypes: [.normal, .normal, .normal], in: context)
        insertWorkout(exercise: exercise, date: weeksAgo(4), setTypes: [.normal, .normal, .normal], in: context)
        try context.save()

        let analytics = try MuscleBalanceAnalyticsService(modelContext: context)
            .analytics(referenceDate: referenceDate)
        XCTAssertTrue(analytics.callouts.contains { $0.group == .hamstrings })
        XCTAssertTrue(analytics.callouts.contains { $0.message.contains("Hamstrings") })
        XCTAssertTrue(analytics.callouts.contains { $0.message.contains("estimated sets per week") })
        XCTAssertTrue(analytics.callouts.contains { $0.message.contains("previous four weeks") })
    }

    func testEmptyHistoryReturnsEightEmptyWeeks() throws {
        let context = try makeContext()
        let analytics = try MuscleBalanceAnalyticsService(modelContext: context)
            .analytics(referenceDate: referenceDate)

        XCTAssertFalse(analytics.hasHistory)
        XCTAssertEqual(analytics.weeks.count, 8)
        XCTAssertTrue(analytics.summaries.isEmpty)
        XCTAssertTrue(analytics.callouts.isEmpty)
    }

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func weeksAgo(_ count: Int) -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: .weekOfYear, value: -count, to: referenceDate)!
    }

    private func insertWorkout(
        exercise: Exercise,
        date: Date,
        setTypes: [SetType],
        in context: ModelContext
    ) {
        let workout = Workout(name: "Balance Fixture", endTime: date.addingTimeInterval(3_600))
        workout.startTime = date
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = setTypes.enumerated().map { index, setType in
            ExerciseSet(
                repetitions: 8,
                weight: 50,
                done: true,
                setType: setType,
                orderIndex: index,
                usedMetric: .metric
            )
        }
        workout.exercises = [entry]
        context.insert(workout)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}

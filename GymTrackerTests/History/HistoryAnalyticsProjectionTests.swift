import Foundation
import XCTest
@testable import GymTracker

@MainActor
final class HistoryAnalyticsProjectionTests: XCTestCase {
    func testProgressProjectionKeepsOneHistoricalIdentityChronologicalAndCountsFrequency() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = date(2026, 8, 12, calendar: calendar)
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest], isCustom: true)

        let older = completedWorkout(
            title: "Older",
            start: date(2026, 8, 4, calendar: calendar),
            exercise: exercise,
            set: ExerciseSet(repetitions: 5, weight: 80, done: true, usedMetric: .metric)
        )
        let newerEntry = ExerciseEntry(
            exercise: exercise,
            sets: [ExerciseSet(repetitions: 6, weight: 85, done: true, usedMetric: .metric)],
            usedMetric: .metric
        )
        // A snapshot rename must update the label but never split the trend.
        newerEntry.nameSnapshot = "Renamed Bench"
        let newer = Workout(name: "Newer", endTime: date(2026, 8, 11, calendar: calendar))
        newer.startTime = date(2026, 8, 11, calendar: calendar)
        newer.exercises = [newerEntry]

        let projection = HistoryProgressProjection.make(
            workouts: [newer, older],
            displayWeightType: .kg,
            calendar: calendar,
            referenceDate: reference
        )

        let series = try XCTUnwrap(projection.exerciseSeries.first)
        XCTAssertEqual(projection.exerciseSeries.count, 1)
        XCTAssertEqual(series.name, "Renamed Bench")
        XCTAssertEqual(series.loadPoints.map(\.value), [80, 85])
        XCTAssertEqual(series.repsPoints.map(\.value), [5, 6])
        XCTAssertEqual(projection.frequencyPoints.reduce(0) { $0 + $1.count }, 2)
    }

    func testRecordsProjectionUsesTraditionalWorkingSetsForRecordsAndVolume() {
        let exercise = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps], isCustom: true)
        let workingSet = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        let warmupSet = ExerciseSet(
            repetitions: 5,
            weight: 140,
            done: true,
            setType: .warmup,
            orderIndex: 1,
            usedMetric: .metric
        )
        let workout = completedWorkout(
            title: "Squat day",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: exercise,
            set: workingSet
        )
        workout.exercises.first?.sets.append(warmupSet)

        let projection = HistoryRecordsProjection.make(workouts: [workout], displayWeightType: .kg)

        XCTAssertEqual(projection.loadRecords.map(\.value), [100])
        XCTAssertEqual(projection.repRecords.map(\.value), [5])
        XCTAssertEqual(projection.notableSessions.map(\.volume), [500])
    }

    func testRecordsProjectionRetainsOnlyTopThreeNotableSessionsInOrder() {
        let exercise = Exercise(name: "Deadlift", primaryMuscles: [.latissimusDorsi], isCustom: true)
        let volumes: [Float] = [100, 500, 300, 400, 200]
        let workouts = volumes.enumerated().map { index, volume in
            completedWorkout(
                title: "Session \(index)",
                start: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                exercise: exercise,
                set: ExerciseSet(
                    repetitions: 1,
                    weight: volume,
                    done: true,
                    usedMetric: .metric
                )
            )
        }

        let projection = HistoryRecordsProjection.make(
            workouts: workouts,
            displayWeightType: .kg
        )

        XCTAssertEqual(projection.notableSessions.map(\.volume), [500, 400, 300])
    }

    func testStrongmanLoadConventionsProduceIndependentHistorySeriesAndLoadRecords() {
        let exercise = Exercise(name: "Strongman Medley", primaryMuscles: [.trapezius], isCustom: true)
        let workout = Workout(name: "Convention day", endTime: Date(timeIntervalSince1970: 2_000))
        workout.startTime = Date(timeIntervalSince1970: 1_000)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let total = ExerciseSet(repetitions: 2, weight: 200, done: true, usedMetric: .metric)
        total.strongmanLoadConvention = .total
        let perHand = ExerciseSet(repetitions: 4, weight: 110, done: true, usedMetric: .metric)
        perHand.strongmanLoadConvention = .perHand
        entry.sets = [total, perHand]
        workout.exercises = [entry]

        let progress = HistoryProgressProjection.make(
            workouts: [workout],
            displayWeightType: .kg,
            referenceDate: Date(timeIntervalSince1970: 2_000)
        )
        let records = HistoryRecordsProjection.make(workouts: [workout], displayWeightType: .kg)

        XCTAssertEqual(progress.exerciseSeries.count, 2)
        XCTAssertEqual(progress.exerciseSeries.flatMap(\.loadPoints).map(\.value).sorted(), [110, 200])
        XCTAssertEqual(records.loadRecords.map(\.value).sorted(), [110, 200])
    }

    private func completedWorkout(title: String, start: Date, exercise: Exercise, set: ExerciseSet) -> Workout {
        let workout = Workout(name: title, endTime: start.addingTimeInterval(3_600))
        workout.startTime = start
        workout.exercises = [ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)]
        return workout
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

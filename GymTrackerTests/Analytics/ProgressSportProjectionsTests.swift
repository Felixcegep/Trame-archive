import Foundation
import XCTest
@testable import GymTracker

@MainActor
final class ProgressSportProjectionsTests: XCTestCase {
    func testFocusTimelineUsesWorkoutDaysRatherThanEntryCountsAndKeepsUnknownVisible() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 UTC-ish
        let interval = DateInterval(start: reference, duration: 14 * 86_400)
        let power = makeWorkout(date: reference.addingTimeInterval(86_400), disciplines: [.powerlifting])
        let mixed = makeWorkout(date: reference.addingTimeInterval(2 * 86_400), disciplines: [.powerlifting, .bodybuilding, .bodybuilding])
        let unknown = makeWorkout(date: reference.addingTimeInterval(3 * 86_400), disciplines: [nil])

        let timeline = ProgressSportFocusTimeline.project(workouts: [power, mixed, unknown], interval: interval, calendar: calendar)
        let slices = timeline.periods.flatMap(\.slices)

        XCTAssertEqual(timeline.periods.map(\.completedWorkoutCount).reduce(0, +), 3)
        XCTAssertEqual(slices.first(where: { $0.discipline == .powerlifting })?.proportion ?? -1, 1.5 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(slices.first(where: { $0.discipline == .bodybuilding })?.proportion ?? -1, 1.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(slices.first(where: { $0.discipline == nil })?.proportion ?? -1, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testLensAvailabilityCoversEveryDisciplineAndReadsSnapshotsOnly() {
        let exercise = makeExercise(discipline: .powerlifting)
        let workout = makeWorkout(date: .now, entries: [ExerciseEntry(exercise: exercise, usedMetric: .metric)])
        exercise.sportDisciplineRaw = SportDiscipline.bodybuilding.rawValue

        let result = ProgressSportLensAvailabilityProjector.project(workouts: [workout], primary: .powerlifting)
        XCTAssertEqual(result.map(\.discipline), SportDiscipline.allCases)
        XCTAssertEqual(result.first(where: { $0.discipline == .powerlifting })?.evidenceWorkoutCount, 1)
        XCTAssertTrue(result.first(where: { $0.discipline == .powerlifting })?.isProfilePriority == true)
        XCTAssertEqual(result.first(where: { $0.discipline == .bodybuilding })?.evidenceWorkoutCount, 0)
    }

    func testSuggestionIsRecencyWeightedAndNeverMutatesProfile() {
        let reference = Date(timeIntervalSince1970: 1_735_689_600)
        let recent = (0..<4).map { index in
            makeWorkout(date: reference.addingTimeInterval(Double(index) * 86_400), disciplines: [.powerlifting])
        }
        let old = (0..<4).map { index in
            makeWorkout(date: reference.addingTimeInterval(Double(-180 - index) * 86_400), disciplines: [.bodybuilding])
        }

        let suggestion = SportProfileSuggestionService.suggest(workouts: recent + old, referenceDate: reference.addingTimeInterval(5 * 86_400))
        XCTAssertEqual(suggestion?.discipline, .powerlifting)
        XCTAssertEqual(suggestion?.completedWorkoutCount, 4)
        XCTAssertFalse(suggestion?.evidence.isEmpty ?? true)
    }

    func testGlobalProjectionExposesOnlyMeasuredSnapshotValues() {
        let power = makeExercise(discipline: .powerlifting)
        let entry = ExerciseEntry(exercise: power, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetitions: 3, weight: 180, done: true, usedMetric: .metric)]
        let workout = makeWorkout(date: .now, entries: [entry], duration: 3_600)

        let projection = GlobalProgressProjection.project(workouts: [workout])
        XCTAssertEqual(projection.completedWorkoutCount, 1)
        XCTAssertEqual(projection.completedEntryCount, 1)
        XCTAssertEqual(projection.trainingTime, 3_600)
        let load = projection.sportHighlights.first { $0.discipline == .powerlifting && $0.metric == .bestLoad }
        XCTAssertEqual(load?.value, 180)
        XCTAssertEqual(load?.unit, WeightType.kg.rawValue)
    }

    func testStrengthProjectionUsesHistoricalIdentityAndRequiresExplicitThreeLiftMapping() {
        let squat = makeExercise(discipline: .powerlifting)
        squat.name = "Squat"
        let bench = makeExercise(discipline: .powerlifting)
        bench.name = "Bench"
        let deadlift = makeExercise(discipline: .powerlifting)
        deadlift.name = "Deadlift"
        let entries = [squat, bench, deadlift].map { exercise -> ExerciseEntry in
            let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
            entry.sets = [ExerciseSet(repetitions: 3, weight: 150, done: true, usedMetric: .metric)]
            return entry
        }
        let date = Date(timeIntervalSince1970: 1_735_689_600)
        let workout = makeWorkout(date: date, entries: entries)
        squat.name = "Renamed after completion"
        let interval = DateInterval(start: date.addingTimeInterval(-1), duration: 86_400)

        let withoutMapping = StrengthProgressProjection.project(workouts: [workout], discipline: .powerlifting, interval: interval)
        let withMapping = StrengthProgressProjection.project(
            workouts: [workout],
            discipline: .powerlifting,
            interval: interval,
            competitionLifts: .init(squatExerciseID: squat.id, benchExerciseID: bench.id, deadliftExerciseID: deadlift.id)
        )

        XCTAssertNil(withoutMapping.estimatedThreeLiftSum)
        XCTAssertEqual(withMapping.estimatedThreeLiftSum ?? 0, 495, accuracy: 0.001)
        XCTAssertEqual(withMapping.exerciseRecords.first(where: { $0.exerciseID == squat.id })?.name, "Squat")
    }

    func testStrengthProjectionNormalizesMixedUnitsBeforeChoosingThreeLiftMaxima() {
        let squat = makeExercise(discipline: .powerlifting)
        let bench = makeExercise(discipline: .powerlifting)
        let deadlift = makeExercise(discipline: .powerlifting)
        let entries = [squat, bench, deadlift].map { exercise -> ExerciseEntry in
            let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
            let kilograms = ExerciseSet(repetitions: 1, weight: 100, done: true, usedMetric: .metric)
            let pounds = ExerciseSet(repetitions: 1, weight: 210, done: true, usedMetric: .imperial)
            pounds.weightType = .lbs
            entry.sets = [kilograms, pounds]
            return entry
        }
        let date = Date(timeIntervalSince1970: 1_735_689_600)
        let projection = StrengthProgressProjection.project(
            workouts: [makeWorkout(date: date, entries: entries)],
            discipline: .powerlifting,
            interval: DateInterval(start: date.addingTimeInterval(-1), duration: 86_400),
            competitionLifts: .init(squatExerciseID: squat.id, benchExerciseID: bench.id, deadliftExerciseID: deadlift.id),
            displayWeightType: .kg
        )

        XCTAssertEqual(projection.estimatedThreeLiftSum ?? 0, 310, accuracy: 0.01)
        XCTAssertEqual(projection.estimatedThreeLiftSumUnit, .kg)
    }

    func testGlobalOlympicHighlightRequiresMadeAttempt() {
        let exercise = makeExercise(discipline: .olympicWeightlifting)
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let missed = ExerciseSet(repetitions: 1, weight: 120, done: true, usedMetric: .metric)
        missed.complexComponents = [
            ComplexComponentResult(
                orderIndex: 0,
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                prescribedRepetitions: 1,
                outcome: .missed
            )
        ]
        let made = ExerciseSet(repetitions: 1, weight: 100, done: true, usedMetric: .metric)
        made.complexComponents = [
            ComplexComponentResult(
                orderIndex: 0,
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                prescribedRepetitions: 1,
                performedRepetitions: 1,
                outcome: .completed
            )
        ]
        entry.sets = [missed, made]

        let projection = GlobalProgressProjection.project(workouts: [makeWorkout(date: .now, entries: [entry])])
        let load = projection.sportHighlights.first {
            $0.discipline == .olympicWeightlifting && $0.metric == .bestLoad
        }

        XCTAssertEqual(load?.value, 100)
        XCTAssertEqual(load?.evidence.first?.setID, made.id)
    }

    func testHybridProjectionComposesOnlyCompletedHistoricalRaceSplits() {
        let entry = ExerciseEntry(exercise: makeExercise(discipline: .hybridFitnessRacing), usedMetric: .metric)
        let set = ExerciseSet(done: true, usedMetric: .metric)
        let run = ExerciseSetSegment(orderIndex: 0, duration: 240, done: true, splitKind: .run, distanceMeters: 1_000)
        let transition = ExerciseSetSegment(orderIndex: 1, duration: 30, done: true, splitKind: .transition)
        let ignored = ExerciseSetSegment(orderIndex: 2, duration: 100, done: false, splitKind: .station)
        set.segments = [run, transition, ignored]
        run.exerciseSet = set
        transition.exerciseSet = set
        ignored.exerciseSet = set
        entry.sets = [set]
        let workout = makeWorkout(date: .now, entries: [entry])

        let projection = HybridRaceProgressProjection.project(workouts: [workout])

        XCTAssertEqual(projection.sessions.first?.totalTime, 270)
        XCTAssertEqual(projection.sessions.first?.runTime, 240)
        XCTAssertEqual(projection.sessions.first?.stationTime, 0)
        XCTAssertEqual(projection.sessions.first?.splits.count, 2)
    }

    func testStrongmanProjectionSeparatesEventFamiliesAndLoadConventions() {
        let exercise = makeExercise(discipline: .strongman)
        exercise.strongmanEventFamilyRaw = StrongmanEventFamily.carry.rawValue
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let total = ExerciseSet(weight: 200, distance: 20, done: true, usedMetric: .metric)
        total.strongmanLoadConventionRaw = LoadConvention.total.rawValue
        total.strongmanImplementProfile = StrongmanImplementProfile(kind: .yoke, surface: .turf)
        let perHand = ExerciseSet(weight: 110, distance: 20, done: true, usedMetric: .metric)
        perHand.strongmanLoadConventionRaw = LoadConvention.perHand.rawValue
        perHand.strongmanImplementProfile = StrongmanImplementProfile(kind: .farmersHandles, surface: .turf)
        let differentSurface = ExerciseSet(weight: 210, distance: 20, done: true, usedMetric: .metric)
        differentSurface.strongmanLoadConventionRaw = LoadConvention.total.rawValue
        differentSurface.strongmanImplementProfile = StrongmanImplementProfile(kind: .yoke, surface: .sand)
        entry.sets = [total, perHand, differentSurface]
        let workout = makeWorkout(date: .now, entries: [entry])

        let projection = StrongmanProgressProjection.project(workouts: [workout])

        XCTAssertEqual(projection.records.count, 3)
        XCTAssertEqual(Set(projection.records.map(\.comparisonKey)).count, 3)
        XCTAssertTrue(projection.records.allSatisfy { $0.family == .carry && $0.distanceMeters == 20 })
    }

    func testStrongmanCarryRequiresBothLoadAndDistance() {
        let exercise = makeExercise(discipline: .strongman)
        exercise.strongmanEventFamilyRaw = StrongmanEventFamily.carry.rawValue
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(weight: 200, done: true, usedMetric: .metric),
            ExerciseSet(distance: 20, done: true, usedMetric: .metric)
        ]

        let projection = StrongmanProgressProjection.project(
            workouts: [makeWorkout(date: .now, entries: [entry])]
        )

        XCTAssertTrue(projection.records.isEmpty)
    }

    func testBodybuildingProjectionCountsEligibleWorkingSetsOnly() {
        let entry = ExerciseEntry(exercise: makeExercise(discipline: .bodybuilding), usedMetric: .metric)
        let working = ExerciseSet(repetitions: 10, weight: 50, done: true, usedMetric: .metric)
        let warmup = ExerciseSet(repetitions: 10, weight: 20, done: true, setType: .warmup, usedMetric: .metric)
        let unfinished = ExerciseSet(repetitions: 10, weight: 50, done: false, usedMetric: .metric)
        entry.sets = [working, warmup, unfinished]
        let date = Date(timeIntervalSince1970: 1_735_689_600)
        let workout = makeWorkout(date: date, entries: [entry])
        let interval = DateInterval(start: date.addingTimeInterval(-1), duration: 86_400)

        let projection = BodybuildingProgressProjection.project(workouts: [workout], interval: interval)

        XCTAssertEqual(projection.weeklyWorkingSets.map(\.value).reduce(0, +), 1)
    }

    func testCardioProjectionNormalizesDistanceAndCalculatesPaceOnlyFromMeasuredPairs() {
        let entry = ExerciseEntry(exercise: makeExercise(discipline: .generalCardio), usedMetric: .metric)
        let kilometer = ExerciseSet(duration: 300, distance: 1, done: true, usedMetric: .metric)
        kilometer.distanceType = .kilometers
        let meters = ExerciseSet(duration: 150, distance: 500, done: true, usedMetric: .metric)
        meters.distanceType = .meters
        entry.sets = [kilometer, meters]
        let date = Date(timeIntervalSince1970: 1_735_689_600)
        let workout = makeWorkout(date: date, entries: [entry])
        let interval = DateInterval(start: date.addingTimeInterval(-1), duration: 86_400)

        let projection = CardioProgressProjection.project(workouts: [workout], interval: interval)

        XCTAssertEqual(projection.totalDistanceMeters, 1_500)
        XCTAssertEqual(projection.totalDuration, 450)
        XCTAssertEqual(projection.averagePaceSecondsPerKilometer, 300)
    }

    func testMixedProjectionSplitsEachWorkoutOnceAcrossSnapshotDisciplines() {
        let date = Date(timeIntervalSince1970: 1_735_689_600)
        let mixed = makeWorkout(date: date, disciplines: [.powerlifting, .bodybuilding, .bodybuilding])
        let cardio = makeWorkout(date: date.addingTimeInterval(600), disciplines: [.generalCardio])
        let interval = DateInterval(start: date.addingTimeInterval(-1), duration: 86_400)

        let projection = MixedProgressProjection.project(workouts: [mixed, cardio], interval: interval)

        XCTAssertEqual(projection.completedWorkoutCount, 2)
        XCTAssertEqual(projection.composition.first(where: { $0.discipline == .powerlifting })?.proportion, 0.25)
        XCTAssertEqual(projection.composition.first(where: { $0.discipline == .bodybuilding })?.proportion, 0.25)
        XCTAssertEqual(projection.composition.first(where: { $0.discipline == .generalCardio })?.proportion, 0.5)
    }

    private func makeExercise(discipline: SportDiscipline?) -> Exercise {
        let exercise = Exercise(name: "Test lift", primaryMuscles: [.quadriceps])
        exercise.sportDisciplineRaw = discipline?.rawValue
        return exercise
    }

    private func makeWorkout(date: Date, disciplines: [SportDiscipline?]) -> Workout {
        let entries = disciplines.map { discipline in
            let entry = ExerciseEntry(exercise: makeExercise(discipline: discipline), usedMetric: .metric)
            if discipline == nil { entry.sportDisciplineSnapshotRaw = nil }
            return entry
        }
        return makeWorkout(date: date, entries: entries)
    }

    private func makeWorkout(date: Date, entries: [ExerciseEntry], duration: TimeInterval = 600) -> Workout {
        let workout = Workout(name: "Test", endTime: date.addingTimeInterval(duration))
        workout.startTime = date
        workout.exercises = entries
        return workout
    }
}

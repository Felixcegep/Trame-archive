import XCTest
@testable import GymTracker

@MainActor
final class WeightliftingAnalyticsProjectionTests: XCTestCase {
    func testBestSuccessfulLiftUsesCompletedMadeEvidenceAndKeepsUnitsSeparate() {
        let kg = makeWorkout(date: Date(timeIntervalSince1970: 100), weight: 100, outcomes: [.completed, .completed])
        let heavierMiss = makeWorkout(date: Date(timeIntervalSince1970: 200), weight: 120, outcomes: [.completed, .missed])
        let active = makeWorkout(date: Date(timeIntervalSince1970: 300), weight: 140, outcomes: [.completed, .completed], completed: false)
        let pounds = makeWorkout(date: Date(timeIntervalSince1970: 400), weight: 225, outcomes: [.completed, .completed])
        pounds.set.weightType = .lbs

        let projection = WeightliftingAnalyticsProjection.project(
            workouts: [kg.workout, heavierMiss.workout, active.workout, pounds.workout]
        )

        XCTAssertNil(projection.bestCompleteSuccessfulLift)
        XCTAssertEqual(projection.bestCompleteSuccessfulLiftsByUnit.count, 2)
        XCTAssertTrue(projection.bestCompleteSuccessfulLiftsByUnit.contains { $0.weight == 100 && $0.weightType == .kg })
        XCTAssertTrue(projection.bestCompleteSuccessfulLiftsByUnit.contains { $0.weight == 225 && $0.weightType == .lbs })
        XCTAssertEqual(projection.complexOutcomes.count, 3)
        XCTAssertEqual(projection.complexOutcomes[1].outcome, .missed)
    }

    func testCleanAndJerkSuccessRequiresExplicitRolesAndCompleteRepetitions() {
        let cleanID = UUID()
        let jerkID = UUID()
        let successful = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            weight: 90,
            componentIDs: [cleanID, jerkID],
            outcomes: [.completed, .completed],
            componentRoles: [cleanID: .clean, jerkID: .jerk]
        )
        let missedJerk = makeWorkout(
            date: Date(timeIntervalSince1970: 200),
            weight: 95,
            componentIDs: [cleanID, jerkID],
            outcomes: [.completed, .missed],
            componentRoles: [cleanID: .clean, jerkID: .jerk]
        )

        let configuration = WeightliftingAnalyticsConfiguration(
            componentRolesByExerciseID: [cleanID: .clean, jerkID: .jerk]
        )
        let projection = WeightliftingAnalyticsProjection.project(
            workouts: [successful.workout, missedJerk.workout],
            configuration: configuration
        )

        XCTAssertEqual(projection.cleanSuccess?.attempts, 2)
        XCTAssertEqual(projection.cleanSuccess?.successes, 2)
        XCTAssertEqual(projection.jerkAfterCleanSuccess?.attempts, 2)
        XCTAssertEqual(projection.jerkAfterCleanSuccess?.successes, 1)
    }

    func testFailureDistributionRetainsComponentOutcomesAndUnknownRole() {
        let cleanID = UUID()
        let unknownID = UUID()
        let fixture = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            weight: 80,
            componentIDs: [cleanID, unknownID],
            outcomes: [.partial, .missed],
            componentRoles: [cleanID: .clean]
        )

        let projection = WeightliftingAnalyticsProjection.project(
            workouts: [fixture.workout],
            configuration: WeightliftingAnalyticsConfiguration(componentRolesByExerciseID: [cleanID: .clean])
        )

        let clean = projection.componentFailureDistribution.first { $0.role == .clean }
        let unknown = projection.componentFailureDistribution.first { $0.role == .unknown }
        XCTAssertEqual(clean?.partial, 1)
        XCTAssertEqual(clean?.failures, 1)
        XCTAssertEqual(unknown?.missed, 1)
        XCTAssertEqual(projection.complexOutcomes.first?.components.map(\.role), [.clean, .unknown])
    }

    func testSuccessRateUsesOnlyAuthoredSetTypeGroupAndQualityIsDescriptive() {
        let top = makeWorkout(date: Date(timeIntervalSince1970: 100), weight: 90, outcomes: [.completed, .completed], quality: .excellent)
        top.set.prescribedSetType = .topSet
        let topMiss = makeWorkout(date: Date(timeIntervalSince1970: 200), weight: 95, outcomes: [.completed, .missed], quality: .missed)
        topMiss.set.prescribedSetType = .topSet
        let ungrouped = makeWorkout(date: Date(timeIntervalSince1970: 300), weight: 80, outcomes: [.completed, .completed], quality: .acceptable)

        let group = WeightliftingAuthoredIntensityGroup(id: "heavy")
        let projection = WeightliftingAnalyticsProjection.project(
            workouts: [top.workout, topMiss.workout, ungrouped.workout],
            configuration: WeightliftingAnalyticsConfiguration(
                intensityGroupsByPrescribedSetTypeRaw: [SetType.topSet.rawValue: group]
            )
        )

        XCTAssertEqual(projection.successRatesByIntensityGroup.count, 1)
        XCTAssertEqual(projection.successRatesByIntensityGroup.first?.attempts, 2)
        XCTAssertEqual(projection.successRatesByIntensityGroup.first?.successes, 1)
        XCTAssertEqual(projection.qualityTrend.count, 3)
        XCTAssertEqual(projection.qualityTrend.map(\.sampleCount), [1, 1, 1])
    }

    private struct Fixture {
        let workout: Workout
        let set: ExerciseSet
    }

    private func makeWorkout(
        date: Date,
        weight: Float,
        componentIDs: [UUID] = [UUID(), UUID()],
        outcomes: [ComplexComponentOutcome],
        componentRoles: [UUID: WeightliftingComponentRole] = [:],
        quality: LiftQuality? = nil,
        completed: Bool = true
    ) -> Fixture {
        let exercise = Exercise(name: "Clean and jerk", primaryMuscles: [.quadriceps])
        exercise.sportDisciplineRaw = SportDiscipline.olympicWeightlifting.rawValue
        let workout = Workout(name: "Olympic session", endTime: completed ? date : nil)
        workout.startTime = date
        workout.status = completed ? .completed : .active
        let entry = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
        entry.sportDisciplineSnapshotRaw = SportDiscipline.olympicWeightlifting.rawValue
        let set = ExerciseSet(repetitions: 2, weight: weight, done: true, liftQuality: quality, usedMetric: .metric)
        set.complexComponents = zip(componentIDs, outcomes).enumerated().map { index, pair in
            ComplexComponentResult(
                orderIndex: index,
                exerciseID: pair.0,
                exerciseNameSnapshot: index == 0 ? "Clean" : "Jerk",
                prescribedRepetitions: 1,
                performedRepetitions: pair.1 == .completed ? 1 : 0,
                outcome: pair.1,
                liftQuality: pair.1 == .completed ? .acceptable : .missed
            )
        }
        entry.sets = [set]
        workout.exercises = [entry]
        _ = componentRoles
        return Fixture(workout: workout, set: set)
    }
}

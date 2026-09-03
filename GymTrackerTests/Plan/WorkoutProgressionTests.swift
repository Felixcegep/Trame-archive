import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutProgressionTests: XCTestCase {
    func testUnitConversionPreservesEquivalentLoad() {
        XCTAssertEqual(UnitConversion.weight(100, from: .kg, to: .lbs), 220.462_26, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.weight(220.462_26, from: .lbs, to: .kg), 100, accuracy: 0.001)
    }

    func testRestTimerSessionTransitionsThroughPauseAndResume() {
        let session = RestTimerSession()
        let endDate = Date.now.addingTimeInterval(90)

        session.start(until: endDate)
        XCTAssertEqual(session.endDate, endDate)
        XCTAssertTrue(session.isVisible)

        session.pause(remaining: 45)
        XCTAssertEqual(session.pausedRemaining, 45)
        XCTAssertNil(session.endDate)

        session.extendPaused(by: 15)
        XCTAssertEqual(session.pausedRemaining, 60)

        session.cancel()
        XCTAssertFalse(session.isVisible)
    }

    func testRestTimerSessionRestoresExpiredDeadlineAsReady() {
        let session = RestTimerSession()

        session.restore(endDate: Date.now.addingTimeInterval(-1), pausedRemaining: nil)

        XCTAssertTrue(session.isReady)
        XCTAssertTrue(session.isVisible)
    }

    func testExerciseActiveDurationAccumulatesAcrossSelectionsAndRelaunches() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        context.insert(exercise)
        context.insert(entry)

        entry.startActiveDuration(at: startedAt)
        entry.stopActiveDuration(at: startedAt.addingTimeInterval(42))
        entry.startActiveDuration(at: startedAt.addingTimeInterval(60))
        try context.save()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciseEntry>()).first)
        XCTAssertEqual(restored.activeDuration(at: startedAt.addingTimeInterval(78)), 60, accuracy: 0.001)

        restored.stopActiveDuration(at: startedAt.addingTimeInterval(78))
        XCTAssertEqual(restored.accumulatedActiveDuration, 60, accuracy: 0.001)
        XCTAssertNil(restored.activeDurationStartedAt)
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

    func testDoubleProgressionHoldsLoadWhenAnyRequiredSetIsBelowTheRepCeiling() {
        let performance = PreviousExercisePerformance(
            workoutDate: .now,
            sets: [
                previousSet(order: 0, reps: 12, weight: 100),
                previousSet(order: 1, reps: 11, weight: 100),
                previousSet(order: 2, reps: 12, weight: 100)
            ]
        )

        let recommendation = DoubleProgressionEngine.recommend(
            from: performance,
            requiredSets: 3,
            repCeiling: 12,
            increment: Constants.Progression.imperialIncrementLbs
        )

        XCTAssertEqual(recommendation?.decision, .hold)
        XCTAssertEqual(recommendation?.recommendedLoad, 100)
        XCTAssertEqual(recommendation?.evidence.completedSets, 3)
    }

    func testDoubleProgressionRequiresTheFullRequiredSetPrefix() {
        let performance = PreviousExercisePerformance(
            workoutDate: .now,
            sets: [
                previousSet(order: 0, reps: 12, weight: 100),
                previousSet(order: 1, reps: 12, weight: 100)
            ]
        )

        XCTAssertNil(
            DoubleProgressionEngine.recommend(
                from: performance,
                requiredSets: 3,
                repCeiling: 12,
                increment: Constants.Progression.imperialIncrementLbs
            )
        )
    }

    func testLoadRecommendationHoldsTodaysWorkingLoadWhenHistoryIsFarAway() {
        let resolved = LoadRecommendationRealism.resolved(
            proposed: 22.5,
            decision: .increase,
            prior: 20,
            unit: .kg,
            working: (60, .kg)
        )

        XCTAssertEqual(resolved.decision, .hold)
        XCTAssertEqual(resolved.load, 60, accuracy: 0.001)
    }

    func testLoadRecommendationKeepsHistoricalJumpWhenWorkingLoadIsClose() {
        let resolved = LoadRecommendationRealism.resolved(
            proposed: 105,
            decision: .increase,
            prior: 100,
            unit: .lbs,
            working: (100, .lbs)
        )

        XCTAssertEqual(resolved.decision, .increase)
        XCTAssertEqual(resolved.load, 105, accuracy: 0.001)
    }

    func testLoadRecommendationLeavesHistoryAloneWhenNoWorkingLoadExists() {
        let resolved = LoadRecommendationRealism.resolved(
            proposed: 105,
            decision: .increase,
            prior: 100,
            unit: .lbs,
            working: nil
        )

        XCTAssertEqual(resolved.decision, .increase)
        XCTAssertEqual(resolved.load, 105, accuracy: 0.001)
    }

    private func previousSet(order: Int, reps: Float, weight: Float) -> PreviousSetPerformance {
        PreviousSetPerformance(
            orderIndex: order,
            repetitions: reps,
            weight: weight,
            weightType: .lbs,
            duration: nil,
            distance: nil,
            distanceType: .miles,
            setType: .normal
        )
    }

}

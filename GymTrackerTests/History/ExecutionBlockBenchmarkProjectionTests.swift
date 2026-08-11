import Foundation
import XCTest
@testable import GymTracker

@MainActor
final class ExecutionBlockBenchmarkProjectionTests: XCTestCase {
    func testMatchingBlockProjectsPreviousResultAndPreservesProgramIdentity() throws {
        let firstExercise = Exercise(name: "Row", primaryMuscles: [.latissimusDorsi])
        let secondExercise = Exercise(name: "Burpee", primaryMuscles: [.quadriceps])
        let previous = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            exercises: [firstExercise, secondExercise],
            kind: .amrap,
            scoreKind: .roundsAndRepetitions,
            completedRounds: 4,
            additionalRepetitions: 3
        )
        let current = makeWorkout(
            date: Date(timeIntervalSince1970: 200),
            exercises: [firstExercise, secondExercise],
            kind: .amrap,
            scoreKind: .roundsAndRepetitions,
            completedRounds: 5,
            additionalRepetitions: 1
        )
        current.block.sourceDefinitionBlockKey = "conditioning.day-a.block-1"
        previous.block.sourceDefinitionBlockKey = "conditioning.day-a.block-1"

        let projection = ExecutionBlockBenchmarkProjectionPolicy.project(
            currentBlock: current.block,
            in: current.workout,
            previousWorkouts: [previous.workout]
        )

        XCTAssertTrue(projection.isComparable)
        XCTAssertEqual(projection.previous?.completedRounds, 4)
        XCTAssertEqual(projection.previous?.additionalRepetitions, 3)
        XCTAssertEqual(projection.previous?.sourceIdentity.stableKey, "definition:conditioning.day-a.block-1")
        XCTAssertEqual(projection.scoreDelta, 1)
    }

    func testDifferentOrderedExerciseIdentitiesAreUnavailable() {
        let row = Exercise(name: "Row", primaryMuscles: [.latissimusDorsi])
        let burpee = Exercise(name: "Burpee", primaryMuscles: [.quadriceps])
        let previous = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            exercises: [row, burpee],
            kind: .circuit,
            scoreKind: .completedWork,
            scoreValue: 10
        )
        let current = makeWorkout(
            date: Date(timeIntervalSince1970: 200),
            exercises: [burpee, row],
            kind: .circuit,
            scoreKind: .completedWork,
            scoreValue: 11
        )

        let projection = ExecutionBlockBenchmarkProjectionPolicy.project(
            currentBlock: current.block,
            in: current.workout,
            previousWorkouts: [previous.workout]
        )

        XCTAssertEqual(projection.unavailableReason, .exerciseIdentityMismatch)
    }

    func testActiveCurrentBlockCanSurfacePreviousBeforeCurrentScoreExists() {
        let exercise = Exercise(name: "Ski", primaryMuscles: [.quadriceps])
        let previous = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            exercises: [exercise],
            kind: .amrap,
            scoreKind: .roundsAndRepetitions,
            completedRounds: 6
        )
        let current = makeWorkout(
            date: Date(timeIntervalSince1970: 200),
            exercises: [exercise],
            kind: .amrap,
            scoreKind: .roundsAndRepetitions
        )
        current.workout.status = .active
        current.block.status = .inProgress

        let projection = ExecutionBlockBenchmarkProjectionPolicy.project(
            currentBlock: current.block,
            in: current.workout,
            previousWorkouts: [previous.workout]
        )

        XCTAssertNil(projection.current)
        XCTAssertEqual(projection.currentResultUnavailableReason, .currentResultUnavailable)
        XCTAssertEqual(projection.currentConfiguration.signature.kind, .amrap)
        XCTAssertEqual(projection.previous?.completedRounds, 6)
        XCTAssertTrue(projection.hasComparablePreviousResult)
        XCTAssertFalse(projection.isComparable)
        XCTAssertNil(projection.scoreDelta)
    }

    func testSourceIdentityRanksThePersonalBenchmarkCandidate() {
        let exercise = Exercise(name: "Press", primaryMuscles: [.frontDeltoid])
        let preferred = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            exercises: [exercise],
            kind: .straight,
            scoreKind: .load,
            scoreValue: 80
        )
        preferred.block.sourceDefinitionBlockKey = "program-a.day-1.press"
        let unrelated = makeWorkout(
            date: Date(timeIntervalSince1970: 300),
            exercises: [exercise],
            kind: .straight,
            scoreKind: .load,
            scoreValue: 120
        )
        unrelated.block.sourceDefinitionBlockKey = "program-b.day-1.press"
        let current = makeWorkout(
            date: Date(timeIntervalSince1970: 400),
            exercises: [exercise],
            kind: .straight,
            scoreKind: .load,
            scoreValue: 90
        )
        current.block.sourceDefinitionBlockKey = "program-a.day-1.press"

        let projection = ExecutionBlockBenchmarkProjectionPolicy.project(
            currentBlock: current.block,
            in: current.workout,
            previousWorkouts: [unrelated.workout, preferred.workout]
        )

        XCTAssertEqual(projection.previous?.scoreValue, 80)
        XCTAssertEqual(projection.previous?.sourceIdentity.stableKey, "definition:program-a.day-1.press")
    }

    func testConfigurationDifferencesHaveExplicitReasons() {
        let exercise = Exercise(name: "Run", primaryMuscles: [.quadriceps])
        let cases: [(ExecutionBlockBenchmarkUnavailabilityReason, (WorkoutExecutionBlock) -> Void)] = [
            (.blockKindMismatch, { $0.kind = .circuit }),
            (.scoreKindMismatch, { $0.scoreKind = .distance }),
            (.clockConfigurationMismatch, { $0.timeCapSeconds = 900 }),
            (.targetRoundsMismatch, { $0.targetRounds = 4 }),
            (.repetitionSchemeMismatch, { $0.repetitionScheme = .ascendingLadder })
        ]

        for (expected, mutatePrevious) in cases {
            let previous = makeWorkout(
                date: Date(timeIntervalSince1970: 100),
                exercises: [exercise],
                kind: .amrap,
                scoreKind: .completedWork,
                scoreValue: 10
            )
            let current = makeWorkout(
                date: Date(timeIntervalSince1970: 200),
                exercises: [exercise],
                kind: .amrap,
                scoreKind: .completedWork,
                scoreValue: 11
            )
            mutatePrevious(previous.block)

            let projection = ExecutionBlockBenchmarkProjectionPolicy.project(
                currentBlock: current.block,
                in: current.workout,
                previousWorkouts: [previous.workout]
            )

            XCTAssertEqual(projection.unavailableReason, expected)
        }
    }

    func testMissingPreviousScoreIsNotPresentedAsZero() {
        let exercise = Exercise(name: "Bike", primaryMuscles: [.quadriceps])
        let previous = makeWorkout(
            date: Date(timeIntervalSince1970: 100),
            exercises: [exercise],
            kind: .straight,
            scoreKind: .distance,
            scoreValue: nil
        )
        let current = makeWorkout(
            date: Date(timeIntervalSince1970: 200),
            exercises: [exercise],
            kind: .straight,
            scoreKind: .distance,
            scoreValue: 10
        )

        let projection = ExecutionBlockBenchmarkProjectionPolicy.project(
            currentBlock: current.block,
            in: current.workout,
            previousWorkouts: [previous.workout]
        )

        XCTAssertEqual(projection.unavailableReason, .scoreValueMissing)
        XCTAssertNil(projection.previous)
        XCTAssertNil(projection.scoreDelta)
    }

    private struct Fixture {
        let workout: Workout
        let block: WorkoutExecutionBlock
    }

    private func makeWorkout(
        date: Date,
        exercises: [Exercise],
        kind: ExerciseBlockKind,
        scoreKind: BlockScoreKind,
        completedRounds: Int = 0,
        additionalRepetitions: Int = 0,
        scoreValue: Double? = nil
    ) -> Fixture {
        let workout = Workout(name: "Benchmark", endTime: date)
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: kind,
            targetRounds: kind == .amrap ? nil : 3,
            clockMode: kind == .amrap ? .countUp : .none,
            timeCapSeconds: kind == .amrap ? 600 : nil,
            scoreKind: scoreKind
        )
        block.status = .completed
        block.completedRounds = completedRounds
        block.additionalRepetitions = additionalRepetitions
        block.scoreValue = scoreValue
        workout.executionBlocks = [block]
        workout.exercises = exercises.enumerated().map { index, exercise in
            let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
            entry.orderIndex = index
            entry.executionBlockID = block.id
            entry.executionBlockComponentOrder = index
            return entry
        }
        return Fixture(workout: workout, block: block)
    }
}

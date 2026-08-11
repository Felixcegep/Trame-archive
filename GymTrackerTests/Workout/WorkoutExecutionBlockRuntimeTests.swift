import XCTest
@testable import GymTracker

final class WorkoutExecutionBlockRuntimeTests: XCTestCase {
    func testCentralWorkflowStartsPausesAndResumesWithReceiptEvidence() {
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit, targetRounds: 3)
        let start = Date(timeIntervalSince1970: 1_000)

        let started = WorkoutExecutionBlockService.apply(
            .start(at: start),
            to: block,
            at: start
        )
        XCTAssertTrue(started.result.isApplied)
        XCTAssertEqual(started.before.status, .notStarted)
        XCTAssertEqual(started.after.status, .inProgress)

        let paused = WorkoutExecutionBlockService.apply(
            .pause(at: start.addingTimeInterval(12)),
            to: block,
            at: start.addingTimeInterval(12)
        )
        XCTAssertEqual(paused.after.status, .inProgress)
        XCTAssertEqual(paused.after.elapsedDuration, 12)

        let resumed = WorkoutExecutionBlockService.apply(
            .resume(at: start.addingTimeInterval(20)),
            to: block,
            at: start.addingTimeInterval(20)
        )
        XCTAssertEqual(resumed.after.status, .inProgress)
        XCTAssertEqual(block.elapsedStartedAt, start.addingTimeInterval(20))
    }

    func testAdvanceRoundCompletesTargetedRoundsWithoutInventingAComponentCursor() {
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .amrap, targetRounds: 2)
        let start = Date(timeIntervalSince1970: 2_000)
        _ = WorkoutExecutionBlockService.start(block, at: start)

        let first = WorkoutExecutionBlockService.apply(
            .advanceRound(at: start.addingTimeInterval(10)),
            to: block,
            at: start.addingTimeInterval(10)
        )
        XCTAssertEqual(first.after.status, .inProgress)
        XCTAssertEqual(first.after.completedRounds, 1)

        let second = WorkoutExecutionBlockService.apply(
            .advanceRound(at: start.addingTimeInterval(20)),
            to: block,
            at: start.addingTimeInterval(20)
        )
        XCTAssertEqual(second.after.status, .completed)
        XCTAssertEqual(second.after.completedRounds, 2)
        XCTAssertTrue(second.after.isPartial == false)
    }

    func testForTimeAdvanceCompletesOnePassWhileEmomAdvancesIntervals() {
        let start = Date(timeIntervalSince1970: 3_000)
        let forTime = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .forTime,
            clockMode: .countUp,
            scoreKind: .duration
        )
        _ = WorkoutExecutionBlockService.start(forTime, at: start)
        let completed = WorkoutExecutionBlockService.advanceRound(forTime, at: start.addingTimeInterval(30))
        XCTAssertTrue(completed.isApplied)
        XCTAssertEqual(forTime.status, .completed)
        XCTAssertEqual(forTime.scoreValue, 30)

        let emom = WorkoutExecutionBlock(
            orderIndex: 1,
            kind: .emom,
            clockMode: .repeatingInterval,
            timeCapSeconds: 300,
            intervalSeconds: 60,
            scoreKind: .completedWork
        )
        _ = WorkoutExecutionBlockService.start(emom, at: start)
        XCTAssertEqual(
            WorkoutExecutionBlockService.runtimeState(of: emom, at: start.addingTimeInterval(121)).currentInterval,
            3
        )
        _ = WorkoutExecutionBlockService.advanceRound(emom, at: start.addingTimeInterval(121))
        XCTAssertEqual(emom.completedRounds, 1)
    }

    func testClockCheckpointPreservesRoundAndScoreEvidenceWhileUpdatingElapsedClock() {
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit, targetRounds: 4)
        let start = Date(timeIntervalSince1970: 4_000)
        _ = WorkoutExecutionBlockService.start(block, at: start)
        block.completedRounds = 2
        block.additionalRepetitions = 5

        let receipt = WorkoutExecutionBlockService.apply(
            .checkpointClock(at: start.addingTimeInterval(18)),
            to: block,
            at: start.addingTimeInterval(18)
        )

        XCTAssertTrue(receipt.result.isApplied)
        XCTAssertEqual(receipt.after.status, .inProgress)
        XCTAssertEqual(receipt.after.completedRounds, 2)
        XCTAssertEqual(receipt.after.additionalRepetitions, 5)
        XCTAssertEqual(receipt.after.elapsedDuration, 18)
    }

    func testScoreCommandKeepsTypedScoreFieldsAndCapPreservesCappedEvidence() {
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .amrap,
            clockMode: .countUp,
            timeCapSeconds: 60,
            scoreKind: .roundsAndRepetitions
        )
        let start = Date(timeIntervalSince1970: 5_000)
        _ = WorkoutExecutionBlockService.start(block, at: start)
        let score = WorkoutExecutionBlockService.apply(
            .score(
                completedRounds: 3,
                additionalRepetitions: 7,
                scoreValue: nil,
                scoreTiebreakValue: nil
            ),
            to: block,
            at: start
        )
        XCTAssertTrue(score.result.isApplied)
        XCTAssertEqual(score.after.completedRounds, 3)
        XCTAssertEqual(score.after.additionalRepetitions, 7)

        let capped = WorkoutExecutionBlockService.apply(
            .cap(at: start.addingTimeInterval(60)),
            to: block,
            at: start.addingTimeInterval(60)
        )
        XCTAssertTrue(capped.result.isApplied)
        XCTAssertTrue(capped.after.isCapped)
        XCTAssertEqual(capped.after.status, .capped)
        XCTAssertEqual(capped.after.completedRounds, 3)
    }

    func testCompletedWorkoutRejectsEveryRuntimeMutation() {
        let workout = Workout(name: "Frozen")
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit)
        block.workout = workout
        workout.status = .completed

        let receipt = WorkoutExecutionBlockService.apply(
            .start(at: Date(timeIntervalSince1970: 6_000)),
            to: block,
            at: Date(timeIntervalSince1970: 6_000)
        )
        XCTAssertEqual(
            receipt.result,
            .rejected(.completedWorkoutMutation(.startExecutionBlock))
        )
        XCTAssertEqual(receipt.before, receipt.after)
    }
}

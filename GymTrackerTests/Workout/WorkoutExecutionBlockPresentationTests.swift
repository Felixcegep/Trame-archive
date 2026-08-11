import XCTest
@testable import GymTracker

final class WorkoutExecutionBlockPresentationTests: XCTestCase {
    func testAMRAPPresentationKeepsOrderedSequenceAndExposesRoundAdvance() {
        let presentation = WorkoutExecutionBlockPresentation.make(
            input: .init(
                kind: .amrap,
                targetRounds: nil,
                clockMode: .countUp,
                prescribedDurationSeconds: nil,
                timeCapSeconds: 600,
                intervalSeconds: nil,
                scoreKind: .roundsAndRepetitions,
                repetitionScheme: .fixed,
                componentNames: ["Pull-Up", "Push-Up"],
                status: .inProgress,
                completedRounds: 2,
                additionalRepetitions: 3,
                scoreValue: nil,
                elapsed: 65,
                isClockRunning: true
            )
        )

        XCTAssertEqual(presentation.phase, .running)
        XCTAssertEqual(presentation.timerText, "1:05")
        XCTAssertEqual(presentation.movementSequence, ["Pull-Up", "Push-Up"])
        XCTAssertEqual(presentation.scoreText, "2 + 3")
        XCTAssertEqual(presentation.primaryAction, .advance)
        XCTAssertTrue(presentation.canPause)
        XCTAssertEqual(presentation.capActionTitle, "End at cap")
    }

    func testPausedCountdownAndRepeatingIntervalExposeRestorableState() {
        let countdown = WorkoutExecutionBlockPresentation.make(
            input: .init(
                kind: .forTime,
                targetRounds: 1,
                clockMode: .countdown,
                prescribedDurationSeconds: 90,
                timeCapSeconds: nil,
                intervalSeconds: nil,
                scoreKind: .duration,
                repetitionScheme: .fixed,
                componentNames: ["Run"],
                status: .inProgress,
                completedRounds: 0,
                additionalRepetitions: 0,
                scoreValue: nil,
                elapsed: 30,
                isClockRunning: false
            )
        )
        XCTAssertEqual(countdown.phase, .paused)
        XCTAssertEqual(countdown.timerText, "1:00")
        XCTAssertEqual(countdown.pauseActionTitle, "Resume clock")
        XCTAssertEqual(countdown.primaryAction, .complete)

        let interval = WorkoutExecutionBlockPresentation.make(
            input: .init(
                kind: .emom,
                targetRounds: nil,
                clockMode: .repeatingInterval,
                prescribedDurationSeconds: nil,
                timeCapSeconds: 600,
                intervalSeconds: 60,
                scoreKind: .none,
                repetitionScheme: .fixed,
                componentNames: ["Row", "Burpee"],
                status: .inProgress,
                completedRounds: 0,
                additionalRepetitions: 0,
                scoreValue: nil,
                elapsed: 65,
                isClockRunning: true
            )
        )
        XCTAssertEqual(interval.intervalText, "Interval 2 · 0:55 remaining")
        XCTAssertEqual(interval.primaryAction, .advance)
    }

    func testTerminalStatesRemoveActiveActionsButPreserveFormatAndScore() {
        let presentation = WorkoutExecutionBlockPresentation.make(
            input: .init(
                kind: .chipper,
                targetRounds: nil,
                clockMode: .countUp,
                prescribedDurationSeconds: nil,
                timeCapSeconds: 300,
                intervalSeconds: nil,
                scoreKind: .duration,
                repetitionScheme: .chipper,
                componentNames: ["Run", "Carry"],
                status: .capped,
                completedRounds: 0,
                additionalRepetitions: 0,
                scoreValue: 275,
                elapsed: 275,
                isClockRunning: false
            )
        )

        XCTAssertEqual(presentation.phase, .capped)
        XCTAssertEqual(presentation.formatTitle, "Chipper")
        XCTAssertEqual(presentation.scoreText, "275")
        XCTAssertEqual(presentation.primaryAction, .none)
        XCTAssertTrue(presentation.movementSequence.isEmpty)
        XCTAssertNil(presentation.capActionTitle)
    }
}

import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SetInputCoordinatorBlockedTests: XCTestCase {
    func testRecordingBlockedAttemptAfterFocusKeepsTheMessage() {
        let coordinator = SetInputCoordinator()
        let focus = makeFocus()

        coordinator.focus = focus
        coordinator.recordBlockedAttempt("Enter repetitions first")

        XCTAssertEqual(coordinator.blockedMessage, "Enter repetitions first")
        XCTAssertEqual(coordinator.blockedAttemptCount, 1)
    }

    func testChangingFocusClearsBlockedMessage() {
        let coordinator = SetInputCoordinator()
        let first = makeFocus(field: .repetitions)
        let second = makeFocus(field: .weight)

        coordinator.focus = first
        coordinator.recordBlockedAttempt("Enter repetitions first")
        coordinator.focus = second

        XCTAssertNil(coordinator.blockedMessage)
    }

    func testRepeatedRefusalsIncrementTheAttemptCount() {
        let coordinator = SetInputCoordinator()
        coordinator.focus = makeFocus()

        coordinator.recordBlockedAttempt("Enter repetitions first")
        coordinator.recordBlockedAttempt("Enter repetitions first")

        XCTAssertEqual(coordinator.blockedMessage, "Enter repetitions first")
        XCTAssertEqual(coordinator.blockedAttemptCount, 2)
    }

    func testSettingFocusToSameValueDoesNotClearMessage() {
        let coordinator = SetInputCoordinator()
        let focus = makeFocus()

        coordinator.focus = focus
        coordinator.recordBlockedAttempt("Enter repetitions first")
        coordinator.focus = focus

        XCTAssertEqual(coordinator.blockedMessage, "Enter repetitions first")
        XCTAssertEqual(coordinator.blockedAttemptCount, 1)
    }

    private func makeFocus(field: SetInputFocus.Field = .repetitions) -> SetInputFocus {
        let exercise = Exercise(name: "Focus fixture", primaryMuscles: [.upperChest])
        let set = ExerciseSet(usedMetric: .metric)
        return SetInputFocus(
            exerciseID: exercise.persistentModelID,
            setID: set.persistentModelID,
            field: field
        )
    }
}

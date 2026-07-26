import XCTest
@testable import GymTracker

final class RepeatingPlanPresentationTests: XCTestCase {
    func testCycleSummaryUsesOneBasedCycleAndWorkoutNumbers() {
        XCTAssertEqual(
            RepeatingPlanPresentation.cycleSummary(
                currentSlotIndex: 1,
                slotCount: 3,
                completedCycleCount: 2
            ),
            "Cycle 3 · Workout 2 of 3"
        )
    }

    func testCycleSummaryReportsInvalidCursorWithoutMisleadingPosition() {
        XCTAssertEqual(
            RepeatingPlanPresentation.cycleSummary(
                currentSlotIndex: 3,
                slotCount: 3,
                completedCycleCount: 0
            ),
            "Rotation needs attention"
        )
    }

    func testRotationSummaryUsesSingularAndPluralForms() {
        XCTAssertEqual(RepeatingPlanPresentation.rotationSummary(slotCount: 1), "1 workout in rotation")
        XCTAssertEqual(RepeatingPlanPresentation.rotationSummary(slotCount: 3), "3 workouts in rotation")
    }

    func testAlternateContinuationCopyMakesCursorBehaviorExplicit() {
        XCTAssertEqual(
            RepeatingPlanPresentation.alternateContinuationTitle(.keepExpected),
            "Keep expected workout next"
        )
        XCTAssertEqual(
            RepeatingPlanPresentation.alternateContinuationTitle(.continueAfterSelected),
            "Continue after selected workout"
        )
        XCTAssertEqual(
            RepeatingPlanPresentation.alternateContinuationDescription(.keepExpected),
            "Your current next workout stays in place after this session."
        )
        XCTAssertEqual(
            RepeatingPlanPresentation.alternateContinuationDescription(.continueAfterSelected),
            "The rotation continues with the workout after this session."
        )
    }

    func testGoalAndExperienceTitlesRemainReadableInTheSourceLocale() {
        XCTAssertEqual(RepeatingPlanPresentation.goalTitle(.generalStrength), "General strength")
        XCTAssertEqual(RepeatingPlanPresentation.goalTitle(.hypertrophy), "Hypertrophy")
        XCTAssertEqual(RepeatingPlanPresentation.goalTitle(.powerlifting), "Powerlifting")
        XCTAssertEqual(RepeatingPlanPresentation.goalTitle(.generalFitness), "General fitness")

        XCTAssertEqual(RepeatingPlanPresentation.experienceTitle(.beginner), "Beginner")
        XCTAssertEqual(RepeatingPlanPresentation.experienceTitle(.intermediate), "Intermediate")
        XCTAssertEqual(RepeatingPlanPresentation.experienceTitle(.advanced), "Advanced")
    }

    func testAlternatePromptNamesTheSelectedWorkoutAndContinuationDecision() {
        XCTAssertEqual(
            RepeatingPlanPresentation.alternateContinuationPrompt(workoutName: "Pull"),
            "Start Pull. Choose whether the expected rotation position stays next or follows this workout."
        )
    }
}

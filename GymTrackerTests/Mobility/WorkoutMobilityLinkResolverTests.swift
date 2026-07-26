import XCTest
@testable import GymTracker

final class WorkoutMobilityLinkResolverTests: XCTestCase {
    func testExpectedAndAlternateCommandsUseTheirSelectedRunSlots() {
        let run = makeRun()

        XCTAssertTrue(
            WorkoutMobilityLinkResolver.slot(in: run, for: .expected) === run.orderedSlots[1]
        )
        XCTAssertTrue(
            WorkoutMobilityLinkResolver.slot(
                in: run,
                for: .alternate(slotIndex: 2, continuationMode: .keepExpected)
            ) === run.orderedSlots[2]
        )
    }

    func testRepeatLastUsesTheLatestCompletedWorkoutOccurrenceRatherThanSkip() {
        let run = makeRun()
        run.occurrences = [
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 0,
                selectedSlotIndex: 0,
                kind: .expected,
                status: .completed,
                cursorBefore: 0,
                cursorAfter: 1,
                createdAt: Date(timeIntervalSince1970: 1)
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 1,
                selectedSlotIndex: 1,
                kind: .skip,
                status: .completed,
                cursorBefore: 1,
                cursorAfter: 2,
                createdAt: Date(timeIntervalSince1970: 2)
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 2,
                selectedSlotIndex: 2,
                kind: .alternate,
                status: .completed,
                cursorBefore: 1,
                cursorAfter: 0,
                createdAt: Date(timeIntervalSince1970: 3)
            )
        ]

        XCTAssertTrue(
            WorkoutMobilityLinkResolver.slot(in: run, for: .repeatLast) === run.orderedSlots[2]
        )
    }

    private func makeRun() -> RepeatingPlanRun {
        let templates = (0..<3).map { index in
            WorkoutTemplate(name: "Workout \(index + 1)", exercises: [])
        }
        let slots = templates.enumerated().map { index, template in
            RepeatingPlanRunSlot(
                sourceSlotID: UUID(),
                orderIndex: index,
                templateIDSnapshot: template.id,
                templateNameSnapshot: template.name,
                workoutTemplate: template
            )
        }
        return RepeatingPlanRun(
            sourcePlanID: UUID(),
            sourcePlanName: "Rotation",
            currentSlotIndex: 1,
            slots: slots
        )
    }
}

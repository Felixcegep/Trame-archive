import XCTest
@testable import GymTracker

final class MobilityRoutineDurationEstimateTests: XCTestCase {
    func testDurationEstimateIncludesExecutedSidesWithoutUnimplementedCyclesOrRest() {
        let durationDefinition = MobilityDefinition(
            name: "Couch stretch",
            trackingType: .duration,
            defaultDurationSeconds: 20
        )
        let routine = MobilityRoutine(name: "Preparation")
        let item = MobilityRoutineItem(
            definition: durationDefinition,
            orderIndex: 0,
            side: .bilateral,
            restSeconds: 10
        )
        item.cycleCount = 2
        routine.items = [item]

        let estimate = MobilityRoutineDurationEstimate.estimate(for: routine)

        XCTAssertEqual(estimate.knownDurationSeconds, 40)
        XCTAssertEqual(estimate.completeness, .complete)
    }

    func testMixedDurationAndRepetitionRoutineProducesPartialEstimate() {
        let durationDefinition = MobilityDefinition(
            name: "Hold",
            trackingType: .duration,
            defaultDurationSeconds: 30
        )
        let repetitionDefinition = MobilityDefinition(
            name: "Controlled rotations",
            trackingType: .repetitions,
            defaultDurationSeconds: nil,
            defaultRepetitions: 8
        )
        let routine = MobilityRoutine(name: "Mixed")
        routine.items = [
            MobilityRoutineItem(
                definition: durationDefinition,
                orderIndex: 0,
                targetDurationSeconds: 45,
                side: .left,
                restSeconds: 15
            ),
            MobilityRoutineItem(
                definition: repetitionDefinition,
                orderIndex: 1,
                targetRepetitions: 10,
                side: .alternating
            )
        ]

        let estimate = MobilityRoutineDurationEstimate.estimate(for: routine)

        XCTAssertEqual(estimate.knownDurationSeconds, 45)
        XCTAssertEqual(estimate.completeness, .partial)
    }

    func testRepetitionOnlyRoutineHasUnknownDurationWithoutInventingRepTiming() {
        let definition = MobilityDefinition(
            name: "Hip rotations",
            trackingType: .repetitions,
            defaultDurationSeconds: nil,
            defaultRepetitions: 8
        )
        let routine = MobilityRoutine(name: "Repetitions")
        routine.items = [
            MobilityRoutineItem(
                definition: definition,
                orderIndex: 0,
                targetRepetitions: 12,
                side: .alternating
            )
        ]

        let estimate = MobilityRoutineDurationEstimate.estimate(for: routine)

        XCTAssertEqual(estimate.knownDurationSeconds, 0)
        XCTAssertEqual(estimate.completeness, .unknown)
    }

    func testEmptyRoutineHasACompleteZeroDurationEstimate() {
        let estimate = MobilityRoutineDurationEstimate.estimate(
            for: MobilityRoutine(name: "Empty")
        )

        XCTAssertEqual(estimate.knownDurationSeconds, 0)
        XCTAssertEqual(estimate.completeness, .complete)
    }
}

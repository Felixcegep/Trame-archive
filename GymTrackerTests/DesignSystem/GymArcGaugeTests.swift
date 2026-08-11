import XCTest
@testable import GymTracker

final class GymArcGaugeTests: XCTestCase {
    func testHoldProgressClampsAndMapsToTheArc() {
        XCTAssertEqual(GymArcGauge.Layout(holdProgress: -1).holdProgress, 0)
        XCTAssertEqual(GymArcGauge.Layout(holdProgress: 2).holdProgress, 1)
        XCTAssertNil(GymArcGauge.Layout(holdProgress: nil).holdProgress)
        XCTAssertEqual(
            GymArcGauge.Layout(holdProgress: 0.5).progressTrimEnd,
            GymArcGauge.Layout.arcStartFraction + (0.5 * GymArcGauge.Layout.arcSpanFraction)
        )
    }

    func testAxisLabelsDistinguishGravityAndRelativeYaw() {
        XCTAssertNotEqual(GymArcGauge.Axis.gravityPitch.title, GymArcGauge.Axis.relativeYaw.title)
        XCTAssertTrue(GymArcGauge.Axis.gravityPitch.interpretation.contains("gravity"))
        XCTAssertTrue(GymArcGauge.Axis.gravityRoll.interpretation.contains("gravity"))
        XCTAssertTrue(GymArcGauge.Axis.relativeYaw.interpretation.contains("relative"))
    }

    func testMeasuringAccessibilitySummaryDoesNotIncludeLiveValues() {
        let gauge = GymArcGauge(
            axis: .gravityPitch,
            state: .measuring,
            degreesText: "12.4°",
            holdProgress: 0.73
        )

        XCTAssertTrue(gauge.accessibilitySummary.contains("Gravity pitch"))
        XCTAssertTrue(gauge.accessibilitySummary.contains("measuring"))
        XCTAssertFalse(gauge.accessibilitySummary.contains("12.4°"))
        XCTAssertFalse(gauge.accessibilitySummary.contains("73%"))
    }

    func testStableAndCompletedSummariesExposeRawEvidenceConcisely() {
        let stable = GymArcGauge(axis: .gravityRoll, state: .stable, degreesText: "−4.0°", holdProgress: 0.8)
        let completed = GymArcGauge(axis: .relativeYaw, state: .completed, degreesText: "2.0°", holdProgress: 1)

        XCTAssertTrue(stable.accessibilitySummary.contains("−4.0°"))
        XCTAssertTrue(stable.accessibilitySummary.contains("Hold 80%"))
        XCTAssertTrue(completed.accessibilitySummary.contains("2.0°"))
        XCTAssertTrue(completed.accessibilitySummary.contains("Hold 100%"))
    }

    func testRejectedAndUnavailableStatesCarryDirectText() {
        let rejected = GymArcGauge(axis: .gravityPitch, state: .rejected(reason: "Movement detected"))
        let unavailable = GymArcGauge(axis: .gravityRoll, state: .unavailable(reason: "Sensor denied"))

        XCTAssertTrue(rejected.accessibilitySummary.contains("rejected"))
        XCTAssertTrue(rejected.accessibilitySummary.contains("Movement detected"))
        XCTAssertTrue(unavailable.accessibilitySummary.contains("unavailable"))
        XCTAssertTrue(unavailable.accessibilitySummary.contains("Sensor denied"))
    }
}

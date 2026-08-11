import XCTest
@testable import GymTracker

final class GymBandMarkerTests: XCTestCase {
    func testTwoSidedBandClampsToTrackAndKeepsInterval() {
        let band = GymBandMarker.Band(lowerFraction: -0.2, upperFraction: 1.4, label: "Reference")
        let layout = GymBandMarker.Layout(markerFraction: 1.2, band: band)

        XCTAssertEqual(layout.markerFraction, 1)
        XCTAssertEqual(layout.interval, 0...1)
    }

    func testEndpointMarkerCentersStayInsideTrackByHalfMarkerWidth() {
        let markerSize = Spacing.l
        let trackWidth: CGFloat = 120
        let leftCenter = GymBandMarker.Layout(markerFraction: 0, band: nil).markerCenter(
            trackWidth: trackWidth,
            markerSize: markerSize
        )
        let rightCenter = GymBandMarker.Layout(markerFraction: 1, band: nil).markerCenter(
            trackWidth: trackWidth,
            markerSize: markerSize
        )

        XCTAssertEqual(leftCenter, markerSize / 2)
        XCTAssertEqual(rightCenter, trackWidth - markerSize / 2)
    }

    func testUnpositionedStatesDoNotProduceAVisualCoordinate() {
        let missing = GymBandMarker(
            measurement: nil,
            state: .missing(reason: "No observation"),
            markerFraction: 0.5
        )
        let incompatible = GymBandMarker(
            measurement: "12.5 cm",
            state: .incompatible(reason: "Different protocol"),
            markerFraction: 0.5
        )

        XCTAssertNil(missing.positionedMarkerCenter(trackWidth: 120, markerSize: Spacing.l))
        XCTAssertNil(incompatible.positionedMarkerCenter(trackWidth: 120, markerSize: Spacing.l))
        XCTAssertNil(GymBandMarker.State.missing(reason: "No observation").position)
        XCTAssertNil(GymBandMarker.State.incompatible(reason: "Different protocol").position)
    }

    func testOneSidedBandsAnchorToTheOpenTrackEdge() {
        let lowerOpen = GymBandMarker.Band(upperFraction: 0.6, label: "Up to 15 cm")
        let upperOpen = GymBandMarker.Band(lowerFraction: 0.4, label: "At least 10 cm")

        XCTAssertEqual(lowerOpen.normalizedRange, 0...0.6)
        XCTAssertEqual(upperOpen.normalizedRange, 0.4...1)
    }

    func testInvalidInvertedOrEmptyBandsDoNotProduceShadedIntervals() {
        XCTAssertNil(GymBandMarker.Band(lowerFraction: 0.8, upperFraction: 0.2, label: "Invalid").normalizedRange)
        XCTAssertNil(GymBandMarker.Band(label: "Missing bounds").normalizedRange)
    }

    func testReadingOrderPlacesRawMeasurementBeforeInterpretation() {
        let marker = GymBandMarker(
            measurement: "12.5 cm",
            band: .init(lowerFraction: 0.25, upperFraction: 0.75, label: "Reference band: 10–15 cm"),
            state: .within,
            markerFraction: 0.5
        )

        XCTAssertEqual(marker.readingOrder.first, "Measured: 12.5 cm")
        XCTAssertEqual(marker.readingOrder.dropFirst(), ["Reference band: 10–15 cm", "Within reference band"])
        XCTAssertTrue(marker.accessibilitySummary.hasPrefix("Measured: 12.5 cm."))
    }

    func testMissingAndIncompatibleStatesRemainTextualAndNeutral() {
        let missing = GymBandMarker(measurement: nil, state: .missing(reason: "No observation"))
        let incompatible = GymBandMarker(
            measurement: "12.5 cm",
            state: .incompatible(reason: "Different protocol version")
        )

        XCTAssertTrue(missing.accessibilitySummary.contains("Measurement unavailable"))
        XCTAssertTrue(missing.accessibilitySummary.contains("No observation"))
        XCTAssertTrue(incompatible.accessibilitySummary.contains("12.5 cm"))
        XCTAssertTrue(incompatible.accessibilitySummary.contains("Reference comparison unavailable"))
        XCTAssertTrue(incompatible.accessibilitySummary.contains("Different protocol version"))
    }
}

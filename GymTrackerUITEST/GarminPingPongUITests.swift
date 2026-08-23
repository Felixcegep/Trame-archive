import XCTest

final class GarminPingPongUITests: GymTrackerUITestCase {
    func testGarminDiagnosticEmptyStateAndCapture() throws {
        let app = launchFreshApp()
        selectTab(.settings, in: app)
        tapButton("settings-advanced", in: app)
        tapButton("settings-garmin-test", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["garmin-ping-pong-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["garmin-select-device"].exists)
        XCTAssertFalse(app.buttons["garmin-send-ping"].isEnabled)
        XCTAssertTrue(app.staticTexts["Select a Garmin to begin the local BLE test."].exists)

        let screenshotURL = URL(fileURLWithPath: "/Users/felixlachapelle/Desktop/GymTracker/Screenshots/settings/04h_Garmin_Ping_Pong.png")
        try FileManager.default.createDirectory(
            at: screenshotURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: screenshotURL)
    }
}

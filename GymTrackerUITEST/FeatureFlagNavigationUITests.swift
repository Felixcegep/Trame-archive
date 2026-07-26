import XCTest

/// Feature-flag gating is centralized at the root navigation boundary
/// (RootView, FolderView) rather than assembled independently in several
/// views. These tests exercise the deterministic `-feature-flags` launch
/// override to prove disabled destinations are actually hidden, not just
/// unlinked in source.
final class FeatureFlagNavigationUITests: GymTrackerUITestCase {
    func testNutritionTabHidesWhenNutritionFlagDisabled() {
        let app = launchFreshApp(additionalArguments: [
            "-feature-flags", "today,mobility,bodyWeight,dailyCheckIn,programBuilder,advancedExecution,betaFeedback"
        ])
        XCTAssertTrue(app.buttons["tab-today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tab-train"].exists)
        XCTAssertTrue(app.buttons["tab-progress"].exists)
        XCTAssertFalse(app.buttons["tab-nutrition"].exists)
    }

    func testNutritionTabShowsWhenNutritionFlagEnabled() {
        let app = launchFreshApp(additionalArguments: [
            "-feature-flags", "today,mobility,nutrition,bodyWeight,dailyCheckIn,programBuilder,advancedExecution,betaFeedback"
        ])
        XCTAssertTrue(app.buttons["tab-nutrition"].waitForExistence(timeout: 10))
    }

    /// Ready-made plans are a scope inside Plans rather than their own Train
    /// row, so `programBuilder` now gates that segment.
    func testMobilityAndProgramCatalogLinksHideWhenTheirFlagsAreDisabled() {
        let app = launchFreshApp(additionalArguments: [
            "-feature-flags", "today,nutrition,bodyWeight,dailyCheckIn,advancedExecution,betaFeedback"
        ])
        XCTAssertTrue(app.buttons["tab-train"].waitForExistence(timeout: 10))
        app.buttons["tab-train"].tap()
        XCTAssertFalse(app.buttons["train-mobility-library"].waitForExistence(timeout: 5))
        // A neighboring, still-enabled entry point confirms the screen
        // rendered rather than failing to load.
        XCTAssertTrue(app.buttons["exercises-browser"].exists)

        tapButton("plans-browser", in: app)
        XCTAssertTrue(app.buttons["Mine"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Ready-made"].exists)
    }

    func testMobilityAndProgramCatalogLinksShowWhenEnabled() {
        let app = launchFreshApp(additionalArguments: [
            "-feature-flags", "today,mobility,nutrition,bodyWeight,dailyCheckIn,programBuilder,advancedExecution,betaFeedback"
        ])
        XCTAssertTrue(app.buttons["tab-train"].waitForExistence(timeout: 10))
        app.buttons["tab-train"].tap()
        XCTAssertTrue(app.buttons["train-mobility-library"].waitForExistence(timeout: 5))

        tapButton("plans-browser", in: app)
        XCTAssertTrue(app.buttons["Ready-made"].waitForExistence(timeout: 5))
    }
}

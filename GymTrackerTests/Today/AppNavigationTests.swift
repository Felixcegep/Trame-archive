import XCTest
@testable import GymTracker

final class AppNavigationTests: XCTestCase {
    func testFourPrimaryTabsHaveStableIdentifiers() {
        XCTAssertEqual(AppTab.allCases, [.today, .train, .nutrition, .progress])
        XCTAssertEqual(AppTab.today.accessibilityIdentifier, "tab-today")
        XCTAssertEqual(AppTab.train.accessibilityIdentifier, "tab-train")
        XCTAssertEqual(AppTab.nutrition.accessibilityIdentifier, "tab-nutrition")
        XCTAssertEqual(AppTab.progress.accessibilityIdentifier, "tab-progress")
    }

    func testActiveExecutionFlowsAreNotTabs() {
        XCTAssertFalse(AppTab.allCases.map(\.title).contains("Active Workout"))
        XCTAssertFalse(AppTab.allCases.map(\.title).contains("Mobility"))
    }
}

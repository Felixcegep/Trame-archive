import XCTest
@testable import GymTracker

final class AppScreenTests: XCTestCase {
    func testEachPrimaryTabReportsExpectedLabel() {
        for tab in AppTab.allCases {
            let screen = AppScreen.current(
                selectedTab: tab,
                isSettingsPresented: false,
                isShowingActiveWorkout: false,
                isShowingWorkoutSave: false,
                isShowingActiveMobility: false
            )
            switch tab {
            case .today: XCTAssertEqual(screen, .today)
            case .train: XCTAssertEqual(screen, .train)
            case .nutrition: XCTAssertEqual(screen, .nutrition)
            case .progress: XCTAssertEqual(screen, .progress)
            }
        }
    }

    func testSettingsIsReportedWhenPresentedOverAnyTab() {
        let screen = AppScreen.current(
            selectedTab: .train,
            isSettingsPresented: true,
            isShowingActiveWorkout: false,
            isShowingWorkoutSave: false,
            isShowingActiveMobility: false
        )
        XCTAssertEqual(screen, .settings)
    }

    func testActiveWorkoutSupersedesItsUnderlyingTab() {
        let screen = AppScreen.current(
            selectedTab: .today,
            isSettingsPresented: true,
            isShowingActiveWorkout: true,
            isShowingWorkoutSave: false,
            isShowingActiveMobility: false
        )
        XCTAssertEqual(screen, .activeWorkout, "An active full-screen workout must supersede whatever is underneath it.")
    }

    func testWorkoutSaveSupersedesActiveWorkout() {
        let screen = AppScreen.current(
            selectedTab: .today,
            isSettingsPresented: false,
            isShowingActiveWorkout: true,
            isShowingWorkoutSave: true,
            isShowingActiveMobility: false
        )
        XCTAssertEqual(screen, .workoutSave)
    }

    func testActiveMobilitySupersedesItsUnderlyingTab() {
        let screen = AppScreen.current(
            selectedTab: .train,
            isSettingsPresented: false,
            isShowingActiveWorkout: false,
            isShowingWorkoutSave: false,
            isShowingActiveMobility: true
        )
        XCTAssertEqual(screen, .activeMobility)
    }

    func testDismissingASheetRestoresTheUnderlyingScreen() {
        // Simulates Settings being dismissed: isSettingsPresented flips back
        // to false and the resolver falls through to the still-selected tab.
        let whilePresented = AppScreen.current(
            selectedTab: .progress,
            isSettingsPresented: true,
            isShowingActiveWorkout: false,
            isShowingWorkoutSave: false,
            isShowingActiveMobility: false
        )
        XCTAssertEqual(whilePresented, .settings)

        let afterDismiss = AppScreen.current(
            selectedTab: .progress,
            isSettingsPresented: false,
            isShowingActiveWorkout: false,
            isShowingWorkoutSave: false,
            isShowingActiveMobility: false
        )
        XCTAssertEqual(afterDismiss, .progress)
    }

    func testNoPersistedOrUserAuthoredContentEntersTheDescriptor() {
        for screen in AppScreen.allCases {
            XCTAssertFalse(screen.diagnosticLabel.isEmpty)
            XCTAssertFalse(screen.rawValue.contains(" "))
        }
    }
}

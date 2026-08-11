import Foundation
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

final class CoachExchangePresentationTests: XCTestCase {
    func testReportStatesKeepLoadingEmptyInvalidAndReadyDistinct() {
        let preview = TrainingReportArtifactPreview(
            includedSensitiveCategories: [.workoutPerformance],
            selectedWorkoutCount: 1,
            selectedPlanCount: 0,
            sectionCount: 2,
            rowCount: 3,
            requiresExplicitShareConfirmation: true,
            shareConfirmation: .notConfirmed
        )

        XCTAssertNotEqual(CoachExchangeReportUIState.loading, .empty)
        XCTAssertNotEqual(CoachExchangeReportUIState.empty, .invalidDateRange)
        XCTAssertEqual(CoachExchangeReportUIState.ready(preview), .ready(preview))
    }

    func testImportStateDoesNotRepresentPreviewAsApplied() {
        let state: CoachExchangeImportUIState = .idle
        XCTAssertEqual(state, .idle)
        XCTAssertFalse(String(describing: state).localizedCaseInsensitiveContains("applied"))
        XCTAssertEqual(CoachExchangeImportUIState.failed("bad file"), .failed("bad file"))
    }
}

#endif

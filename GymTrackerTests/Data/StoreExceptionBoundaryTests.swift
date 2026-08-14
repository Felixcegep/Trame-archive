import Foundation
import XCTest
@testable import GymTracker

final class StoreExceptionBoundaryTests: XCTestCase {
    func testOperationReturnsNormallyWithoutException() {
        var didRun = false
        var exception: NSException?

        let returned = GTExceptionBoundary.performOperation({
            didRun = true
        }, caughtException: &exception)

        XCTAssertTrue(returned)
        XCTAssertTrue(didRun)
        XCTAssertNil(exception)
    }

    func testObjectiveCExceptionIsReturnedInsteadOfTerminatingProcess() throws {
        let expectedName = NSExceptionName("GymTrackerStoreOpenFailure")
        var exception: NSException?

        let returned = GTExceptionBoundary.performOperation({
            NSException(
                name: expectedName,
                reason: "Malformed persistent-store metadata",
                userInfo: nil
            ).raise()
        }, caughtException: &exception)

        XCTAssertFalse(returned)
        let captured = try XCTUnwrap(exception)
        XCTAssertEqual(captured.name, expectedName)
        XCTAssertEqual(captured.reason, "Malformed persistent-store metadata")
    }
}

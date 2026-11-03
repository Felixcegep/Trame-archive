import XCTest
@testable import GymTracker

final class GoogleDriveOAuthConfigTests: XCTestCase {
    func testReversedClientIDMapsGoogleIosClient() {
        XCTAssertEqual(
            GoogleDriveOAuthConfig.reversedClientID(from: "123-abc.apps.googleusercontent.com"),
            "com.googleusercontent.apps.123-abc"
        )
        XCTAssertEqual(
            GoogleDriveOAuthConfig.reversedClientID(from: "123-abc.apps.googleusercontent.com") + ":/oauth2redirect",
            "com.googleusercontent.apps.123-abc:/oauth2redirect"
        )
    }

    func testIsConfiguredFalseForEmptyAndReplace() {
        XCTAssertFalse(GoogleDriveOAuthConfig.isConfiguredClientID(""))
        XCTAssertFalse(GoogleDriveOAuthConfig.isConfiguredClientID("   "))
        XCTAssertFalse(GoogleDriveOAuthConfig.isConfiguredClientID("REPLACE.apps.googleusercontent.com"))
        XCTAssertFalse(
            GoogleDriveOAuthConfig.isConfiguredClientID("123-REPLACE-abc.apps.googleusercontent.com")
        )
        XCTAssertFalse(GoogleDriveOAuthConfig.isConfiguredClientID("123-abc"))
        XCTAssertTrue(
            GoogleDriveOAuthConfig.isConfiguredClientID("123-abc.apps.googleusercontent.com")
        )
    }
}

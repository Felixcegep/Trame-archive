import XCTest
@testable import GymTracker

final class GoogleDriveTokenStoreTests: XCTestCase {
    private var store: GoogleDriveTokenStore!

    override func setUp() {
        super.setUp()
        store = GoogleDriveTokenStore(
            service: "felix.GymTracker.googleDriveOAuth.tests.\(UUID().uuidString)",
            account: "credentials"
        )
        store.delete()
    }

    override func tearDown() {
        store.delete()
        store = nil
        super.tearDown()
    }

    func testSaveLoadAndDeleteRoundTrip() throws {
        XCTAssertNil(store.load())
        let credentials = GoogleDriveCredentials(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            tokenType: "Bearer",
            accountEmail: "user@example.com"
        )
        try store.save(credentials)
        let loaded = store.load()
        XCTAssertEqual(loaded, credentials)
        store.delete()
        XCTAssertNil(store.load())
    }
}

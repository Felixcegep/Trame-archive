import XCTest
import SwiftData
@testable import GymTracker

final class GymTrackerPersistenceConfigurationTests: XCTestCase {
    func testModelConfigurationStoreURLContinuity() {
        let actualConfig = GymTrackerPersistenceConfiguration().makeModelConfiguration()
        let defaultBareConfig = ModelConfiguration()
        let preRevert114aff1bConfig = ModelConfiguration(
            "GymTrackerCloudUserData",
            schema: GymTrackerPersistenceConfiguration.schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        print("[STORE_URL_VERIFICATION] actualConfig URL: \(actualConfig.url.path)")
        print("[STORE_URL_VERIFICATION] defaultBareConfig URL: \(defaultBareConfig.url.path)")
        print("[STORE_URL_VERIFICATION] preRevert114aff1bConfig URL: \(preRevert114aff1bConfig.url.path)")

        XCTAssertEqual(
            actualConfig.url.path,
            defaultBareConfig.url.path,
            "GymTrackerPersistenceConfiguration store URL MUST equal default bare ModelConfiguration URL!"
        )

        XCTAssertNotEqual(
            actualConfig.url.path,
            preRevert114aff1bConfig.url.path,
            "Commit 114aff1b config (named config + groupContainer .none) resolves to a different path! The revert in 92d7c354 was required to prevent data loss."
        )
    }
}

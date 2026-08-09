import Foundation
import XCTest
@testable import GymTracker

final class AppLaunchArgumentsTests: XCTestCase {
    func testUsesProcessArgumentsWhenNoMirroredPayloadExists() {
        let arguments = ["Trame", "-ui-testing", "-reset-data"]

        XCTAssertEqual(
            AppLaunchArguments.resolve(arguments: arguments, environment: [:]),
            arguments
        )
    }

    func testMirroredPayloadIsAuthoritativeWhenLaunchServiceDropsArguments() throws {
        let mirroredArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-test-fixture",
            "active-draft"
        ]
        let data = try JSONEncoder().encode(mirroredArguments)
        let payload = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(
            AppLaunchArguments.resolve(
                arguments: ["Trame"],
                environment: [AppLaunchArguments.uiTestPayloadEnvironmentKey: payload]
            ),
            mirroredArguments
        )
    }

    func testFreshMirroredPayloadReplacesPriorFixtureAndResetOptions() throws {
        let preserveDataArguments = ["-ui-testing"]
        let data = try JSONEncoder().encode(preserveDataArguments)
        let payload = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(
            AppLaunchArguments.resolve(
                arguments: ["Trame", "-reset-data", "-ui-test-fixture", "active-draft"],
                environment: [AppLaunchArguments.uiTestPayloadEnvironmentKey: payload]
            ),
            preserveDataArguments
        )
    }

    func testMalformedMirroredPayloadFallsBackToProcessArguments() {
        let arguments = ["Trame", "-ui-testing"]

        XCTAssertEqual(
            AppLaunchArguments.resolve(
                arguments: arguments,
                environment: [AppLaunchArguments.uiTestPayloadEnvironmentKey: "not-json"]
            ),
            arguments
        )
    }
}

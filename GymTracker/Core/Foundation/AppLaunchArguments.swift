import Foundation

/// One source for process launch options, including a deterministic UI-test
/// transport. XCTest normally forwards `XCUIApplication.launchArguments` to
/// the app process, but Simulator launch services can occasionally drop them.
/// UI tests mirror the same array through this environment payload, so every
/// test-only route observes one coherent set of options instead of inventing a
/// second flag for each fixture or screenshot state.
enum AppLaunchArguments {
    nonisolated static let uiTestPayloadEnvironmentKey = "GYMTRACKER_UI_TEST_ARGUMENTS_JSON"

    nonisolated static var current: [String] {
        resolve(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    nonisolated static func resolve(
        arguments: [String],
        environment: [String: String]
    ) -> [String] {
        guard
            let payload = environment[uiTestPayloadEnvironmentKey],
            let data = payload.data(using: .utf8),
            let mirroredArguments = try? JSONDecoder().decode([String].self, from: data)
        else {
            return arguments
        }

        // The explicit environment payload is authoritative when present. It
        // is regenerated before every launch, including preserve-data
        // relaunches, so stale reset or fixture options cannot leak forward.
        return mirroredArguments
    }
}

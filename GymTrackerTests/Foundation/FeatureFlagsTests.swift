import XCTest
@testable import GymTracker

final class FeatureFlagsTests: XCTestCase {
    func testInternalDevelopmentChannelEnablesEveryFlag() {
        let configuration = DefaultFeatureFlagConfiguration(buildChannel: .internalDevelopment)
        for flag in FeatureFlag.allCases {
            XCTAssertTrue(configuration.isEnabled(flag), "\(flag) should be enabled for internal development.")
        }
        XCTAssertEqual(Set(configuration.enabledFlags), Set(FeatureFlag.allCases))
    }

    func testReleaseChannelEnablesEveryFlag() {
        let configuration = DefaultFeatureFlagConfiguration(buildChannel: .release)
        XCTAssertEqual(Set(configuration.enabledFlags), Set(FeatureFlag.allCases))
    }

    func testBetaChannelHidesEverySecondaryDomain() {
        let configuration = DefaultFeatureFlagConfiguration(buildChannel: .beta)
        XCTAssertTrue(configuration.isEnabled(.today))
        XCTAssertTrue(configuration.isEnabled(.betaFeedback))
        for hidden: FeatureFlag in [.mobility, .nutrition, .bodyWeight, .dailyCheckIn, .programBuilder, .advancedExecution] {
            XCTAssertFalse(configuration.isEnabled(hidden), "\(hidden) must stay hidden in the Beta 1 matrix.")
        }
    }

    func testCaffeineQuickLoggingRequiresNutrition() {
        let withNutrition = DefaultFeatureFlagConfiguration(buildChannel: .internalDevelopment)
        XCTAssertTrue(withNutrition.isCaffeineQuickLoggingAvailable)

        let withoutNutrition = DefaultFeatureFlagConfiguration(
            buildChannel: .internalDevelopment,
            overrides: Set(FeatureFlag.allCases).subtracting([.nutrition])
        )
        XCTAssertFalse(withoutNutrition.isEnabled(.nutrition))
        XCTAssertFalse(
            withoutNutrition.isCaffeineQuickLoggingAvailable,
            "Caffeine quick logging has no flag of its own and must fail closed without Nutrition."
        )
    }

    func testDeterministicLaunchArgumentOverrideWinsOverDefaultMatrix() {
        let configuration = FeatureFlags.makeCurrent(
            arguments: ["AppName", "-feature-flags", "today,mobility"],
            environment: [:]
        )
        XCTAssertEqual(Set(configuration.enabledFlags), [.today, .mobility])
        XCTAssertFalse(configuration.isEnabled(.nutrition))
        XCTAssertFalse(configuration.isEnabled(.programBuilder))
    }

    func testDeterministicEnvironmentOverrideWinsOverDefaultMatrix() {
        let configuration = FeatureFlags.makeCurrent(
            arguments: ["AppName"],
            environment: ["GYMTRACKER_FEATURE_FLAGS": "today,betaFeedback"]
        )
        XCTAssertEqual(Set(configuration.enabledFlags), [.today, .betaFeedback])
    }

    func testLaunchArgumentOverrideTakesPrecedenceOverEnvironment() {
        let configuration = FeatureFlags.makeCurrent(
            arguments: ["AppName", "-feature-flags", "today"],
            environment: ["GYMTRACKER_FEATURE_FLAGS": "today,mobility,nutrition"]
        )
        XCTAssertEqual(Set(configuration.enabledFlags), [.today])
    }

    func testMalformedOverrideValueYieldsNoEnabledFlags() {
        let configuration = FeatureFlags.makeCurrent(
            arguments: ["AppName", "-feature-flags", "not-a-real-flag, also-bogus"],
            environment: [:]
        )
        XCTAssertTrue(configuration.enabledFlags.isEmpty)
    }

    func testNoOverridePresentFallsBackToDefaultMatrix() {
        let configuration = FeatureFlags.makeCurrent(arguments: ["AppName"], environment: [:])
        XCTAssertFalse(configuration.enabledFlags.isEmpty)
    }
}

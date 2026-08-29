import XCTest
@testable import GymTracker

final class FeatureFlagsTests: XCTestCase {
    func testInternalDevelopmentChannelEnablesEveryFlag() {
        let configuration = DefaultFeatureFlagConfiguration(buildChannel: .internalDevelopment)
        XCTAssertEqual(Set(configuration.enabledFlags), Set(FeatureFlag.allCases))
        XCTAssertTrue(configuration.isEnabled(.nutrition))
        XCTAssertTrue(configuration.isEnabled(.recipeGeneration))
    }

    func testReleaseChannelMatchesGeneralAvailabilityMatrix() {
        let configuration = DefaultFeatureFlagConfiguration(buildChannel: .release)
        XCTAssertEqual(Set(configuration.enabledFlags), DefaultFeatureFlagConfiguration.generalAvailability)
    }

    func testUndeclaredDistributedBuildResolvesToBeta() {
        XCTAssertEqual(
            FeatureFlagBuildChannel.resolve(infoDictionary: [:], isDebugBuild: false),
            .beta
        )
    }

    func testDeclaredChannelWins() {
        XCTAssertEqual(
            FeatureFlagBuildChannel.resolve(
                infoDictionary: [FeatureFlagBuildChannel.infoDictionaryKey: "release"],
                isDebugBuild: false
            ),
            .release
        )
        XCTAssertEqual(
            FeatureFlagBuildChannel.resolve(
                infoDictionary: [FeatureFlagBuildChannel.infoDictionaryKey: "beta"],
                isDebugBuild: true
            ),
            .beta
        )
        XCTAssertEqual(
            FeatureFlagBuildChannel.resolve(
                infoDictionary: [FeatureFlagBuildChannel.infoDictionaryKey: "unknown"],
                isDebugBuild: false
            ),
            .beta
        )
    }

    func testDebugBuildResolvesToInternalDevelopment() {
        XCTAssertEqual(
            FeatureFlagBuildChannel.resolve(infoDictionary: nil, isDebugBuild: true),
            .internalDevelopment
        )
    }

    func testDependentFlagFailsClosed() {
        let assessmentOnly = DefaultFeatureFlagConfiguration(
            buildChannel: .release,
            overrides: [.mobilityAssessment]
        )
        XCTAssertFalse(assessmentOnly.isEnabled(.mobilityAssessment))

        let generationOnly = DefaultFeatureFlagConfiguration(
            buildChannel: .release,
            overrides: [.recipeGeneration]
        )
        XCTAssertFalse(generationOnly.isEnabled(.recipeGeneration))
    }

    func testCurrentWaveExcludesUnfinishedSurfacesOnly() {
        let configuration = DefaultFeatureFlagConfiguration(buildChannel: .beta)
        XCTAssertEqual(
            Set(configuration.enabledFlags),
            Set(FeatureFlag.allCases).subtracting([
                .mobilityAssessment, .mobilityProgram, .recipeGeneration,
                .workoutGeneration, .sportSpecializations
            ])
        )
        XCTAssertFalse(configuration.isEnabled(.mobilityAssessment))
        XCTAssertFalse(configuration.isEnabled(.mobilityProgram))
        XCTAssertFalse(configuration.isEnabled(.recipeGeneration))
        XCTAssertFalse(configuration.isEnabled(.workoutGeneration))
        XCTAssertTrue(configuration.isEnabled(.nutrition))
        XCTAssertFalse(configuration.isEnabled(.sportSpecializations))
    }

    func testCaffeineQuickLoggingRequiresNutrition() {
        let withNutrition = DefaultFeatureFlagConfiguration(
            buildChannel: .internalDevelopment,
            overrides: Set(FeatureFlag.allCases)
        )
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

import XCTest
@testable import GymTracker

@MainActor
final class BetaFeedbackContextTests: XCTestCase {
    private func makeContext(
        infoDictionary: [String: Any] = [
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "42"
        ],
        buildChannel: FeatureFlagBuildChannel = .beta,
        enabledFlags: Set<FeatureFlag> = [.today, .betaFeedback],
        screen: AppScreen = .settings
    ) -> BetaFeedbackContext {
        let flags = DefaultFeatureFlagConfiguration(buildChannel: buildChannel, overrides: enabledFlags)
        return BetaFeedbackContextProvider.makeContext(
            screen: screen,
            infoDictionary: infoDictionary,
            featureFlags: flags,
            deviceModel: "iPhone15,2",
            osVersion: "iOS 18.0"
        )
    }

    func testContextCreationIsDeterministicUnderInjectedValues() {
        let context = makeContext()
        XCTAssertEqual(context.appVersion, "1.2")
        XCTAssertEqual(context.buildNumber, "42")
        XCTAssertEqual(context.schemaVersion, GymTrackerAppSchema.diagnosticVersion)
        XCTAssertEqual(context.backupFormatVersion, BackupDTO.currentVersion)
        XCTAssertEqual(context.buildChannel, .beta)
        XCTAssertEqual(context.deviceModel, "iPhone15,2")
        XCTAssertEqual(context.osVersion, "iOS 18.0")
        XCTAssertEqual(context.screen, .settings)
    }

    func testMissingBundleValuesDisplayUnknown() {
        let context = makeContext(infoDictionary: [:])
        XCTAssertEqual(context.appVersion, BetaFeedbackContext.unknownValue)
        XCTAssertEqual(context.buildNumber, BetaFeedbackContext.unknownValue)
    }

    func testEnabledFlagsAreSortedUsingFeatureFlagAllCases() {
        let context = makeContext(enabledFlags: [.betaFeedback, .today])
        let expectedOrder = FeatureFlag.allCases.filter { [.today, .betaFeedback].contains($0) }
        XCTAssertEqual(context.enabledFlags, expectedOrder)
    }

    func testDiagnosticTextContainsEveryLineExactlyOnce() {
        let context = makeContext()
        for line in context.diagnosticLines {
            XCTAssertTrue(context.diagnosticText.contains("\(line.label): \(line.value)"))
        }
        XCTAssertEqual(context.diagnosticText.components(separatedBy: "\n").count, context.diagnosticLines.count)
    }

    func testDiagnosticTextNeverContainsSensitiveDomainKeywords() {
        let context = makeContext()
        let forbidden = ["workout", "exercise", "meal", "food", "journal", "check-in", "weight", "health"]
        let haystack = context.diagnosticText.lowercased()
        for word in forbidden {
            XCTAssertFalse(haystack.contains(word), "Diagnostic text must never mention '\(word)'.")
        }
    }
}

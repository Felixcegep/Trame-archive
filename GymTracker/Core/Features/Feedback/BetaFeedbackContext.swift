import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A deterministic snapshot of version and environment metadata attached to
/// an in-app beta feedback report. This intentionally excludes every
/// workout, meal, health, or journal value — only diagnostic identity about
/// the build and device is captured here.
struct BetaFeedbackContext: Sendable, Equatable {
    static let unknownValue = "Unknown"

    let appVersion: String
    let buildNumber: String
    let schemaVersion: String
    let backupFormatVersion: Int
    let buildChannel: FeatureFlagBuildChannel
    let enabledFlags: [FeatureFlag]
    let deviceModel: String
    let osVersion: String
    let screen: AppScreen
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder.Snapshot?

    init(
        appVersion: String,
        buildNumber: String,
        schemaVersion: String,
        backupFormatVersion: Int,
        buildChannel: FeatureFlagBuildChannel,
        enabledFlags: [FeatureFlag],
        deviceModel: String,
        osVersion: String,
        screen: AppScreen,
        activeLoggingMetrics: ActiveLoggingMetricsRecorder.Snapshot? = nil
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.schemaVersion = schemaVersion
        self.backupFormatVersion = backupFormatVersion
        self.buildChannel = buildChannel
        self.enabledFlags = enabledFlags
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.screen = screen
        self.activeLoggingMetrics = activeLoggingMetrics
    }

    /// Ordered label/value pairs for the exact preview shown to the user
    /// before sharing, and for the plain-text payload attached to the share
    /// sheet. Order matters for both surfaces, so it is defined once here.
    var diagnosticLines: [(label: String, value: String)] {
        var lines = [
            (String(localized: "App Version"), appVersion),
            (String(localized: "Build"), buildNumber),
            (String(localized: "Schema Version"), schemaVersion),
            (String(localized: "Backup Format"), "v\(backupFormatVersion)"),
            (String(localized: "Build Channel"), buildChannel.rawValue),
            (String(localized: "Enabled Flags"), enabledFlags.map(\.rawValue).joined(separator: ", ")),
            (String(localized: "Device"), deviceModel),
            (String(localized: "OS Version"), osVersion),
            (String(localized: "Screen"), screen.diagnosticLabel)
        ]
        if let activeLoggingMetrics, activeLoggingMetrics.hasRecordedData {
            lines.append(contentsOf: activeLoggingMetrics.diagnosticLines)
        }
        return lines
    }

    var diagnosticText: String {
        diagnosticLines.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
    }
}

/// Builds `BetaFeedbackContext` values from injectable sources so context
/// creation stays deterministic under test while defaulting to the real
/// bundle, feature-flag configuration, and device in production.
enum BetaFeedbackContextProvider {
    @MainActor
    static func makeContext(
        screen: AppScreen,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:],
        featureFlags: FeatureFlagConfiguration? = nil,
        deviceModel: String? = nil,
        osVersion: String? = nil,
        activeLoggingMetrics: ActiveLoggingMetricsRecorder.Snapshot? = nil
    ) -> BetaFeedbackContext {
        let featureFlags = featureFlags ?? FeatureFlags.current
        let deviceModel = deviceModel ?? BetaFeedbackDevice.currentModel()
        let osVersion = osVersion ?? BetaFeedbackDevice.currentOSVersion()
        return BetaFeedbackContext(
            appVersion: infoDictionary["CFBundleShortVersionString"] as? String ?? BetaFeedbackContext.unknownValue,
            buildNumber: infoDictionary["CFBundleVersion"] as? String ?? BetaFeedbackContext.unknownValue,
            schemaVersion: GymTrackerAppSchema.diagnosticVersion,
            backupFormatVersion: BackupDTO.currentVersion,
            buildChannel: featureFlags.buildChannel,
            enabledFlags: featureFlags.enabledFlags,
            deviceModel: deviceModel,
            osVersion: osVersion,
            screen: screen,
            activeLoggingMetrics: activeLoggingMetrics
        )
    }
}

enum BetaFeedbackDevice {
    static func currentModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? BetaFeedbackContext.unknownValue
    }

    static func currentOSVersion() -> String {
        #if canImport(UIKit)
        return "iOS \(UIDevice.current.systemVersion)"
        #else
        return BetaFeedbackContext.unknownValue
        #endif
    }
}

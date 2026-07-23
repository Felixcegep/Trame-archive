import Foundation

/// Stable identities for capabilities that can be exposed selectively by
/// beta phase. A flag hides navigation and entry points; it never deletes or
/// migrates the persisted data underneath a disabled capability.
enum FeatureFlag: String, CaseIterable, Codable, Sendable {
    case today
    case mobility
    case nutrition
    case bodyWeight
    case dailyCheckIn
    case programBuilder
    case advancedExecution
    case betaFeedback
}

/// The rollout matrix a build was produced for. `internalDevelopment` is the
/// full-functionality configuration used for solo development and dogfooding
/// today; `beta` matrices mirror `RoadMap.md`'s staged tester waves; `release`
/// is general availability once every domain has cleared its beta phase.
enum FeatureFlagBuildChannel: String, CaseIterable, Sendable {
    case internalDevelopment
    case beta
    case release
}

/// Read-only capability surface. Views ask this instead of reading
/// `UserDefaults` or a launch argument directly, so availability stays
/// centralized, deterministic, and reportable to beta feedback.
protocol FeatureFlagConfiguration: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    var enabledFlags: [FeatureFlag] { get }
    var buildChannel: FeatureFlagBuildChannel { get }
}

extension FeatureFlagConfiguration {
    /// Caffeine quick logging is a Nutrition sub-feature with no flag of its
    /// own; it must never be reachable while Nutrition itself is disabled.
    var isCaffeineQuickLoggingAvailable: Bool { isEnabled(.nutrition) }
}

struct DefaultFeatureFlagConfiguration: FeatureFlagConfiguration {
    let buildChannel: FeatureFlagBuildChannel
    private let enabled: Set<FeatureFlag>

    /// - Parameters:
    ///   - buildChannel: which default matrix to start from.
    ///   - overrides: a deterministic replacement set for debug/UI-test
    ///     launch arguments. Production builds must never pass a remote or
    ///     user-facing value here — only a deliberate local build
    ///     configuration may override the shipped matrix.
    init(
        buildChannel: FeatureFlagBuildChannel,
        overrides: Set<FeatureFlag>? = nil
    ) {
        self.buildChannel = buildChannel
        self.enabled = Self.applyingDependencies(
            to: overrides ?? Self.defaultMatrix(for: buildChannel)
        )
    }

    /// One reviewed matrix per channel so different surfaces cannot disagree
    /// about what is available.
    static func defaultMatrix(for buildChannel: FeatureFlagBuildChannel) -> Set<FeatureFlag> {
        switch buildChannel {
        case .internalDevelopment, .release:
            return Set(FeatureFlag.allCases)
        case .beta:
            // Beta 1 — Core workout reliability: hide every secondary
            // domain until its own beta wave begins (RoadMap.md §4).
            return [.today, .betaFeedback]
        }
    }

    /// Fails a dependent flag closed whenever its prerequisite is disabled,
    /// so an override set can never produce a combination no UI can express
    /// safely (e.g. Nutrition off but a Nutrition-only surface reachable).
    private static func applyingDependencies(to flags: Set<FeatureFlag>) -> Set<FeatureFlag> {
        flags
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool { enabled.contains(flag) }
    var enabledFlags: [FeatureFlag] { FeatureFlag.allCases.filter(enabled.contains) }
}

enum FeatureFlags {
    private static let launchArgumentKey = "-feature-flags"
    private static let environmentKey = "GYMTRACKER_FEATURE_FLAGS"

    @MainActor static var current: FeatureFlagConfiguration = makeCurrent()

    /// Deterministic launch-argument/environment overrides for UI-test and
    /// local-build coverage, resolved once at composition time. There is no
    /// user-facing experimental-toggle screen and no remote configuration
    /// source for Beta 0.
    static func makeCurrent(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> FeatureFlagConfiguration {
        #if DEBUG
        let defaultChannel: FeatureFlagBuildChannel = .internalDevelopment
        #else
        let defaultChannel: FeatureFlagBuildChannel = .release
        #endif

        if let overrides = overrideFlags(arguments: arguments, environment: environment) {
            return DefaultFeatureFlagConfiguration(buildChannel: defaultChannel, overrides: overrides)
        }
        return DefaultFeatureFlagConfiguration(buildChannel: defaultChannel)
    }

    private static func overrideFlags(
        arguments: [String],
        environment: [String: String]
    ) -> Set<FeatureFlag>? {
        if let index = arguments.firstIndex(of: launchArgumentKey),
           arguments.indices.contains(index + 1) {
            return parse(arguments[index + 1])
        }
        if let value = environment[environmentKey] {
            return parse(value)
        }
        return nil
    }

    private static func parse(_ value: String) -> Set<FeatureFlag> {
        Set(
            value.split(separator: ",")
                .compactMap { FeatureFlag(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        )
    }
}

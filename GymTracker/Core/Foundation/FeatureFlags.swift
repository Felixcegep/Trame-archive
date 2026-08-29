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
    case recipeGeneration
    /// On-device, user-confirmable workout drafting. Kept separate from the
    /// core workout paths so unavailable Apple Intelligence never blocks
    /// starting an empty, saved, planned, or rotating workout.
    case workoutGeneration
    /// The assessment surface inside Mobility. Separate from `mobility` because
    /// its data model shipped well before its UI, localization, accessibility,
    /// and screenshots did — and a ready model is not a reason to expose a
    /// half-finished screen to a tester.
    case mobilityAssessment
    /// The mobility program run surface (browse/activate/track a mobility
    /// plan). Separate from `mobility` for the same reason
    /// `mobilityAssessment` is: this ships without verified build/test/
    /// screenshot evidence, and a ready runtime is not a reason to expose an
    /// unverified screen to a tester.
    case mobilityProgram
    /// Sport discipline/strongman authoring on the exercise editor (Release
    /// 10). Kept separate from every existing strength flag for the same
    /// reason `mobilityProgram` is: this ships without verified build/test
    /// evidence, and progressive disclosure alone is not a reason to expose
    /// an unverified authoring surface to a tester.
    case sportSpecializations

    /// The flag this one cannot be reachable without. Declared per case rather
    /// than as a lookup table so a new flag has to answer the question.
    var prerequisite: FeatureFlag? {
        switch self {
        case .mobilityAssessment: .mobility
        case .mobilityProgram: .mobility
        case .recipeGeneration: .nutrition
        case .today, .mobility, .nutrition, .bodyWeight, .dailyCheckIn,
             .programBuilder, .advancedExecution, .betaFeedback,
             .workoutGeneration, .sportSpecializations: nil
        }
    }
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

extension FeatureFlagBuildChannel {
    /// The Info.plist key an archive uses to declare which matrix it was built
    /// for. Set it per build configuration (`INFOPLIST_KEY_GTFeatureFlagChannel`).
    ///
    /// How the project sets it today:
    ///
    /// - `Debug` declares nothing and resolves to `internalDevelopment`.
    /// - `Release` declares `beta`, because every build distributed so far has
    ///   gone to TestFlight. It previously declared `release`, which handed
    ///   testers every unfinished surface the beta wave exists to withhold —
    ///   the exact failure `resolve(infoDictionary:isDebugBuild:)` defaults
    ///   against, defeated by declaring the channel explicitly.
    ///
    /// Before the first App Store submission, add a third build configuration
    /// that declares `release` and archive general availability from *that*,
    /// leaving `Release` as the TestFlight configuration. One configuration
    /// cannot serve both: the channel is a property of who receives the build,
    /// and TestFlight and the App Store are different audiences.
    static let infoDictionaryKey = "GTFeatureFlagChannel"

    /// Resolves the matrix a build was produced for.
    ///
    /// This exists because `.beta` was previously unreachable: the channel came
    /// from `#if DEBUG` alone, so every distributed build resolved to `.release`
    /// and turned on every flag. A staged wave no build can select is not a gate.
    ///
    /// A distributed build that declares no channel resolves to `.beta`, not
    /// `.release`. The asymmetry is deliberate — an unlabelled archive is far more
    /// likely to be a tester build than general availability, and the expensive
    /// mistake is exposing an unfinished surface, not withholding a finished one.
    /// General availability says so explicitly by declaring `release`.
    ///
    /// Pure, so the mapping is verifiable without a build or a device. Deliberately
    /// not inferred from the App Store receipt: that API is deprecated in favour of
    /// StoreKit's `AppTransaction`, and StoreKit is explicitly deferred from the
    /// first beta (`FeaturesList.md` §4).
    static func resolve(infoDictionary: [String: Any]?, isDebugBuild: Bool) -> FeatureFlagBuildChannel {
        if let raw = infoDictionary?[infoDictionaryKey] as? String,
           let declared = FeatureFlagBuildChannel(rawValue: raw.trimmingCharacters(in: .whitespaces)) {
            return declared
        }
        return isDebugBuild ? .internalDevelopment : .beta
    }
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
        case .internalDevelopment:
            return Set(FeatureFlag.allCases)
        case .beta:
            return currentWave
        case .release:
            return generalAvailability
        }
    }

    /// What a TestFlight tester sees: everything already shipped, minus the
    /// surfaces whose UI is unfinished or temporarily hidden.
    static let currentWave: Set<FeatureFlag> = Set(FeatureFlag.allCases)
        .subtracting([
            .mobilityAssessment, .mobilityProgram, .recipeGeneration, .workoutGeneration,
            .sportSpecializations
        ])

    /// What general availability ships. Today: exactly what beta ships.
    ///
    /// This used to share `internalDevelopment`'s matrix — everything except
    /// Nutrition — which made `release` the *widest* matrix in the app rather
    /// than the most conservative one. A build declaring `release` would have
    /// exposed mobility assessment, mobility programs, workout generation and
    /// sport specializations: precisely the six surfaces `currentWave` withholds
    /// from testers for being unfinished, handed instead to the general public.
    ///
    /// Defined as "whatever beta ships" so that promoting a surface to general
    /// availability is a deliberate edit here, made once that surface has
    /// actually cleared its beta phase. A flag can never reach the public by
    /// being forgotten; only by being named.
    static let generalAvailability: Set<FeatureFlag> = currentWave

    /// The narrower RoadMap.md §4 "Beta 1 — core workout reliability" wave, kept
    /// because it is a real staged option and selectable by launch argument. It
    /// is not the default: `currentWave` is, and it is wider than this.
    ///
    /// `currentWave` withholds unfinished surfaces (mobility assessment/program,
    /// recipe generation, workout generation, sport specializations). Nutrition
    /// ships with the beta wave once its Today logging loop is verified.
    static let coreReliabilityOnly: Set<FeatureFlag> = [.today, .betaFeedback]

    /// Fails a dependent flag closed whenever its prerequisite is disabled,
    /// so an override set can never produce a combination no UI can express
    /// safely (e.g. Nutrition off but a Nutrition-only surface reachable).
    ///
    /// Resolved to a fixed point rather than in one pass, so a chain — a flag
    /// whose prerequisite has a prerequisite — cannot leave a dependant enabled.
    private static func applyingDependencies(to flags: Set<FeatureFlag>) -> Set<FeatureFlag> {
        var resolved = flags
        var didRemove = true
        while didRemove {
            didRemove = false
            for flag in resolved {
                guard let prerequisite = flag.prerequisite,
                      resolved.contains(prerequisite) == false
                else { continue }
                resolved.remove(flag)
                didRemove = true
            }
        }
        return resolved
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
        arguments: [String] = AppLaunchArguments.current,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        channel: FeatureFlagBuildChannel = .resolve(
            infoDictionary: Bundle.main.infoDictionary,
            isDebugBuild: isDebugBuild
        )
    ) -> FeatureFlagConfiguration {
        let defaultChannel = channel

        if let overrides = overrideFlags(arguments: arguments, environment: environment) {
            return DefaultFeatureFlagConfiguration(buildChannel: defaultChannel, overrides: overrides)
        }
        return DefaultFeatureFlagConfiguration(buildChannel: defaultChannel)
    }

    static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
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

import Foundation
import FoundationModels

/// UI-facing availability state for the recipe-generation prototype
/// (plan §8). Image input is currently gated on the same base-model
/// signal Apple exposes today; if a distinct per-modality capability check
/// ships later, `status(locale:)` is the only place that needs to change.
enum RecipeGenerationAvailabilityStatus: Equatable, Sendable {
    case fullyAvailable
    case textOnly
    case modelDownloading
    case unsupportedDevice
    case unsupportedLocale

    var allowsGeneration: Bool {
        switch self {
        case .fullyAvailable, .textOnly: true
        case .modelDownloading, .unsupportedDevice, .unsupportedLocale: false
        }
    }

    var allowsImageInput: Bool { self == .fullyAvailable }
}

@MainActor
enum RecipeGenerationAvailability {
    /// The installed Foundation Models framework has no `Attachment`/image
    /// type at all yet, so image input can never be used for generation
    /// regardless of device or region. Flip this once Apple ships a real
    /// per-modality capability check; `map(availability:supportsLocale:)`
    /// already exercises the `.fullyAvailable` branch that unlocks then.
    static let isImageInputSupported = false

    private static let launchArgumentKey = "-ui-test-recipe-generation-availability"
    private static let environmentKey = "GYMTRACKER_RECIPE_GENERATION_AVAILABILITY"

    static func status(
        locale: Locale = .current,
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RecipeGenerationAvailabilityStatus {
        // Apple Intelligence is rarely available on CI simulators, so a
        // dedicated launch-argument/environment override (mirroring
        // `FeatureFlags`' own `-feature-flags` mechanism) lets UI tests
        // exercise every generation state deterministically.
        if let override = overrideStatus(arguments: arguments, environment: environment) {
            return override
        }
        let model = SystemLanguageModel.default
        let base = map(availability: model.availability, supportsLocale: model.supportsLocale(locale))
        return capped(base, imageInputSupported: isImageInputSupported)
    }

    private static func overrideStatus(arguments: [String], environment: [String: String]) -> RecipeGenerationAvailabilityStatus? {
        let raw: String?
        if let index = arguments.firstIndex(of: launchArgumentKey), arguments.indices.contains(index + 1) {
            raw = arguments[index + 1]
        } else {
            raw = environment[environmentKey]
        }
        switch raw {
        case "fullyAvailable": return .fullyAvailable
        case "textOnly": return .textOnly
        case "modelDownloading": return .modelDownloading
        case "unsupportedDevice": return .unsupportedDevice
        case "unsupportedLocale": return .unsupportedLocale
        default: return nil
        }
    }

    /// Pure mapping, isolated from the live singleton so tests can exercise
    /// every branch without depending on the actual on-device model state.
    static func map(availability: SystemLanguageModel.Availability, supportsLocale: Bool) -> RecipeGenerationAvailabilityStatus {
        switch availability {
        case .available:
            return supportsLocale ? .fullyAvailable : .unsupportedLocale
        case .unavailable(.modelNotReady):
            return .modelDownloading
        case .unavailable:
            return .unsupportedDevice
        }
    }

    static func capped(_ status: RecipeGenerationAvailabilityStatus, imageInputSupported: Bool) -> RecipeGenerationAvailabilityStatus {
        guard status == .fullyAvailable, imageInputSupported == false else { return status }
        return .textOnly
    }
}

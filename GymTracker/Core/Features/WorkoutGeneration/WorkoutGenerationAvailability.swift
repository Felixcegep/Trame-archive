import Foundation
import FoundationModels

enum WorkoutGenerationAvailabilityStatus: Equatable, Sendable {
    case available
    case modelDownloading
    case unsupportedDevice
    case unsupportedLocale

    var allowsGeneration: Bool { self == .available }
}

/// Centralized, testable Apple Intelligence availability gate. The manual
/// workout paths deliberately do not consult this gate and always remain
/// available.
@MainActor
enum WorkoutGenerationAvailability {
    private static let launchArgumentKey = "-ui-test-workout-generation-availability"
    private static let environmentKey = "GYMTRACKER_WORKOUT_GENERATION_AVAILABILITY"

    static func status(
        locale: Locale = .current,
        arguments: [String] = AppLaunchArguments.current,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> WorkoutGenerationAvailabilityStatus {
        if let override = overrideStatus(arguments: arguments, environment: environment) {
            print("[GymTracker FoundationModels] Availability status overridden to: \(override)")
            return override
        }
        let model = SystemLanguageModel.default
        let availability = model.availability
        let supportsLocale = model.supportsLocale(locale)

        diagnoseFoundationModel(model: model, locale: locale, supportsLocale: supportsLocale)

        return map(availability: availability, supportsLocale: supportsLocale)
    }

    private static func diagnoseFoundationModel(
        model: SystemLanguageModel,
        locale: Locale,
        supportsLocale: Bool
    ) {
        print("[GymTracker FoundationModels Diagnosis]")
        print("  - Raw model availability: \(String(reflecting: model.availability))")
        print("  - Current Locale: \(locale.identifier)")
        print("  - Model supports locale: \(supportsLocale)")

        switch model.availability {
        case .available:
            if supportsLocale {
                print("  ✅ Model is available and supports current locale.")
            } else {
                print("  ⚠️ Model is available, but does NOT support locale '\(locale.identifier)'.")
            }
        case .unavailable(let reason):
            print("  ❌ Model is unavailable. Exact reason: \(String(reflecting: reason))")
        @unknown default:
            print("  ❌ Model is in unknown availability state.")
        }
    }

    static func map(
        availability: SystemLanguageModel.Availability,
        supportsLocale: Bool
    ) -> WorkoutGenerationAvailabilityStatus {
        switch availability {
        case .available:
            return supportsLocale ? .available : .unsupportedLocale
        case .unavailable(.modelNotReady):
            return .modelDownloading
        case .unavailable:
            return .unsupportedDevice
        }
    }

    private static func overrideStatus(
        arguments: [String],
        environment: [String: String]
    ) -> WorkoutGenerationAvailabilityStatus? {
        let raw: String?
        if let index = arguments.firstIndex(of: launchArgumentKey), arguments.indices.contains(index + 1) {
            raw = arguments[index + 1]
        } else {
            raw = environment[environmentKey]
        }
        switch raw {
        case "available": return .available
        case "modelDownloading": return .modelDownloading
        case "unsupportedDevice": return .unsupportedDevice
        case "unsupportedLocale": return .unsupportedLocale
        default: return nil
        }
    }
}

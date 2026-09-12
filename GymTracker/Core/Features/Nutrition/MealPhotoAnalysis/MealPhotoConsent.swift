import Foundation

/// Whether a compressed meal photo may leave the device for an estimate.
/// Stored separately from the Gemini key.
enum MealPhotoConsent: String, CaseIterable, Identifiable {
    case never
    case ask
    case sendWhenEstimating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: String(localized: "Never")
        case .ask: String(localized: "Ask before sending")
        case .sendWhenEstimating: String(localized: "Send when I estimate")
        }
    }

    static var `default`: MealPhotoConsent { .ask }
}

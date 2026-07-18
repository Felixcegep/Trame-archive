import Foundation

enum LiftQuality: String, Codable, CaseIterable, Hashable {
    case excellent
    case acceptable
    case technicallyPoor
    case missed

    var title: String {
        switch self {
        case .excellent: String(localized: "Excellent")
        case .acceptable: String(localized: "Acceptable")
        case .technicallyPoor: String(localized: "Technically poor")
        case .missed: String(localized: "Missed")
        }
    }
}

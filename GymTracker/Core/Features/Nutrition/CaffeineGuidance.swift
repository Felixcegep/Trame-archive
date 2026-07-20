import Foundation

nonisolated enum CaffeineAgeBand: Equatable {
    case adult
    case teen
    case child
    case unknown
}

nonisolated enum CaffeineDailyLimit: Equatable {
    case milligrams(Double, isPersonalized: Bool)
    case needsBodyWeight
    case notRecommended
}

nonisolated enum CaffeineGuidance {
    static func ageBand(birthdate: Date?, referenceDate: Date = .now) -> CaffeineAgeBand {
        guard let birthdate else { return .unknown }
        let calendar = Calendar(identifier: .gregorian)
        let years = calendar.dateComponents([.year], from: birthdate, to: referenceDate).year ?? 0
        switch years {
        case ..<14: return .child
        case 14...17: return .teen
        default: return .adult
        }
    }

    static func dailyLimit(ageBand: CaffeineAgeBand, bodyWeightKilograms: Double?) -> CaffeineDailyLimit {
        switch ageBand {
        case .adult, .unknown:
            return .milligrams(400, isPersonalized: ageBand == .adult)
        case .teen:
            guard let bodyWeightKilograms, bodyWeightKilograms > 0 else { return .needsBodyWeight }
            return .milligrams(2.5 * bodyWeightKilograms, isPersonalized: true)
        case .child:
            return .notRecommended
        }
    }
}

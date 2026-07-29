import Foundation

/// The intended use of a reusable `MobilityRoutine` prescription.
///
/// This is deliberately independent from `MobilitySessionContext`, which
/// records how one performed session was actually used. A development routine
/// may be launched as a warm-up, and neither value is derived from the other.
/// Purpose supports organization and discoverability only; it never restricts
/// launching a routine or makes a physiological claim.
enum MobilityRoutinePurpose: String, Codable, CaseIterable, Hashable, Identifiable {
    case preparation
    case development
    case cooldown

    var id: Self { self }

    var displayName: String {
        switch self {
        case .preparation:
            String(localized: "Preparation")
        case .development:
            String(localized: "Development")
        case .cooldown:
            // This must remain distinct from MobilitySessionContext.cooldown:
            // it is an author's intended role, not a performed-session state.
            String(localized: "Post-workout mobility")
        }
    }

    /// Fixed presentation order, independent of future `allCases` changes.
    static let displayOrder: [MobilityRoutinePurpose] = [.preparation, .development, .cooldown]
}

import Foundation

/// How a performed load maps onto the implement. Two loads are only ever
/// comparable when their convention matches — a Farmer's Hold at 100 kg per
/// hand is not the same stimulus as a 100 kg total-load carry, and neither
/// converts into the other without knowing the implement's handle spacing.
/// See `StrongmanLoadComparability`, the single enforcement point for this.
nonisolated enum LoadConvention: String, Codable, CaseIterable, Hashable, Sendable {
    case total
    case perHand
    case perSide
    case implementOnly
    case systemTotal

    var title: String {
        switch self {
        case .total: String(localized: "Total load", comment: "Strongman load convention: one combined load number")
        case .perHand: String(localized: "Per hand", comment: "Strongman load convention: load carried in each hand")
        case .perSide: String(localized: "Per side", comment: "Strongman load convention: load on each side of an implement")
        case .implementOnly: String(localized: "Implement only", comment: "Strongman load convention: the implement's own fixed weight")
        case .systemTotal: String(localized: "System total", comment: "Strongman load convention: implement plus every added load")
        }
    }
}

/// A coarse grouping of strongman event styles. Used to route performed
/// evidence to the right analytics policy without hardcoding per-exercise
/// logic — see `SportAnalyticsPolicyResolver`.
nonisolated enum StrongmanEventFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case overhead
    case deadlift
    case carry
    case hold
    case loading
    case throwing
    case pulling
    case pushing
    case medley

    var title: String {
        switch self {
        case .overhead: String(localized: "Overhead", comment: "Strongman event family")
        case .deadlift: String(localized: "Deadlift", comment: "Strongman event family")
        case .carry: String(localized: "Carry", comment: "Strongman event family")
        case .hold: String(localized: "Hold", comment: "Strongman event family")
        case .loading: String(localized: "Loading", comment: "Strongman event family")
        case .throwing: String(localized: "Throwing", comment: "Strongman event family")
        case .pulling: String(localized: "Pulling", comment: "Strongman event family")
        case .pushing: String(localized: "Pushing", comment: "Strongman event family")
        case .medley: String(localized: "Medley", comment: "Strongman event family")
        }
    }
}

/// The physical implement an event was performed on.
nonisolated enum StrongmanImplementKind: String, Codable, CaseIterable, Hashable, Sendable {
    case atlasStone
    case yoke
    case farmersHandles
    case log
    case axle
    case keg
    case sandbag
    case tire
    case sled
    case duffelBag
    case circusDumbbell
    case other

    var title: String {
        switch self {
        case .atlasStone: String(localized: "Atlas stone", comment: "Strongman implement")
        case .yoke: String(localized: "Yoke", comment: "Strongman implement")
        case .farmersHandles: String(localized: "Farmer's handles", comment: "Strongman implement")
        case .log: String(localized: "Log", comment: "Strongman implement")
        case .axle: String(localized: "Axle", comment: "Strongman implement")
        case .keg: String(localized: "Keg", comment: "Strongman implement")
        case .sandbag: String(localized: "Sandbag", comment: "Strongman implement")
        case .tire: String(localized: "Tire", comment: "Strongman implement")
        case .sled: String(localized: "Sled", comment: "Strongman implement")
        case .duffelBag: String(localized: "Duffel bag", comment: "Strongman implement")
        case .circusDumbbell: String(localized: "Circus dumbbell", comment: "Strongman implement")
        case .other: String(localized: "Other implement", comment: "Strongman implement")
        }
    }

    /// A starting point only, used when an author has not explicitly chosen a
    /// convention. `StrongmanImplementProfile.loadConvention` — the authored
    /// or snapshotted value — is what analytics and comparison ever read.
    var defaultLoadConvention: LoadConvention {
        switch self {
        case .farmersHandles: .perHand
        case .yoke, .sandbag, .keg, .tire, .sled, .duffelBag, .circusDumbbell: .total
        case .atlasStone, .log, .axle: .implementOnly
        case .other: .total
        }
    }
}

/// The ground an event was performed on. Distinct from the exercise library's
/// general equipment vocabulary because it materially changes strongman
/// performance (a yoke walk over sand is not comparable to one on a platform).
nonisolated enum SurfaceType: String, Codable, CaseIterable, Hashable, Sendable {
    case platform
    case turf
    case grass
    case sand
    case gravel
    case asphalt
    case snow
    case other

    var title: String {
        switch self {
        case .platform: String(localized: "Platform", comment: "Strongman event surface")
        case .turf: String(localized: "Turf", comment: "Strongman event surface")
        case .grass: String(localized: "Grass", comment: "Strongman event surface")
        case .sand: String(localized: "Sand", comment: "Strongman event surface")
        case .gravel: String(localized: "Gravel", comment: "Strongman event surface")
        case .asphalt: String(localized: "Asphalt", comment: "Strongman event surface")
        case .snow: String(localized: "Snow", comment: "Strongman event surface")
        case .other: String(localized: "Other surface", comment: "Strongman event surface")
        }
    }
}

/// Authored (catalog, on `Exercise`) or snapshotted (performed, on
/// `ExerciseSet`) description of the specific implement an event was
/// performed on. Performed evidence always keeps its own copy — see
/// `ExerciseSet.strongmanImplementProfile` — so a later catalog edit (a gym's
/// yoke gets re-measured, an exercise's default implement changes) never
/// rewrites what already happened.
nonisolated struct StrongmanImplementProfile: Codable, Hashable, Sendable {
    var kind: StrongmanImplementKind
    var loadConvention: LoadConvention
    var handleHeightMeters: Double?
    var handleDiameterMeters: Double?
    var loadingHeightMeters: Double?
    var surface: SurfaceType?
    var inclinePercent: Double?
    var notes: String?

    init(
        kind: StrongmanImplementKind,
        loadConvention: LoadConvention? = nil,
        handleHeightMeters: Double? = nil,
        handleDiameterMeters: Double? = nil,
        loadingHeightMeters: Double? = nil,
        surface: SurfaceType? = nil,
        inclinePercent: Double? = nil,
        notes: String? = nil
    ) {
        self.kind = kind
        self.loadConvention = loadConvention ?? kind.defaultLoadConvention
        self.handleHeightMeters = handleHeightMeters
        self.handleDiameterMeters = handleDiameterMeters
        self.loadingHeightMeters = loadingHeightMeters
        self.surface = surface
        self.inclinePercent = inclinePercent
        self.notes = notes
    }
}

/// The single enforcement point for the strongman non-negotiable: loads under
/// a different convention are never numerically compared, ranked, or folded
/// into the same record line. Every record/PR/previous-performance lookup
/// that touches strongman evidence must route through this rather than
/// comparing `ExerciseSet.weight` directly.
nonisolated enum StrongmanLoadComparability {
    /// `nil` on either side (every set logged before this slice, and every
    /// non-strongman set) compares exactly as it always has — only a genuine
    /// convention mismatch breaks comparability.
    static func areComparable(_ lhs: LoadConvention?, _ rhs: LoadConvention?) -> Bool {
        lhs == rhs
    }

    /// A stable grouping key so a caller can take a max/best within one
    /// convention without ever crossing the boundary. Safe to use directly as
    /// a dictionary or record key; non-strongman sets all share one key,
    /// matching their current ungrouped comparison behavior exactly.
    static func comparisonGroupKey(_ convention: LoadConvention?) -> String {
        convention?.rawValue ?? "legacyOrNonStrongman"
    }
}

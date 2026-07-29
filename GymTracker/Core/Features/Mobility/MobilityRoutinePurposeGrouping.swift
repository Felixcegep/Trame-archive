import Foundation

enum MobilityPurposeFilter: Hashable {
    case all
    case purpose(MobilityRoutinePurpose)
    case unspecified

    /// Stable, unlocalized token for accessibility identifiers.
    var token: String {
        switch self {
        case .all: "all"
        case .purpose(let purpose): purpose.rawValue
        case .unspecified: "unspecified"
        }
    }
}

struct MobilityRoutineGroup: Identifiable {
    let purpose: MobilityRoutinePurpose?
    let routines: [MobilityRoutine]

    var id: String { purpose?.rawValue ?? "unspecified" }
}

enum MobilityRoutinePurposeGrouping {
    /// Preserves the input order within each group. Callers own archival and
    /// query ordering, allowing this function to remain view-free and pure.
    static func groups(for routines: [MobilityRoutine]) -> [MobilityRoutineGroup] {
        let purposes: [MobilityRoutinePurpose?] = MobilityRoutinePurpose.displayOrder.map(Optional.some) + [nil]
        return purposes.compactMap { purpose in
            let matching = routines.filter { $0.purpose == purpose }
            guard matching.isEmpty == false else { return nil }
            return MobilityRoutineGroup(purpose: purpose, routines: matching)
        }
    }

    static func filtered(_ routines: [MobilityRoutine], by filter: MobilityPurposeFilter) -> [MobilityRoutine] {
        switch filter {
        case .all:
            routines
        case .purpose(let purpose):
            routines.filter { $0.purpose == purpose }
        case .unspecified:
            routines.filter { $0.purpose == nil }
        }
    }
}

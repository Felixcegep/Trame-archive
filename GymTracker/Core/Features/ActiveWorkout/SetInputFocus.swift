import SwiftData

struct SetInputFocus: Hashable {
    enum Field: Int, CaseIterable, Hashable {
        case repetitions
        case weight
        case duration
        case distance
        case calories
    }

    let exerciseID: PersistentIdentifier
    let setID: PersistentIdentifier
    let field: Field

    init(
        exerciseID: PersistentIdentifier,
        setID: PersistentIdentifier,
        field: Field = .repetitions
    ) {
        self.exerciseID = exerciseID
        self.setID = setID
        self.field = field
    }
}

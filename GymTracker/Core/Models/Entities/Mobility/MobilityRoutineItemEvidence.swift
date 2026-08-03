import Foundation
import SwiftData

/// Optional advanced prescription metadata kept outside the frozen baseline
/// routine-item model. `routineItemID` is an ownership key, not a live
/// relationship: starting a session copies these values into performed
/// evidence so later prescription edits cannot rewrite history.
@Model
final class MobilityRoutineItemEvidence {
    var id: UUID
    @Attribute(.unique) var routineItemID: UUID
    var methodRaw: String?
    var purposeRaw: String?
    var createdAt: Date
    var updatedAt: Date

    var method: MobilityMethod? {
        get { methodRaw.flatMap(MobilityMethod.init(rawValue:)) }
        set { methodRaw = newValue?.rawValue }
    }

    var purpose: MobilityTrainingPurpose? {
        get { purposeRaw.flatMap(MobilityTrainingPurpose.init(rawValue:)) }
        set { purposeRaw = newValue?.rawValue }
    }

    init(
        routineItemID: UUID,
        method: MobilityMethod? = nil,
        purpose: MobilityTrainingPurpose? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.routineItemID = routineItemID
        self.methodRaw = method?.rawValue
        self.purposeRaw = purpose?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

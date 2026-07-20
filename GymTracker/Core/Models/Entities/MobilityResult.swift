import Foundation
import SwiftData

@Model
final class MobilityResult {
    var id: UUID
    var sideRaw: String
    var statusRaw: String
    var prescribedDurationSeconds: Int?
    var prescribedRepetitions: Int?
    var performedDurationSeconds: Int?
    var performedRepetitions: Int?
    var perceivedIntensity: Int?
    var discomfortNote: String?
    var startedAt: Date?
    var completedAt: Date?
    var entry: MobilityEntry?

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    var status: MobilityResultStatus {
        get { MobilityResultStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    init(
        side: MobilitySide,
        prescribedDurationSeconds: Int? = nil,
        prescribedRepetitions: Int? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.sideRaw = side.rawValue
        self.statusRaw = MobilityResultStatus.notStarted.rawValue
        self.prescribedDurationSeconds = prescribedDurationSeconds
        self.prescribedRepetitions = prescribedRepetitions
        self.performedDurationSeconds = nil
        self.performedRepetitions = nil
        self.perceivedIntensity = nil
        self.discomfortNote = nil
        self.startedAt = nil
        self.completedAt = nil
    }
}

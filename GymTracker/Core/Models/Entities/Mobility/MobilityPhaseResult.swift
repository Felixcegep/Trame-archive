import Foundation
import SwiftData

@Model
final class MobilityPhaseResult {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var phaseTypeRaw: String = "initialStretch"
    var prescribedDurationSeconds: Int = 20
    var performedDurationSeconds: Int?
    var cycleIndex: Int = 0
    var sideRaw: String = "none"
    var prescribedIntensityRaw: String?
    var performedIntensityRaw: String?
    var statusRaw: String = "notStarted"
    var startedAt: Date?
    var completedAt: Date?
    var entry: MobilityEntry?

    var phaseType: PNFPhaseType {
        get { PNFPhaseType(rawValue: phaseTypeRaw) ?? .initialStretch }
        set { phaseTypeRaw = newValue.rawValue }
    }

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    var prescribedIntensity: ContractionIntensity? {
        get { prescribedIntensityRaw.flatMap(ContractionIntensity.init(rawValue:)) }
        set { prescribedIntensityRaw = newValue?.rawValue }
    }

    var performedIntensity: ContractionIntensity? {
        get { performedIntensityRaw.flatMap(ContractionIntensity.init(rawValue:)) }
        set { performedIntensityRaw = newValue?.rawValue }
    }

    var status: MobilityResultStatus {
        get { MobilityResultStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    init(
        orderIndex: Int,
        phaseType: PNFPhaseType,
        prescribedDurationSeconds: Int,
        cycleIndex: Int = 0,
        side: MobilitySide = .none,
        prescribedIntensity: ContractionIntensity? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.phaseTypeRaw = phaseType.rawValue
        self.prescribedDurationSeconds = prescribedDurationSeconds
        self.cycleIndex = cycleIndex
        self.sideRaw = side.rawValue
        self.prescribedIntensityRaw = prescribedIntensity?.rawValue
        self.statusRaw = MobilityResultStatus.notStarted.rawValue
    }
}

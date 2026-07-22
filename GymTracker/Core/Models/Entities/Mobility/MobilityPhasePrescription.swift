import Foundation
import SwiftData

@Model
final class MobilityPhasePrescription {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var phaseTypeRaw: String = "initialStretch"
    var durationSeconds: Int = 20
    var contractionIntensityRaw: String? = "moderate"
    var instructions: String?
    var sideRaw: String = "none"
    var routineItem: MobilityRoutineItem?

    var phaseType: PNFPhaseType {
        get { PNFPhaseType(rawValue: phaseTypeRaw) ?? .initialStretch }
        set { phaseTypeRaw = newValue.rawValue }
    }

    var contractionIntensity: ContractionIntensity? {
        get { contractionIntensityRaw.flatMap(ContractionIntensity.init(rawValue:)) }
        set { contractionIntensityRaw = newValue?.rawValue }
    }

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    init(
        orderIndex: Int,
        phaseType: PNFPhaseType,
        durationSeconds: Int,
        contractionIntensity: ContractionIntensity? = nil,
        instructions: String? = nil,
        side: MobilitySide = .none,
        id: UUID = UUID()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.phaseTypeRaw = phaseType.rawValue
        self.durationSeconds = durationSeconds
        self.contractionIntensityRaw = contractionIntensity?.rawValue
        self.instructions = instructions
        self.sideRaw = side.rawValue
    }
}

enum PNFPhaseType: String, Codable, CaseIterable, Hashable {
    case initialStretch
    case contraction
    case relax
    case deeperStretch
    case activeContraction
    case rest

    var title: String {
        switch self {
        case .initialStretch: return "Initial Stretch"
        case .contraction: return "Contract"
        case .relax: return "Relax"
        case .deeperStretch: return "Deeper Stretch"
        case .activeContraction: return "Active Contract"
        case .rest: return "Rest"
        }
    }
}

enum ContractionIntensity: String, Codable, CaseIterable, Hashable {
    case light
    case moderate
    case strong

    var title: String {
        switch self {
        case .light: return "Light effort"
        case .moderate: return "Moderate effort"
        case .strong: return "Strong effort"
        }
    }
}

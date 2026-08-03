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
    var breathingPrescriptionData: Data?
    var tempoPrescriptionData: Data?
    var assistancePrescriptionData: Data?
    var supportLevelRaw: String?
    var metricProfileData: Data?
    var metricTargetsData: Data?
    /// Stable key of the `MobilityRoutineBlock` this item belongs to, or
    /// `nil` for an unblocked item. This is an ownership key, not a live
    /// relationship, matching `routineItemID` above.
    var blockKey: String?
    var sideStrategyRaw: String?
    var restPrescriptionData: Data?
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

    var breathingPrescription: MobilityBreathingPrescription? {
        get { Self.decode(MobilityBreathingPrescription.self, from: breathingPrescriptionData) }
        set { breathingPrescriptionData = Self.encode(newValue?.isEmpty == false ? newValue : nil) }
    }

    var tempoPrescription: MobilityTempoPrescription? {
        get { Self.decode(MobilityTempoPrescription.self, from: tempoPrescriptionData) }
        set { tempoPrescriptionData = Self.encode(newValue?.isEmpty == false ? newValue : nil) }
    }

    var assistancePrescription: MobilityAssistancePrescription? {
        get { Self.decode(MobilityAssistancePrescription.self, from: assistancePrescriptionData) }
        set { assistancePrescriptionData = Self.encode(newValue) }
    }

    var supportLevel: MobilitySupportLevel? {
        get { supportLevelRaw.flatMap(MobilitySupportLevel.init(rawValue:)) }
        set { supportLevelRaw = newValue?.rawValue }
    }

    var metricProfile: MobilityMetricProfile? {
        get { Self.decode(MobilityMetricProfile.self, from: metricProfileData) }
        set { metricProfileData = Self.encode(newValue) }
    }

    var metricTargets: MobilityMetricTargets? {
        get { Self.decode(MobilityMetricTargets.self, from: metricTargetsData) }
        set { metricTargetsData = Self.encode(newValue) }
    }

    var sideStrategy: MobilitySideStrategy? {
        get { sideStrategyRaw.flatMap(MobilitySideStrategy.init(rawValue:)) }
        set { sideStrategyRaw = newValue?.rawValue }
    }

    /// Authored scoped-rest override for this item. When absent, execution
    /// falls back to the legacy numeric `restSeconds` mapping.
    var restPrescription: MobilityRestPrescription? {
        get { Self.decode(MobilityRestPrescription.self, from: restPrescriptionData) }
        set { restPrescriptionData = Self.encode(newValue) }
    }

    init(
        routineItemID: UUID,
        method: MobilityMethod? = nil,
        purpose: MobilityTrainingPurpose? = nil,
        breathingPrescription: MobilityBreathingPrescription? = nil,
        tempoPrescription: MobilityTempoPrescription? = nil,
        assistancePrescription: MobilityAssistancePrescription? = nil,
        supportLevel: MobilitySupportLevel? = nil,
        metricProfile: MobilityMetricProfile? = nil,
        metricTargets: MobilityMetricTargets? = nil,
        blockKey: String? = nil,
        sideStrategy: MobilitySideStrategy? = nil,
        restPrescription: MobilityRestPrescription? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.routineItemID = routineItemID
        self.methodRaw = method?.rawValue
        self.purposeRaw = purpose?.rawValue
        self.breathingPrescriptionData = nil
        self.tempoPrescriptionData = nil
        self.assistancePrescriptionData = nil
        self.supportLevelRaw = supportLevel?.rawValue
        self.metricProfileData = Self.encode(metricProfile)
        self.metricTargetsData = Self.encode(metricTargets)
        self.blockKey = blockKey
        self.sideStrategyRaw = sideStrategy?.rawValue
        self.restPrescriptionData = Self.encode(restPrescription)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.breathingPrescription = breathingPrescription
        self.tempoPrescription = tempoPrescription
        self.assistancePrescription = assistancePrescription
    }

    private static func encode<Value: Encodable>(_ value: Value?) -> Data? {
        value.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

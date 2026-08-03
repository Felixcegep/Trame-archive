import Foundation
import SwiftData

/// Side-specific performed mobility evidence. This is intentionally separate
/// from assessment observations and from workout results.
@Model
final class MobilityResultEvidence {
    var id: UUID
    @Attribute(.unique) var resultID: UUID
    var entryIDSnapshot: UUID
    var sideRaw: String
    var methodSnapshotRaw: String?
    var purposeSnapshotRaw: String?
    var breathingPrescriptionSnapshotData: Data?
    var tempoPrescriptionSnapshotData: Data?
    var assistancePrescriptionSnapshotData: Data?
    var supportLevelSnapshotRaw: String?
    var metricProfileSnapshotData: Data?
    var metricTargetsSnapshotData: Data?
    var performedBreathingCycles: Int?
    var performedAssistanceLevel: Int?
    var performedSupportLevelRaw: String?
    var sensationRaw: String?
    var movementQualityRaw: String?
    var compensationKeysData: Data?
    var recordedAt: Date

    var side: MobilitySide {
        MobilitySide(rawValue: sideRaw) ?? .none
    }

    var methodSnapshot: MobilityMethod? {
        methodSnapshotRaw.flatMap(MobilityMethod.init(rawValue:))
    }

    var purposeSnapshot: MobilityTrainingPurpose? {
        purposeSnapshotRaw.flatMap(MobilityTrainingPurpose.init(rawValue:))
    }

    var breathingPrescriptionSnapshot: MobilityBreathingPrescription? {
        Self.decode(MobilityBreathingPrescription.self, from: breathingPrescriptionSnapshotData)
    }

    var tempoPrescriptionSnapshot: MobilityTempoPrescription? {
        Self.decode(MobilityTempoPrescription.self, from: tempoPrescriptionSnapshotData)
    }

    var assistancePrescriptionSnapshot: MobilityAssistancePrescription? {
        Self.decode(MobilityAssistancePrescription.self, from: assistancePrescriptionSnapshotData)
    }

    var supportLevelSnapshot: MobilitySupportLevel? {
        supportLevelSnapshotRaw.flatMap(MobilitySupportLevel.init(rawValue:))
    }

    var metricProfileSnapshot: MobilityMetricProfile? {
        Self.decode(MobilityMetricProfile.self, from: metricProfileSnapshotData)
    }

    var metricTargetsSnapshot: MobilityMetricTargets? {
        Self.decode(MobilityMetricTargets.self, from: metricTargetsSnapshotData)
    }

    var performedSupportLevel: MobilitySupportLevel? {
        get { performedSupportLevelRaw.flatMap(MobilitySupportLevel.init(rawValue:)) }
        set { performedSupportLevelRaw = newValue?.rawValue }
    }

    var sensation: MobilitySensation? {
        get { sensationRaw.flatMap(MobilitySensation.init(rawValue:)) }
        set { sensationRaw = newValue?.rawValue }
    }

    var movementQuality: MobilityMovementQuality? {
        get { movementQualityRaw.flatMap(MobilityMovementQuality.init(rawValue:)) }
        set { movementQualityRaw = newValue?.rawValue }
    }

    var compensationKeys: Set<MobilityCompensationKey> {
        get {
            guard let compensationKeysData,
                  let rawValues = try? JSONDecoder().decode([String].self, from: compensationKeysData) else {
                return []
            }
            return Set(rawValues.compactMap(MobilityCompensationKey.init(rawValue:)))
        }
        set {
            let rawValues = newValue.map(\.rawValue).sorted()
            compensationKeysData = rawValues.isEmpty ? nil : try? JSONEncoder().encode(rawValues)
        }
    }

    /// Central safety boundary for future mobility progression adapters.
    /// Stop signals remain historical evidence but can never be recommendation
    /// evidence.
    var isProgressionEligible: Bool {
        sensation?.isStopSignal != true
    }

    init(
        resultID: UUID,
        entryIDSnapshot: UUID,
        side: MobilitySide,
        methodSnapshot: MobilityMethod?,
        purposeSnapshot: MobilityTrainingPurpose?,
        breathingPrescriptionSnapshot: MobilityBreathingPrescription? = nil,
        tempoPrescriptionSnapshot: MobilityTempoPrescription? = nil,
        assistancePrescriptionSnapshot: MobilityAssistancePrescription? = nil,
        supportLevelSnapshot: MobilitySupportLevel? = nil,
        metricProfileSnapshot: MobilityMetricProfile? = nil,
        metricTargetsSnapshot: MobilityMetricTargets? = nil,
        performedBreathingCycles: Int? = nil,
        performedAssistanceLevel: Int? = nil,
        performedSupportLevel: MobilitySupportLevel? = nil,
        sensation: MobilitySensation? = nil,
        movementQuality: MobilityMovementQuality? = nil,
        compensationKeys: Set<MobilityCompensationKey> = [],
        id: UUID = UUID(),
        recordedAt: Date = .now
    ) {
        self.id = id
        self.resultID = resultID
        self.entryIDSnapshot = entryIDSnapshot
        self.sideRaw = side.rawValue
        self.methodSnapshotRaw = methodSnapshot?.rawValue
        self.purposeSnapshotRaw = purposeSnapshot?.rawValue
        self.breathingPrescriptionSnapshotData = Self.encode(breathingPrescriptionSnapshot)
        self.tempoPrescriptionSnapshotData = Self.encode(tempoPrescriptionSnapshot)
        self.assistancePrescriptionSnapshotData = Self.encode(assistancePrescriptionSnapshot)
        self.supportLevelSnapshotRaw = supportLevelSnapshot?.rawValue
        self.metricProfileSnapshotData = Self.encode(metricProfileSnapshot)
        self.metricTargetsSnapshotData = Self.encode(metricTargetsSnapshot)
        self.performedBreathingCycles = performedBreathingCycles
        self.performedAssistanceLevel = performedAssistanceLevel
        self.performedSupportLevelRaw = performedSupportLevel?.rawValue
        self.sensationRaw = sensation?.rawValue
        self.movementQualityRaw = movementQuality?.rawValue
        self.compensationKeysData = nil
        self.recordedAt = recordedAt
        self.compensationKeys = compensationKeys
    }

    /// Support and assistance are comparison conditions, not outcomes.
    func isComparable(to currentPrescription: MobilityResultEvidence?) -> Bool {
        guard let currentPrescription else {
            return methodSnapshotRaw == nil
                && purposeSnapshotRaw == nil
                && supportLevelSnapshotRaw == nil
                && assistancePrescriptionSnapshot == nil
        }
        let priorSupport = performedSupportLevelRaw ?? supportLevelSnapshotRaw
        var priorAssistance = assistancePrescriptionSnapshot
        if performedAssistanceLevel != nil {
            priorAssistance?.level = performedAssistanceLevel
        }
        return methodSnapshotRaw == currentPrescription.methodSnapshotRaw
            && purposeSnapshotRaw == currentPrescription.purposeSnapshotRaw
            && priorSupport == currentPrescription.supportLevelSnapshotRaw
            && priorAssistance == currentPrescription.assistancePrescriptionSnapshot
    }

    private static func encode<Value: Encodable>(_ value: Value?) -> Data? {
        value.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

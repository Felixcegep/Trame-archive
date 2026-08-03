import Foundation
import SwiftData

@MainActor
enum MobilityEvidenceService {
    static func prescriptionEvidence(
        using modelContext: ModelContext
    ) -> [UUID: MobilityRoutineItemEvidence] {
        let records = (try? modelContext.fetch(FetchDescriptor<MobilityRoutineItemEvidence>())) ?? []
        return Dictionary(records.map { ($0.routineItemID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func resultEvidence(
        for resultID: UUID,
        using modelContext: ModelContext
    ) -> MobilityResultEvidence? {
        let descriptor = FetchDescriptor<MobilityResultEvidence>(
            predicate: #Predicate { $0.resultID == resultID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    static func resultEvidence(
        using modelContext: ModelContext
    ) -> [UUID: MobilityResultEvidence] {
        let records = (try? modelContext.fetch(FetchDescriptor<MobilityResultEvidence>())) ?? []
        return Dictionary(records.map { ($0.resultID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func upsertPrescription(
        for routineItemID: UUID,
        method: MobilityMethod?,
        purpose: MobilityTrainingPurpose?,
        breathingPrescription: MobilityBreathingPrescription? = nil,
        tempoPrescription: MobilityTempoPrescription? = nil,
        assistancePrescription: MobilityAssistancePrescription? = nil,
        supportLevel: MobilitySupportLevel? = nil,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        if method == nil,
           purpose == nil,
           breathingPrescription?.isEmpty != false,
           tempoPrescription?.isEmpty != false,
           assistancePrescription == nil,
           supportLevel == nil {
            if let existing {
                existing.method = nil
                existing.purpose = nil
                existing.breathingPrescription = nil
                existing.tempoPrescription = nil
                existing.assistancePrescription = nil
                existing.supportLevel = nil
                existing.updatedAt = now
                if isEmpty(existing) { modelContext.delete(existing) }
            }
        } else if let existing {
            existing.method = method
            existing.purpose = purpose
            existing.breathingPrescription = breathingPrescription
            existing.tempoPrescription = tempoPrescription
            existing.assistancePrescription = assistancePrescription
            existing.supportLevel = supportLevel
            existing.updatedAt = now
        } else {
            modelContext.insert(
                MobilityRoutineItemEvidence(
                    routineItemID: routineItemID,
                    method: method,
                    purpose: purpose,
                    breathingPrescription: breathingPrescription,
                    tempoPrescription: tempoPrescription,
                    assistancePrescription: assistancePrescription,
                    supportLevel: supportLevel,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    /// Metric authoring has a separate mutation so an older advanced-details
    /// editor cannot erase a profile it does not display.
    static func upsertMetricPrescription(
        for routineItemID: UUID,
        profile: MobilityMetricProfile?,
        targets: MobilityMetricTargets?,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        if let existing {
            existing.metricProfile = profile
            existing.metricTargets = targets
            existing.updatedAt = now
            if isEmpty(existing) { modelContext.delete(existing) }
        } else if profile != nil || targets != nil {
            modelContext.insert(
                MobilityRoutineItemEvidence(
                    routineItemID: routineItemID,
                    metricProfile: profile,
                    metricTargets: targets,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    private static func isEmpty(_ evidence: MobilityRoutineItemEvidence) -> Bool {
        evidence.methodRaw == nil
            && evidence.purposeRaw == nil
            && evidence.breathingPrescriptionData == nil
            && evidence.tempoPrescriptionData == nil
            && evidence.assistancePrescriptionData == nil
            && evidence.supportLevelRaw == nil
            && evidence.metricProfileData == nil
            && evidence.metricTargetsData == nil
    }

    static func apply(
        _ input: MobilityResultInput,
        to result: MobilityResult,
        using modelContext: ModelContext
    ) {
        guard let evidence = resultEvidence(for: result.id, using: modelContext) else { return }
        evidence.sensation = input.sensation
        evidence.movementQuality = input.movementQuality
        evidence.compensationKeys = input.compensationKeys
        evidence.performedBreathingCycles = input.performedBreathingCycles
        evidence.performedAssistanceLevel = input.performedAssistanceLevel
        evidence.performedSupportLevel = input.performedSupportLevel
        evidence.recordedAt = .now
    }

    static func isProgressionEligible(
        resultID: UUID,
        using modelContext: ModelContext
    ) -> Bool {
        resultEvidence(for: resultID, using: modelContext)?.isProgressionEligible ?? true
    }
}

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
        return try? modelContext.fetch(descriptor).first
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
        now: Date = .now,
        using modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        let existing = try? modelContext.fetch(descriptor).first
        if method == nil, purpose == nil {
            if let existing { modelContext.delete(existing) }
        } else if let existing {
            existing.method = method
            existing.purpose = purpose
            existing.updatedAt = now
        } else {
            modelContext.insert(
                MobilityRoutineItemEvidence(
                    routineItemID: routineItemID,
                    method: method,
                    purpose: purpose,
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

    static func apply(
        _ input: MobilityResultInput,
        to result: MobilityResult,
        using modelContext: ModelContext
    ) {
        guard let evidence = resultEvidence(for: result.id, using: modelContext) else { return }
        evidence.sensation = input.sensation
        evidence.movementQuality = input.movementQuality
        evidence.compensationKeys = input.compensationKeys
        evidence.recordedAt = .now
    }

    static func isProgressionEligible(
        resultID: UUID,
        using modelContext: ModelContext
    ) -> Bool {
        resultEvidence(for: resultID, using: modelContext)?.isProgressionEligible ?? true
    }
}

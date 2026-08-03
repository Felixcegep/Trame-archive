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

    static func entryEvidence(
        for entryID: UUID,
        using modelContext: ModelContext
    ) -> MobilityEntryEvidence? {
        let descriptor = FetchDescriptor<MobilityEntryEvidence>(
            predicate: #Predicate { $0.entryID == entryID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    static func entryEvidence(
        using modelContext: ModelContext
    ) -> [UUID: MobilityEntryEvidence] {
        let records = (try? modelContext.fetch(FetchDescriptor<MobilityEntryEvidence>())) ?? []
        return Dictionary(records.map { ($0.entryID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// All authored blocks for one routine, ordered for authoring/session
    /// materialization.
    static func blocks(
        forRoutineID routineID: UUID,
        using modelContext: ModelContext
    ) -> [MobilityRoutineBlock] {
        let descriptor = FetchDescriptor<MobilityRoutineBlock>(
            predicate: #Predicate { $0.routineID == routineID }
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).sorted {
            $0.orderIndex == $1.orderIndex ? $0.blockKey < $1.blockKey : $0.orderIndex < $1.orderIndex
        }
    }

    static func block(
        forKey blockKey: String,
        using modelContext: ModelContext
    ) -> MobilityRoutineBlock? {
        let descriptor = FetchDescriptor<MobilityRoutineBlock>(
            predicate: #Predicate { $0.blockKey == blockKey }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    @discardableResult
    static func upsertBlock(
        blockKey: String? = nil,
        routineID: UUID,
        orderIndex: Int,
        name: String?,
        kind: MobilityBlockKind,
        targetRounds: Int?,
        restPrescription: MobilityRestPrescription?,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityRoutineBlock? {
        let existing = blockKey.flatMap { block(forKey: $0, using: modelContext) }
        let resolvedBlock: MobilityRoutineBlock
        if let existing {
            existing.orderIndex = orderIndex
            existing.name = name
            existing.kind = kind
            existing.targetRounds = targetRounds
            existing.restPrescription = restPrescription
            existing.updatedAt = now
            resolvedBlock = existing
        } else {
            resolvedBlock = MobilityRoutineBlock(
                blockKey: blockKey ?? UUID().uuidString,
                routineID: routineID,
                orderIndex: orderIndex,
                name: name,
                kind: kind,
                targetRounds: targetRounds,
                restPrescription: restPrescription,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(resolvedBlock)
        }
        do {
            try modelContext.save()
            return resolvedBlock
        } catch {
            modelContext.rollback()
            return nil
        }
    }

    @discardableResult
    static func deleteBlock(
        blockKey: String,
        routineItemIDs: [UUID],
        using modelContext: ModelContext
    ) -> Bool {
        guard let block = block(forKey: blockKey, using: modelContext) else { return false }
        modelContext.delete(block)
        // Membership is expressed on the item's evidence, not on the block,
        // so deleting a block must explicitly clear every member's key
        // rather than relying on a cascade rule that does not exist for this
        // ownership-key relationship.
        for routineItemID in routineItemIDs {
            let descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
                predicate: #Predicate { $0.routineItemID == routineItemID }
            )
            if let evidence = (try? modelContext.fetch(descriptor))?.first, evidence.blockKey == blockKey {
                evidence.blockKey = nil
            }
        }
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
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

    /// Block membership, side strategy and scoped-rest override have a
    /// separate mutation so an older advanced-details editor cannot erase
    /// authoring it does not display, matching `upsertMetricPrescription`.
    @discardableResult
    static func upsertStructurePrescription(
        for routineItemID: UUID,
        blockKey: String?,
        sideStrategy: MobilitySideStrategy?,
        restPrescription: MobilityRestPrescription?,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        if let existing {
            existing.blockKey = blockKey
            existing.sideStrategy = sideStrategy
            existing.restPrescription = restPrescription
            existing.updatedAt = now
            if isEmpty(existing) { modelContext.delete(existing) }
        } else if blockKey != nil || sideStrategy != nil || restPrescription != nil {
            modelContext.insert(
                MobilityRoutineItemEvidence(
                    routineItemID: routineItemID,
                    blockKey: blockKey,
                    sideStrategy: sideStrategy,
                    restPrescription: restPrescription,
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
            && evidence.blockKey == nil
            && evidence.sideStrategyRaw == nil
            && evidence.restPrescriptionData == nil
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

    /// Snapshots the rest a resolved transition prescribed after this side's
    /// result became terminal. Called once per terminal result so a later
    /// prescription edit (a changed item rest, a renamed/deleted block)
    /// cannot rewrite what this session actually rested for.
    static func snapshotRest(
        _ rest: MobilityRestPrescription,
        resultID: UUID,
        using modelContext: ModelContext
    ) {
        guard let evidence = resultEvidence(for: resultID, using: modelContext) else { return }
        evidence.restSnapshot = rest
    }

    static func isProgressionEligible(
        resultID: UUID,
        using modelContext: ModelContext
    ) -> Bool {
        resultEvidence(for: resultID, using: modelContext)?.isProgressionEligible ?? true
    }
}

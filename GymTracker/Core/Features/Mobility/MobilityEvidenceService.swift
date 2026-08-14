import Foundation
import SwiftData

@MainActor
enum MobilityEvidenceService {
    static func prescriptionEvidence(
        for routineItemID: UUID,
        using modelContext: ModelContext
    ) -> MobilityRoutineItemEvidence? {
        var descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Resolves only the items a routine is about to materialize. SwiftData's
    /// current predicate translation is unreliable for captured UUID arrays,
    /// so a handful of exact indexed reads is preferable to retaining every
    /// historical prescription row.
    static func prescriptionEvidence(
        for routineItemIDs: [UUID],
        using modelContext: ModelContext
    ) -> [UUID: MobilityRoutineItemEvidence] {
        var evidenceByItemID: [UUID: MobilityRoutineItemEvidence] = [:]
        evidenceByItemID.reserveCapacity(routineItemIDs.count)
        for routineItemID in Set(routineItemIDs) {
            if let evidence = prescriptionEvidence(for: routineItemID, using: modelContext) {
                evidenceByItemID[routineItemID] = evidence
            }
        }
        return evidenceByItemID
    }

    static func resultEvidence(
        for resultID: UUID,
        using modelContext: ModelContext
    ) -> MobilityResultEvidence? {
        try? resultEvidenceRequiringStore(for: resultID, using: modelContext)
    }

    static func resultEvidenceRequiringStore(
        for resultID: UUID,
        using modelContext: ModelContext
    ) throws -> MobilityResultEvidence? {
        var descriptor = FetchDescriptor<MobilityResultEvidence>(
            predicate: #Predicate { $0.resultID == resultID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    static func entryEvidence(
        for entryID: UUID,
        using modelContext: ModelContext
    ) -> MobilityEntryEvidence? {
        var descriptor = FetchDescriptor<MobilityEntryEvidence>(
            predicate: #Predicate { $0.entryID == entryID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    static func entryEvidence(
        for entryIDs: [UUID],
        using modelContext: ModelContext
    ) -> [UUID: MobilityEntryEvidence] {
        var evidenceByEntryID: [UUID: MobilityEntryEvidence] = [:]
        evidenceByEntryID.reserveCapacity(entryIDs.count)
        for entryID in Set(entryIDs) {
            if let evidence = entryEvidence(for: entryID, using: modelContext) {
                evidenceByEntryID[entryID] = evidence
            }
        }
        return evidenceByEntryID
    }

    /// All authored blocks for one routine, ordered for authoring/session
    /// materialization.
    static func blocks(
        forRoutineID routineID: UUID,
        using modelContext: ModelContext
    ) -> [MobilityRoutineBlock] {
        let descriptor = FetchDescriptor<MobilityRoutineBlock>(
            predicate: #Predicate { $0.routineID == routineID },
            sortBy: [
                SortDescriptor(\MobilityRoutineBlock.orderIndex),
                SortDescriptor(\MobilityRoutineBlock.blockKey)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    static func block(
        forKey blockKey: String,
        using modelContext: ModelContext
    ) -> MobilityRoutineBlock? {
        var descriptor = FetchDescriptor<MobilityRoutineBlock>(
            predicate: #Predicate { $0.blockKey == blockKey }
        )
        descriptor.fetchLimit = 1
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
        do {
            let existing: MobilityRoutineBlock?
            if let blockKey {
                var descriptor = FetchDescriptor<MobilityRoutineBlock>(
                    predicate: #Predicate { $0.blockKey == blockKey }
                )
                descriptor.fetchLimit = 1
                existing = try modelContext.fetch(descriptor).first
            } else {
                existing = nil
            }
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
        do {
            var blockDescriptor = FetchDescriptor<MobilityRoutineBlock>(
                predicate: #Predicate { $0.blockKey == blockKey }
            )
            blockDescriptor.fetchLimit = 1
            guard let block = try modelContext.fetch(blockDescriptor).first else { return false }
            modelContext.delete(block)
            // Membership is expressed on the item's evidence, not on the
            // block, so clear every member within the same all-or-nothing
            // read/mutation/save boundary.
            for routineItemID in routineItemIDs {
                var descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
                    predicate: #Predicate { $0.routineItemID == routineItemID }
                )
                descriptor.fetchLimit = 1
                if let evidence = try modelContext.fetch(descriptor).first,
                   evidence.blockKey == blockKey {
                    evidence.blockKey = nil
                }
            }
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
        var descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        descriptor.fetchLimit = 1
        do {
            let existing = try modelContext.fetch(descriptor).first
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
        var descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        descriptor.fetchLimit = 1
        do {
            let existing = try modelContext.fetch(descriptor).first
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
        var descriptor = FetchDescriptor<MobilityRoutineItemEvidence>(
            predicate: #Predicate { $0.routineItemID == routineItemID }
        )
        descriptor.fetchLimit = 1
        do {
            let existing = try modelContext.fetch(descriptor).first
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

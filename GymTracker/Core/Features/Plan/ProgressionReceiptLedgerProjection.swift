import Foundation

#if !GYMTRACKER_EXTENSION

/// A typed, read-only view of the progression receipt ledger. It does not
/// evaluate a rule, read live plan state, or infer a decision from `isResolved`.
/// In particular, a resolved legacy row with no outcome remains explicit.
struct ProgressionReceiptLedgerProjection {
    enum DecisionState: Equatable {
        case pending
        case accepted
        case acceptedWithModifiedValue
        case declined
        case outcomeNotRecorded
    }

    enum EvidenceAvailability: Equatable {
        case absent
        case decoded
        case unreadable
    }

    struct Proposal: Equatable {
        let load: Double?
        let loadUnit: WeightType?
        let trainingMax: Double?
        let estimatedOneRepMax: Double?
        let actualOneRepMax: Double?
        let stageID: String?
        let variationExerciseID: UUID?
        let repetitionOffset: Int
        let setCountOffset: Int
        let durationOffset: TimeInterval
        let distanceOffset: Double
        let restDurationOffset: Int
        let caloriesOffset: Double
        let waveIndex: Int
        let blockIndex: Int
        let isDeloading: Bool
    }

    struct Evidence: Equatable {
        let action: ProgressionAction?
        let actionAvailability: EvidenceAvailability
        let performance: ProgressionPerformance?
        let performanceAvailability: EvidenceAvailability
        let reasonKey: String?
        /// Legacy English provenance is retained as data only. Presentation
        /// must prefer `reasonKey` and never display this field directly.
        let legacyReason: String
    }

    struct Entry: Equatable, Identifiable {
        let id: UUID
        let createdAt: Date
        let resolvedAt: Date?
        let planRunID: UUID
        let workoutID: UUID
        let progressionKey: String
        let scopeOwnerKey: String
        let ruleID: UUID
        let ruleVersion: Int?
        let cadence: ProgressionCadence
        let scope: ProgressionScope
        let applicationMode: ProgressionApplicationMode
        let proposal: Proposal
        let evidence: Evidence
        let decision: DecisionState
        /// For an accepted receipt, the proposed load is the applied load by
        /// contract. A modified acceptance uses the explicitly recorded value;
        /// declined and legacy outcomes remain nil.
        let appliedLoad: Double?
        let explicitlyRecordedAppliedLoad: Double?

        var isResolved: Bool { decision != .pending }
    }

    /// A descriptive census of recorded recommendation outcomes. Legacy rows
    /// without a persisted outcome stay separate instead of being inferred as
    /// accepted or declined.
    struct DecisionSummary: Equatable, Identifiable {
        let decision: DecisionState
        let count: Int

        var id: String {
            switch decision {
            case .pending: "pending"
            case .accepted: "accepted"
            case .acceptedWithModifiedValue: "modified"
            case .declined: "declined"
            case .outcomeNotRecorded: "unrecorded"
            }
        }
    }

    static func decisionSummary(entries: [Entry]) -> [DecisionSummary] {
        let orderedDecisions: [DecisionState] = [
            .pending,
            .accepted,
            .acceptedWithModifiedValue,
            .declined,
            .outcomeNotRecorded
        ]

        return orderedDecisions.compactMap { decision in
            let count = entries.lazy.filter { $0.decision == decision }.count
            return count > 0 ? DecisionSummary(decision: decision, count: count) : nil
        }
    }

    static func project(
        records: [PlanProgressionRecommendationRecord],
        decoder: JSONDecoder = JSONDecoder()
    ) -> [Entry] {
        records
            .map { project(record: $0, decoder: decoder) }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func project(
        record: PlanProgressionRecommendationRecord,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Entry {
        let action: ProgressionAction?
        let actionAvailability: EvidenceAvailability
        if record.actionData.isEmpty {
            action = nil
            actionAvailability = .absent
        } else if let decoded = try? decoder.decode(ProgressionAction.self, from: record.actionData) {
            action = decoded
            actionAvailability = .decoded
        } else {
            action = nil
            actionAvailability = .unreadable
        }

        let performance: ProgressionPerformance?
        let performanceAvailability: EvidenceAvailability
        if let data = record.performanceData {
            if let decoded = try? decoder.decode(ProgressionPerformance.self, from: data) {
                performance = decoded
                performanceAvailability = .decoded
            } else {
                performance = nil
                performanceAvailability = .unreadable
            }
        } else {
            performance = nil
            performanceAvailability = .absent
        }

        let decision: DecisionState
        if !record.isResolved {
            decision = .pending
        } else {
            switch record.decisionOutcome {
            case .accepted: decision = .accepted
            case .acceptedWithModifiedValue: decision = .acceptedWithModifiedValue
            case .declined: decision = .declined
            case nil: decision = .outcomeNotRecorded
            }
        }

        let proposal = Proposal(
            load: record.proposedLoad,
            loadUnit: record.proposedLoadUnit,
            trainingMax: record.proposedTrainingMax,
            estimatedOneRepMax: record.proposedEstimatedOneRepMax,
            actualOneRepMax: record.proposedActualOneRepMax,
            stageID: record.proposedStageID,
            variationExerciseID: record.proposedVariationExerciseID,
            repetitionOffset: record.proposedRepetitionOffset,
            setCountOffset: record.proposedSetCountOffset,
            durationOffset: record.proposedDurationOffset,
            distanceOffset: record.proposedDistanceOffset,
            restDurationOffset: record.proposedRestDurationOffset,
            caloriesOffset: record.proposedCaloriesOffset,
            waveIndex: record.proposedWaveIndex,
            blockIndex: record.proposedBlockIndex,
            isDeloading: record.proposedIsDeloading
        )

        let appliedLoad: Double?
        switch decision {
        case .accepted:
            appliedLoad = proposal.load
        case .acceptedWithModifiedValue:
            appliedLoad = record.appliedLoad
        case .pending, .declined, .outcomeNotRecorded:
            appliedLoad = nil
        }

        return Entry(
            id: record.id,
            createdAt: record.createdAt,
            resolvedAt: record.resolvedAt,
            planRunID: record.planRunID,
            workoutID: record.workoutID,
            progressionKey: record.progressionKey,
            scopeOwnerKey: record.scopeOwnerKey,
            ruleID: record.ruleID,
            ruleVersion: record.ruleVersion,
            cadence: record.cadence,
            scope: record.scope,
            applicationMode: record.applicationMode,
            proposal: proposal,
            evidence: Evidence(
                action: action,
                actionAvailability: actionAvailability,
                performance: performance,
                performanceAvailability: performanceAvailability,
                reasonKey: record.reasonKey,
                legacyReason: record.reason
            ),
            decision: decision,
            appliedLoad: appliedLoad,
            explicitlyRecordedAppliedLoad: record.appliedLoad
        )
    }
}

#endif

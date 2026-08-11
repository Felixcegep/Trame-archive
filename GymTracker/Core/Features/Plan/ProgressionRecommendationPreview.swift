import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

enum ProgressionPreviewStateField: String, CaseIterable, Hashable {
    case load
    case repetitions
    case setCount
    case duration
    case distance
    case restDuration
    case calories
    case stage
    case variation
    case wave
    case block
    case trainingMax
    case estimatedOneRepMax
    case actualOneRepMax
    case deloading
    case velocityBaseline
}

enum ProgressionPreviewInsufficiency: Equatable, Hashable {
    case currentPrescriptionUnavailable
    case actionUnavailable
    case evidenceUnavailable
    case ruleVersionUnavailable
    case sourceOccurrenceUnavailable
    case futureOccurrencesUnavailable
    case futureBoundaryUnavailable(ProgressionCadence)
    case legacyOutcomeUnavailable
}

enum ProgressionPreviewDecisionState: Equatable, Hashable {
    case pending
    case accepted
    case acceptedWithModifiedValue
    case declined
    case resolvedOutcomeUnavailable
}

enum ProgressionPreviewReofferState: Equatable, Hashable {
    case eligible
    case alreadyResolved
    case suppressedUntilNewEvidence
    case eligibleAfterNewEvidence
    case outcomeUnavailable
}

enum ProgressionPreviewUnchangedArea: String, CaseIterable, Hashable {
    case performedWorkoutHistory
    case recommendationEvidence
    case ruleAndVersion
    case unrelatedProgressionScopes
    case futureOccurrencesUntilCadenceBoundary
    case declinedPrescription
}

struct ProgressionFutureOccurrencePreview: Equatable, Hashable {
    let progressID: UUID
    let plannedWorkoutID: UUID
    let plannedWorkoutName: String
    let weekIndex: Int
    let workoutIndex: Int
    let scheduledDate: Date?
    let effect: ProgressionCadence
}

/// A read-only contract for the fields a receipt/review surface needs. It
/// never writes the recommendation, progression state, plan, or performed
/// History and never re-runs the evaluator.
struct ProgressionRecommendationPreview: Equatable {
    let recommendationID: UUID
    let ruleID: UUID
    let ruleVersion: Int?
    let action: ProgressionAction?
    let cadence: ProgressionCadence
    let scope: ProgressionScope
    let reasonKey: String?
    let exactEvidence: ProgressionPerformance?
    let currentPrescription: ProgressionEvaluationState?
    let proposedPrescription: ProgressionEvaluationState
    let changedFields: [ProgressionPreviewStateField]
    let unchangedFields: [ProgressionPreviewStateField]
    let futureOccurrences: [ProgressionFutureOccurrencePreview]
    let unchangedAreas: [ProgressionPreviewUnchangedArea]
    let decisionState: ProgressionPreviewDecisionState
    let reofferState: ProgressionPreviewReofferState
    let insufficiencies: [ProgressionPreviewInsufficiency]

    var isActionable: Bool {
        decisionState == .pending && insufficiencies.isEmpty
    }
}

enum ProgressionRecommendationPreviewPolicy {
    static func make(
        for recommendation: PlanProgressionRecommendationRecord,
        currentPrescription: ProgressionEvaluationState?,
        in run: PlanRun? = nil,
        newEvidenceSinceDecline: Bool = false,
        decoder: JSONDecoder = JSONDecoder()
    ) -> ProgressionRecommendationPreview {
        var insufficiencies: [ProgressionPreviewInsufficiency] = []
        func appendUnique(_ value: ProgressionPreviewInsufficiency) {
            if !insufficiencies.contains(value) { insufficiencies.append(value) }
        }

        let action = try? recommendation.action(decoder: decoder)
        if action == nil { appendUnique(.actionUnavailable) }
        let evidence = recommendation.performance(decoder: decoder)
        if evidence == nil { appendUnique(.evidenceUnavailable) }
        if recommendation.ruleVersion == nil { appendUnique(.ruleVersionUnavailable) }
        if currentPrescription == nil { appendUnique(.currentPrescriptionUnavailable) }

        let proposed = proposedState(from: recommendation)
        let changed = fields(
            differingFrom: currentPrescription,
            to: proposed
        )
        let unchanged = fields(
            matching: currentPrescription,
            to: proposed
        )

        let decisionState = decisionState(for: recommendation)
        if recommendation.isResolved && recommendation.decisionOutcome == nil {
            appendUnique(.legacyOutcomeUnavailable)
        }
        let reoffer = reofferState(
            for: recommendation,
            newEvidenceSinceDecline: newEvidenceSinceDecline
        )

        let future = futureOccurrences(
            for: recommendation,
            in: run,
            appendInsufficiency: appendUnique
        )
        var unchangedAreas: [ProgressionPreviewUnchangedArea] = [
            .performedWorkoutHistory,
            .recommendationEvidence,
            .ruleAndVersion,
            .unrelatedProgressionScopes
        ]
        if recommendation.decisionOutcome == .declined {
            unchangedAreas.append(.declinedPrescription)
        }
        if recommendation.cadence != .immediately,
           recommendation.cadence != .nextSet,
           !unchangedAreas.contains(.futureOccurrencesUntilCadenceBoundary) {
            unchangedAreas.append(.futureOccurrencesUntilCadenceBoundary)
        }

        return ProgressionRecommendationPreview(
            recommendationID: recommendation.id,
            ruleID: recommendation.ruleID,
            ruleVersion: recommendation.ruleVersion,
            action: action,
            cadence: recommendation.cadence,
            scope: recommendation.scope,
            reasonKey: recommendation.reasonKey,
            exactEvidence: evidence,
            currentPrescription: currentPrescription,
            proposedPrescription: proposed,
            changedFields: changed,
            unchangedFields: unchanged,
            futureOccurrences: future,
            unchangedAreas: unchangedAreas,
            decisionState: decisionState,
            reofferState: reoffer,
            insufficiencies: insufficiencies
        )
    }

    private static func proposedState(
        from record: PlanProgressionRecommendationRecord
    ) -> ProgressionEvaluationState {
        ProgressionEvaluationState(
            currentLoad: record.proposedLoad,
            repetitionOffset: record.proposedRepetitionOffset,
            setCountOffset: record.proposedSetCountOffset,
            durationOffset: record.proposedDurationOffset,
            distanceOffset: record.proposedDistanceOffset,
            restDurationOffset: record.proposedRestDurationOffset,
            caloriesOffset: record.proposedCaloriesOffset,
            currentStageID: record.proposedStageID,
            currentVariationExerciseID: record.proposedVariationExerciseID,
            currentWaveIndex: record.proposedWaveIndex,
            currentBlockIndex: record.proposedBlockIndex,
            trainingMax: record.proposedTrainingMax,
            estimatedOneRepMax: record.proposedEstimatedOneRepMax,
            actualOneRepMax: record.proposedActualOneRepMax,
            isDeloading: record.proposedIsDeloading
        )
    }

    private static func decisionState(
        for record: PlanProgressionRecommendationRecord
    ) -> ProgressionPreviewDecisionState {
        guard record.isResolved else { return .pending }
        switch record.decisionOutcome {
        case .accepted: return .accepted
        case .acceptedWithModifiedValue: return .acceptedWithModifiedValue
        case .declined: return .declined
        case nil: return .resolvedOutcomeUnavailable
        }
    }

    private static func reofferState(
        for record: PlanProgressionRecommendationRecord,
        newEvidenceSinceDecline: Bool
    ) -> ProgressionPreviewReofferState {
        switch record.decisionOutcome {
        case .declined:
            return newEvidenceSinceDecline ? .eligibleAfterNewEvidence : .suppressedUntilNewEvidence
        case .accepted, .acceptedWithModifiedValue:
            return .alreadyResolved
        case nil:
            return record.isResolved ? .outcomeUnavailable : .eligible
        }
    }

    private static func fields(
        differingFrom current: ProgressionEvaluationState?,
        to proposed: ProgressionEvaluationState
    ) -> [ProgressionPreviewStateField] {
        guard let current else { return [] }
        return ProgressionPreviewStateField.allCases.filter {
            value(of: current, field: $0) != value(of: proposed, field: $0)
        }
    }

    private static func fields(
        matching current: ProgressionEvaluationState?,
        to proposed: ProgressionEvaluationState
    ) -> [ProgressionPreviewStateField] {
        guard let current else { return [] }
        return ProgressionPreviewStateField.allCases.filter {
            value(of: current, field: $0) == value(of: proposed, field: $0)
        }
    }

    private static func value(
        of state: ProgressionEvaluationState,
        field: ProgressionPreviewStateField
    ) -> String {
        switch field {
        case .load: return String(describing: state.currentLoad)
        case .repetitions: return String(state.repetitionOffset)
        case .setCount: return String(state.setCountOffset)
        case .duration: return String(state.durationOffset)
        case .distance: return String(state.distanceOffset)
        case .restDuration: return String(state.restDurationOffset)
        case .calories: return String(state.caloriesOffset)
        case .stage: return String(describing: state.currentStageID)
        case .variation: return String(describing: state.currentVariationExerciseID)
        case .wave: return String(state.currentWaveIndex)
        case .block: return String(state.currentBlockIndex)
        case .trainingMax: return String(describing: state.trainingMax)
        case .estimatedOneRepMax: return String(describing: state.estimatedOneRepMax)
        case .actualOneRepMax: return String(describing: state.actualOneRepMax)
        case .deloading: return String(state.isDeloading)
        case .velocityBaseline: return String(describing: state.velocityBaseline)
        }
    }

    private static func futureOccurrences(
        for recommendation: PlanProgressionRecommendationRecord,
        in run: PlanRun?,
        appendInsufficiency: (ProgressionPreviewInsufficiency) -> Void
    ) -> [ProgressionFutureOccurrencePreview] {
        guard recommendation.cadence != .immediately,
              recommendation.cadence != .nextSet else {
            return []
        }
        guard let run else {
            appendInsufficiency(.futureOccurrencesUnavailable)
            return []
        }
        guard let source = run.orderedWorkoutProgress.first(where: {
            $0.completedWorkout?.id == recommendation.workoutID
        }) else {
            appendInsufficiency(.sourceOccurrenceUnavailable)
            return []
        }

        if recommendation.cadence == .nextWave {
            appendInsufficiency(.futureBoundaryUnavailable(.nextWave))
            return []
        }
        if recommendation.cadence == .nextExerciseOccurrence,
           recommendation.progressionKey.isEmpty {
            appendInsufficiency(.futureOccurrencesUnavailable)
            return []
        }

        let future = run.orderedWorkoutProgress.filter { progress in
            guard progress.status != .completed, progress.status != .skipped else { return false }
            guard isAfter(progress, source) else { return false }
            switch recommendation.cadence {
            case .nextWorkout:
                return true
            case .nextExerciseOccurrence:
                return containsProgressionKey(
                    recommendation.progressionKey,
                    in: progress,
                    run: run
                )
            case .nextWeek:
                return progress.weekIndex > source.weekIndex
            case .nextBlock:
                return progress.weekIndex > source.weekIndex
            case .nextCycle:
                return true
            case .immediately, .nextSet, .nextWave:
                return false
            }
        }
        return future.map {
            ProgressionFutureOccurrencePreview(
                progressID: $0.id,
                plannedWorkoutID: $0.plannedWorkoutID,
                plannedWorkoutName: $0.plannedWorkoutName,
                weekIndex: $0.weekIndex,
                workoutIndex: $0.workoutIndex,
                scheduledDate: $0.scheduledDate,
                effect: recommendation.cadence
            )
        }
    }

    private static func containsProgressionKey(
        _ key: String,
        in progress: PlanWorkoutProgress,
        run: PlanRun
    ) -> Bool {
        run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .first(where: { $0.id == progress.plannedWorkoutID })?
            .orderedPlannedExercises
            .contains { $0.progressionKey == key } == true
    }

    private static func isAfter(_ lhs: PlanWorkoutProgress, _ rhs: PlanWorkoutProgress) -> Bool {
        lhs.weekIndex > rhs.weekIndex ||
            lhs.weekIndex == rhs.weekIndex && lhs.workoutIndex > rhs.workoutIndex
    }
}

#endif

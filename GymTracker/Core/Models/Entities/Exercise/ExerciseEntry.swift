//
//  ExerciseEntry.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import Combine
import SwiftData

@Model
final class ExerciseEntry{
    var orderIndex: Int = 0
    /// Snapshot-local membership in a contiguous superset. It must never reuse
    /// a template or planned-workout identifier.
    var supersetGroupID: UUID?
    /// Membership in a first-class execution block snapshot. This is separate
    /// from the legacy superset identifier and enables circuits, complexes,
    /// shared clocks, and scored work without changing progression ownership.
    var executionBlockID: UUID?
    var executionBlockComponentOrder: Int?
    var comment: String?
    var exercise: Exercise
    var usedMetric : UnitSystem
    var prescribedSets: Int?
    var prescribedRepRangeMinimum: Int?
    var prescribedRepRangeMaximum: Int?
    var prescribedRestSeconds: Int?
    var prescribedRPE: Double?
    var prescribedRIR: Int?
    var prescriptionNotes: String?
    var sourcePlannedExerciseID: UUID?
    /// Stable program exposure key copied from the planned exercise for
    /// same-session formula resolution and progression-state lookup.
    var progressionKey: String?
    var prescribedRole: ExerciseRole?
    var isPrescribedOptional: Bool?
    var prescribedSuggestedLoad: Double?
    var prescribedSuggestedLoadType: WeightType?
    var prescribedProgressionRule: ProgressionRule?
    var prescriptionDefinitionData: Data?
    var prescriptionRulesData: Data?
    /// Deferred `SetPrescriptionDefinition` records for generated back-off
    /// work. They are snapshot-local and never require a live plan lookup.
    var deferredBackOffDefinitionsData: Data?
    // Evidence captured at workout start so recommendations remain explainable
    // even when their source template or prior workout later changes.
    var recommendedDecision: DoubleProgressionDecision?
    var recommendedLoad: Float?
    var recommendedUnit: WeightType?
    var recommendationPriorLoad: Float?
    var recommendationRequiredSets: Int?
    var recommendationRepCeiling: Int?
    var recommendationCompletedSets: Int?
    var recommendationPriorWorkoutDate: Date?
    var accumulatedActiveDuration: TimeInterval = 0
    var activeDurationStartedAt: Date?
    // Captured from the exercise at entry-creation time so a completed set's
    // interpretation (name, tracking, per-side/per-unit logging) stays fixed
    // even if the library exercise is edited afterward.
    var nameSnapshot: String = ""
    /// The identity of the exercise this entry was created against. This is
    /// the historical source of truth for completed-history grouping and
    /// display — the `exercise` relationship is only a convenience link that
    /// may later be renamed, archived, or (once nullable) removed. `nil` only
    /// for rows persisted before this field existed; `historicalExerciseID`
    /// is the accessor every consumer should use instead of this raw field.
    var exerciseIDSnapshot: UUID?
    /// When an unstarted entry is substituted, preserve the original and
    /// selected identities instead of rewriting the historical meaning.
    var originalExerciseIDSnapshot: UUID?
    var originalExerciseNameSnapshot: String?
    var selectedSubstituteExerciseIDSnapshot: UUID?
    /// Legacy unstructured marker. Kept populated for backward compatibility
    /// with pre-v20 backups and existing tests, but it is no longer the
    /// decision of record — `substitutionReasonCode` is. Never displayed.
    var substitutionReason: String?
    /// The value both progression services read
    /// (`ActiveWorkoutProgressionService`, `PlanProgressionEvaluationService`).
    /// It is derived from `substitutionProgressionPolicy` and must only ever be
    /// written through `applySubstitutionDecision(_:)`, which keeps the two in
    /// lockstep. Writing it directly can desynchronize the persisted decision
    /// from its explanation.
    var substitutionSharesProgressionState: Bool = false
    // MARK: Decision-aware substitution evidence
    /// `SubstitutionReason` raw value.
    var substitutionReasonCode: String?
    var substitutionSuitabilityRaw: String?
    var substitutionComparabilityRaw: String?
    var substitutionProgressionPolicyRaw: String?
    var substitutionScopeRaw: String?
    var substitutionEvidenceConfidenceRaw: String?
    /// The rule-set version that produced the verdict, so a later rule change
    /// never retroactively reinterprets this decision.
    var substitutionEvaluationVersion: Int?
    /// Encoded `SubstitutionEvaluationSnapshot`.
    var substitutionEvaluationData: Data?
    /// When a progression variation resolves to a different exercise, retain
    /// both identities in the performed snapshot. The selected exercise is
    /// what the user performed; the source identity is what the program
    /// prescribed, and neither should be inferred from a later plan edit.
    var variationSourceExerciseIDSnapshot: UUID?
    var variationSelectedExerciseIDSnapshot: UUID?
    var trackingTypeSnapshot: TrackingType = TrackingType.weightAndReps
    var stimulusSnapshotRaw: String?
    var lateralitySnapshot: Laterality = Laterality.bilateral
    var repCountingStyleSnapshot: RepCountingStyle = RepCountingStyle.total
    var weightEntryStyleSnapshot: WeightEntryStyle = WeightEntryStyle.totalLoad
    var loadUnitCountSnapshot: Int = 1
    var workout: Workout?

    var stimulusSnapshot: TrainingStimulus? {
        get {
            stimulusSnapshotRaw.flatMap(TrainingStimulus.init(rawValue:))
        }
        set {
            stimulusSnapshotRaw = newValue?.rawValue
        }
    }
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exerciseEntry)
    var sets: [ExerciseSet]

    init(
        comment: String? = nil,
        exercise: Exercise,
        sets: [ExerciseSet] = [],
        orderIndex: Int = 0,
        usedMetric: UnitSystem,
        supersetGroupID: UUID? = nil
    ) {
        self.orderIndex = orderIndex
        self.supersetGroupID = supersetGroupID
        self.executionBlockID = nil
        self.executionBlockComponentOrder = nil
        self.comment = comment
        self.exercise = exercise
        self.sets = sets
        self.usedMetric = usedMetric
        self.nameSnapshot = exercise.name
        self.exerciseIDSnapshot = exercise.id
        self.trackingTypeSnapshot = exercise.trackingType
        self.lateralitySnapshot = exercise.laterality
        self.repCountingStyleSnapshot = exercise.repCountingStyle
        self.weightEntryStyleSnapshot = exercise.weightEntryStyle
        self.loadUnitCountSnapshot = exercise.loadUnitCount
        self.prescribedSets = nil
        self.prescribedRepRangeMinimum = nil
        self.prescribedRepRangeMaximum = nil
        self.prescribedRestSeconds = nil
        self.prescribedRPE = nil
        self.prescribedRIR = nil
        self.prescriptionNotes = nil
        self.sourcePlannedExerciseID = nil
        self.progressionKey = nil
        self.prescribedRole = nil
        self.isPrescribedOptional = nil
        self.prescribedSuggestedLoad = nil
        self.prescribedSuggestedLoadType = nil
        self.prescribedProgressionRule = nil
        self.prescriptionDefinitionData = nil
        self.prescriptionRulesData = nil
        self.deferredBackOffDefinitionsData = nil
        self.recommendedDecision = nil
        self.recommendedLoad = nil
        self.recommendedUnit = nil
        self.recommendationPriorLoad = nil
        self.recommendationRequiredSets = nil
        self.recommendationRepCeiling = nil
        self.recommendationCompletedSets = nil
        self.recommendationPriorWorkoutDate = nil
        self.accumulatedActiveDuration = 0
        self.activeDurationStartedAt = nil
        self.originalExerciseIDSnapshot = nil
        self.originalExerciseNameSnapshot = nil
        self.selectedSubstituteExerciseIDSnapshot = nil
        self.substitutionReason = nil
        self.substitutionSharesProgressionState = false
        self.substitutionReasonCode = nil
        self.substitutionSuitabilityRaw = nil
        self.substitutionComparabilityRaw = nil
        self.substitutionProgressionPolicyRaw = nil
        self.substitutionScopeRaw = nil
        self.substitutionEvidenceConfidenceRaw = nil
        self.substitutionEvaluationVersion = nil
        self.substitutionEvaluationData = nil
        self.variationSourceExerciseIDSnapshot = nil
        self.variationSelectedExerciseIDSnapshot = nil
        normalizeSetOrder()
    }

    convenience init(from: Exercise, orderIndex: Int = 0, usedMetric: UnitSystem) {
        self.init(exercise: from, orderIndex: orderIndex, usedMetric: usedMetric)
        addDefaultSets()
    }

    convenience init(
        from templateExercise: TemplateExercise,
        orderIndex: Int,
        usedMetric: UnitSystem,
        supersetGroupID: UUID? = nil
    ) {
        self.init(
            exercise: templateExercise.exercise,
            orderIndex: orderIndex,
            usedMetric: usedMetric,
            supersetGroupID: supersetGroupID
        )
        trackingTypeSnapshot = templateExercise.resolvedTrackingType
        stimulusSnapshot = templateExercise.resolvedStimulus
        prescribedSets = templateExercise.targetSets
        prescribedRepRangeMinimum = templateExercise.repRangeMinimum
        prescribedRepRangeMaximum = templateExercise.repRangeMaximum
        prescribedRestSeconds = templateExercise.restSeconds
        prescribedRPE = templateExercise.targetRPE
        prescribedRIR = templateExercise.targetRIR
        prescriptionNotes = templateExercise.notes
        prescribedProgressionRule = templateExercise.progressionRule
        addDefaultSets(count: templateExercise.targetSets)
    }

    convenience init(
        from plannedExercise: PlannedExercise,
        exercise resolvedExercise: Exercise? = nil,
        orderIndex: Int,
        usedMetric: UnitSystem,
        supersetGroupID: UUID? = nil
    ) {
        self.init(
            exercise: resolvedExercise ?? plannedExercise.exercise,
            orderIndex: orderIndex,
            usedMetric: usedMetric,
            supersetGroupID: supersetGroupID
        )
        trackingTypeSnapshot = plannedExercise.resolvedTrackingType
        stimulusSnapshot = plannedExercise.resolvedStimulus
        prescribedSets = plannedExercise.targetSets
        prescribedRepRangeMinimum = plannedExercise.repRangeMinimum
        prescribedRepRangeMaximum = plannedExercise.repRangeMaximum
        prescribedRestSeconds = plannedExercise.restSeconds
        prescribedRPE = plannedExercise.targetRPE
        prescribedRIR = plannedExercise.targetRIR
        prescriptionNotes = plannedExercise.notes
        sourcePlannedExerciseID = plannedExercise.id
        progressionKey = plannedExercise.progressionKey
        prescribedRole = plannedExercise.role
        isPrescribedOptional = plannedExercise.isOptional
        prescribedSuggestedLoad = plannedExercise.suggestedLoad
        prescribedSuggestedLoadType = plannedExercise.suggestedLoadType
        prescribedProgressionRule = plannedExercise.progressionRule
        prescriptionRulesData = plannedExercise.progressionRulesData

        let plannedSets = plannedExercise.orderedPlannedSets
        if let plannedSetData = plannedSets.first?.definitionData {
            prescriptionDefinitionData = plannedSetData
        } else {
            prescriptionDefinitionData = nil
        }

        if plannedSets.isEmpty {
            let reps = Float(plannedExercise.repRangeMaximum)
            let weight = Float(plannedExercise.suggestedLoad ?? 0)
            for i in 0..<plannedExercise.targetSets {
                let setObj = createEmptySet(orderIndex: i)
                if exercise.trackingType.usesReps { setObj.repetitions = reps }
                if exercise.trackingType.usesWeight {
                    setObj.weight = weight
                    setObj.weightType = plannedExercise.suggestedLoadType
                        ?? (usedMetric == .metric ? .kg : .lbs)
                }
                sets.append(setObj)
            }
            return
        }

        for plannedSet in plannedSets {
            let setObj = createEmptySet(orderIndex: plannedSet.orderIndex)
            setObj.setType = plannedSet.setType
            setObj.prescribedSetType = plannedSet.setType
            setObj.prescribedRepetitions = plannedSet.repetitions
            setObj.prescribedRepRangeMinimum = plannedSet.repRangeMinimum
            setObj.prescribedRepRangeMaximum = plannedSet.repRangeMaximum
            setObj.prescribedSuggestedLoad = plannedSet.suggestedLoad
            setObj.prescribedSuggestedLoadType = plannedSet.suggestedLoadType
            setObj.prescribedRestSeconds = plannedSet.restSeconds
            setObj.prescribedRPE = plannedSet.targetRPE
            setObj.prescribedRIR = plannedSet.targetRIR
            setObj.prescribedTempo = plannedSet.tempo
            setObj.prescribedProgressionEligible = plannedSet.progressionEligible
            setObj.isPrescribedOptional = plannedSet.isOptional
            setObj.prescriptionNotes = plannedSet.notes
            setObj.prescriptionDefinitionData = plannedSet.definitionData
            if exercise.trackingType.usesReps {
                setObj.repetitions = Float(plannedSet.repetitions ?? plannedSet.repRangeMaximum ?? plannedExercise.repRangeMaximum)
            }
            if exercise.trackingType.usesWeight {
                setObj.weight = Float(plannedSet.suggestedLoad ?? plannedExercise.suggestedLoad ?? 0)
                setObj.weightType = plannedSet.suggestedLoadType
                    ?? plannedExercise.suggestedLoadType
                    ?? (usedMetric == .metric ? .kg : .lbs)
            }
            sets.append(setObj)
        }
    }

    func addEmptySet() {
        sets.append(createEmptySet(orderIndex: nextSetOrderIndex))
    }

    func addDefaultSets(count: Int = 3) {
        for _ in 0..<count {
            addEmptySet()
        }
    }

    /// Replaces an unstarted entry's library definition while retaining its
    /// prescription and position in the active workout. Callers must delete
    /// existing sets before rebuilding them for the replacement tracking type.
    func updateExerciseSnapshot(from exercise: Exercise) {
        self.exercise = exercise
        nameSnapshot = exercise.name
        exerciseIDSnapshot = exercise.id
        trackingTypeSnapshot = exercise.trackingType
        lateralitySnapshot = exercise.laterality
        repCountingStyleSnapshot = exercise.repCountingStyle
        weightEntryStyleSnapshot = exercise.weightEntryStyle
        loadUnitCountSnapshot = exercise.loadUnitCount
        recommendedDecision = nil
        recommendedLoad = nil
        recommendedUnit = nil
        recommendationPriorLoad = nil
        recommendationRequiredSets = nil
        recommendationRepCeiling = nil
        recommendationCompletedSets = nil
        recommendationPriorWorkoutDate = nil
    }

    // MARK: - Decision-aware substitution

    var substitutionReasonValue: SubstitutionReason? {
        substitutionReasonCode.flatMap(SubstitutionReason.init(rawValue:))
    }

    var substitutionSuitability: SubstitutionSuitability? {
        substitutionSuitabilityRaw.flatMap(SubstitutionSuitability.init(rawValue:))
    }

    var substitutionComparability: SubstitutionComparability? {
        substitutionComparabilityRaw.flatMap(SubstitutionComparability.init(rawValue:))
    }

    /// Legacy substituted rows (persisted before this field existed) read as
    /// `separate`, which matches the `false` Boolean they already carry.
    var substitutionProgressionPolicy: ProgressionTransferPolicy? {
        guard let raw = substitutionProgressionPolicyRaw else {
            return isSubstituted ? .separate : nil
        }
        return ProgressionTransferPolicy(rawValue: raw)
    }

    var substitutionScope: SubstitutionScope? {
        substitutionScopeRaw.flatMap(SubstitutionScope.init(rawValue:))
    }

    var substitutionEvidenceConfidence: SubstitutionEvidenceConfidence? {
        substitutionEvidenceConfidenceRaw.flatMap(SubstitutionEvidenceConfidence.init(rawValue:))
    }

    var substitutionEvaluation: SubstitutionEvaluationSnapshot? {
        SubstitutionEvaluationSnapshot.decoded(from: substitutionEvaluationData)
    }

    var isSubstituted: Bool { originalExerciseIDSnapshot != nil }

    /// The **only** supported way to record a substitution decision.
    ///
    /// It exists so the persisted Boolean the progression services read can
    /// never drift from the policy that explains it. The invariant it
    /// guarantees, in all three directions:
    ///
    /// - `.continueShared`  → `substitutionSharesProgressionState == true`
    /// - `.separate`        → `false`
    /// - `.undetermined`    → `false` (unknown never silently becomes yes)
    ///
    /// `SubstitutionDecision`'s own initializer has already downgraded a
    /// `.continueShared` policy that the evaluation cannot support, so a
    /// non-`direct` comparability can never reach the `true` branch here.
    func applySubstitutionDecision(_ decision: SubstitutionDecision) {
        substitutionReasonCode = decision.reason.rawValue
        substitutionScopeRaw = decision.scope.rawValue
        substitutionProgressionPolicyRaw = decision.progressionPolicy.rawValue
        substitutionSharesProgressionState = decision.progressionPolicy.sharesProgressionState
        substitutionSuitabilityRaw = decision.evaluation.suitability.rawValue
        substitutionComparabilityRaw = decision.evaluation.comparability.rawValue
        substitutionEvidenceConfidenceRaw = decision.evaluation.confidence.rawValue
        substitutionEvaluationVersion = decision.evaluation.version
        substitutionEvaluationData = decision.evaluation.encoded()
        // Retained so a pre-v20 reader still sees a non-nil marker. Stable and
        // non-localized on purpose: it is provenance, not display text.
        substitutionReason = "structured:\(decision.reason.rawValue)"
    }

    func copyLastSet() {
        guard let lastSet = orderedSets.last else {
            addEmptySet()
            return
        }

        let copiedSet = lastSet.copy()
        copiedSet.orderIndex = nextSetOrderIndex
        sets.append(copiedSet)
    }

    /// The stable identity for completed-history grouping, analytics, and
    /// records. Falls back to the live relationship only for rows persisted
    /// before `exerciseIDSnapshot` existed.
    var historicalExerciseID: UUID { exerciseIDSnapshot ?? exercise.id }

    /// The name to show for this entry once a workout is completed. Falls
    /// back to the live relationship's name only if the snapshot was never
    /// captured (legacy rows created before `nameSnapshot` existed).
    var displayName: String { nameSnapshot.isEmpty ? exercise.name : nameSnapshot }

    var loggingSemanticsSnapshot: LoggingSemantics {
        LoggingSemantics(
            laterality: lateralitySnapshot,
            repCountingStyle: repCountingStyleSnapshot,
            weightEntryStyle: weightEntryStyleSnapshot,
            loadUnitCount: loadUnitCountSnapshot
        )
    }

    var orderedSets: [ExerciseSet] {
        sets.sorted(by: { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.id.uuidString < rhs.id.uuidString
        })
    }

    func normalizeSetOrder() {
        for (index, set) in orderedSets.enumerated() {
            set.orderIndex = index
            set.normalizeSegmentOrder()
        }
    }

    func activeDuration(at date: Date = .now) -> TimeInterval {
        accumulatedActiveDuration + max(0, activeDurationStartedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    func startActiveDuration(at date: Date = .now) {
        guard activeDurationStartedAt == nil else { return }
        activeDurationStartedAt = date
    }

    func stopActiveDuration(at date: Date = .now) {
        guard let startedAt = activeDurationStartedAt else { return }
        accumulatedActiveDuration += max(0, date.timeIntervalSince(startedAt))
        activeDurationStartedAt = nil
    }

    private var nextSetOrderIndex: Int {
        (orderedSets.last?.orderIndex ?? -1) + 1
    }

    private func createEmptySet(orderIndex: Int) -> ExerciseSet {
        switch trackingTypeSnapshot {
        case .weightAndReps, .weightedBodyweight, .assistedBodyweight:
            return ExerciseSet(repetitions: 0, weight: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .repsOnly:
            return ExerciseSet(repetitions: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .duration:
            return ExerciseSet(duration: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .durationAndDistance:
            return ExerciseSet(duration: 0, distance: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .calories:
            return ExerciseSet(calories: 0, orderIndex: orderIndex, usedMetric: usedMetric)
        }
    }

}

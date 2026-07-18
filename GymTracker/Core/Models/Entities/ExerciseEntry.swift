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
    /// When an unstarted entry is substituted, preserve the original and
    /// selected identities instead of rewriting the historical meaning.
    var originalExerciseIDSnapshot: UUID?
    var originalExerciseNameSnapshot: String?
    var selectedSubstituteExerciseIDSnapshot: UUID?
    var substitutionReason: String?
    var substitutionSharesProgressionState: Bool = false
    var trackingTypeSnapshot: TrackingType = TrackingType.weightAndReps
    var lateralitySnapshot: Laterality = Laterality.bilateral
    var repCountingStyleSnapshot: RepCountingStyle = RepCountingStyle.total
    var weightEntryStyleSnapshot: WeightEntryStyle = WeightEntryStyle.totalLoad
    var loadUnitCountSnapshot: Int = 1
    var workout: Workout?
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
        self.comment = comment
        self.exercise = exercise
        self.sets = sets
        self.usedMetric = usedMetric
        self.nameSnapshot = exercise.name
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
        orderIndex: Int,
        usedMetric: UnitSystem,
        supersetGroupID: UUID? = nil
    ) {
        self.init(
            exercise: plannedExercise.exercise,
            orderIndex: orderIndex,
            usedMetric: usedMetric,
            supersetGroupID: supersetGroupID
        )
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

    func copyLastSet() {
        guard let lastSet = orderedSets.last else {
            addEmptySet()
            return
        }

        let copiedSet = lastSet.copy()
        copiedSet.orderIndex = nextSetOrderIndex
        sets.append(copiedSet)
    }

    var loggingSemanticsSnapshot: LoggingSemantics {
        LoggingSemantics(
            laterality: lateralitySnapshot,
            repCountingStyle: repCountingStyleSnapshot,
            weightEntryStyle: weightEntryStyleSnapshot,
            loadUnitCount: loadUnitCountSnapshot
        )
    }

    var orderedSets: [ExerciseSet] {
        sets.sorted { lhs, rhs in
            lhs.orderIndex == rhs.orderIndex
                ? lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                : lhs.orderIndex < rhs.orderIndex
        }
    }

    func normalizeSetOrder() {
        for (index, set) in orderedSets.enumerated() {
            set.orderIndex = index
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

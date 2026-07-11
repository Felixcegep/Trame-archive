//
//  ExerciceEntry.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import Combine
import SwiftData

@Model
final class ExerciceEntry{
    var orderIndex: Int = 0
    var Comment: String?
    var exercice: ExerciceTemplate
    var usedMetric : UnitSystem
    var prescribedSets: Int?
    var prescribedRepRangeMinimum: Int?
    var prescribedRepRangeMaximum: Int?
    var prescribedRestSeconds: Int?
    var prescribedRPE: Double?
    var prescribedRIR: Int?
    var prescriptionNotes: String?
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet]

    init(
        Comment: String? = nil,
        exercice: ExerciceTemplate,
        sets: [ExerciseSet] = [],
        orderIndex: Int = 0,
        usedMetric: UnitSystem
    ) {
        self.orderIndex = orderIndex
        self.Comment = Comment
        self.exercice = exercice
        self.sets = sets
        self.usedMetric = usedMetric
        self.prescribedSets = nil
        self.prescribedRepRangeMinimum = nil
        self.prescribedRepRangeMaximum = nil
        self.prescribedRestSeconds = nil
        self.prescribedRPE = nil
        self.prescribedRIR = nil
        self.prescriptionNotes = nil
        normalizeSetOrder()
    }

    convenience init(from: ExerciceTemplate, orderIndex: Int = 0, usedMetric: UnitSystem) {
        self.init(exercice: from, orderIndex: orderIndex, usedMetric: usedMetric)
        addDefaultSets()
    }

    convenience init(from templateExercise: TemplateExercise, orderIndex: Int, usedMetric: UnitSystem) {
        self.init(exercice: templateExercise.exercise, orderIndex: orderIndex, usedMetric: usedMetric)
        prescribedSets = templateExercise.targetSets
        prescribedRepRangeMinimum = templateExercise.repRangeMinimum
        prescribedRepRangeMaximum = templateExercise.repRangeMaximum
        prescribedRestSeconds = templateExercise.restSeconds
        prescribedRPE = templateExercise.targetRPE
        prescribedRIR = templateExercise.targetRIR
        prescriptionNotes = templateExercise.notes
        addDefaultSets(count: templateExercise.targetSets)
    }

    func addEmptySet() {
        sets.append(createEmptySet(orderIndex: nextSetOrderIndex))
    }

    func addDefaultSets(count: Int = 3) {
        for _ in 0..<count {
            addEmptySet()
        }
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

    private var nextSetOrderIndex: Int {
        (orderedSets.last?.orderIndex ?? -1) + 1
    }

    private func createEmptySet(orderIndex: Int) -> ExerciseSet {
        switch exercice.trackingType {
        case .weightAndReps, .weightedBodyweight, .assistedBodyweight:
            return ExerciseSet(repetition: 0, weight: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .repsOnly:
            return ExerciseSet(repetition: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .duration:
            return ExerciseSet(duration: 0, orderIndex: orderIndex, usedMetric: usedMetric)

        case .durationAndDistance:
            return ExerciseSet(duration: 0, distance: 0, orderIndex: orderIndex, usedMetric: usedMetric)
        }
    }

}

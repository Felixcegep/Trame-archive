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

    init(Comment: String? = nil, exercice: ExerciceTemplate, sets: [ExerciseSet] = [], usedMetric: UnitSystem) {
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
    }

    convenience init(from: ExerciceTemplate,usedMetric: UnitSystem) {
        self.init(exercice: from,usedMetric: usedMetric)
        addDefaultSets()
        
    }

    convenience init(from templateExercise: TemplateExercise, usedMetric: UnitSystem) {
        self.init(exercice: templateExercise.exercise, usedMetric: usedMetric)
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
        sets.append(createEmptySet())
    }

    func addDefaultSets(count: Int = 3) {
        for _ in 0..<count {
            addEmptySet()
        }
    }

    func copyLastSet() {
        guard let lastSet = sets.last else {
            addEmptySet()
            return
        }

        sets.append(lastSet.copy())
    }

    private func createEmptySet() -> ExerciseSet {
        switch exercice.trackingType {
        case .weightAndReps, .weightedBodyweight, .assistedBodyweight:
            return ExerciseSet(repetition: 0, weight: 0,usedMetric: usedMetric)

        case .repsOnly:
            return ExerciseSet(repetition: 0,usedMetric: usedMetric)

        case .duration:
            return ExerciseSet(duration: 0,usedMetric: usedMetric)

        case .durationAndDistance:
            return ExerciseSet(duration: 0, distance: 0,usedMetric: usedMetric)
        }
    }

}

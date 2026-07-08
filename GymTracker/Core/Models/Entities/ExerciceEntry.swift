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
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet]

    init(Comment: String? = nil, exercice: ExerciceTemplate, sets: [ExerciseSet] = [], usedMetric: UnitSystem) {
        self.Comment = Comment
        self.exercice = exercice
        self.sets = sets
        self.usedMetric = usedMetric
    }

    convenience init(from: ExerciceTemplate,usedMetric: UnitSystem) {
        self.init(exercice: from,usedMetric: usedMetric)
        addDefaultSets()
        
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

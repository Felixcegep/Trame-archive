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

    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet]

    init(Comment: String? = nil, exercice: ExerciceTemplate, sets: [ExerciseSet] = []) {
        self.Comment = Comment
        self.exercice = exercice
        self.sets = sets
    }

    convenience init(from: ExerciceTemplate) {
        self.init(exercice: from)
    }

    func addEmptySet() {
        sets.append(createEmptySet())
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
            return ExerciseSet(repetition: 0, weight: 0)

        case .repsOnly:
            return ExerciseSet(repetition: 0)

        case .duration:
            return ExerciseSet(duration: 0)

        case .durationAndDistance:
            return ExerciseSet(duration: 0, distance: 0)
        }
    }

}

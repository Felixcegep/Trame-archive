//
//  ExerciseSeedData+Legs.swift
//  GymTracker
//

import Foundation

extension ExerciseSeedData {
    static func legsTemplates() -> [Exercise] {
        [
            Exercise(
                name: "Goblet Stiletto Squat",
                primaryMuscles: [.quadriceps],
                secondaryMuscles: [.gluteMaximus],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                forceType: .push,
                mechanics: .compound,
                difficulty: .beginner,
                tags: ["front-loaded", "heels-elevated"]
            ),
            Exercise(
                name: "Bulgarian Split Squat",
                primaryMuscles: [.quadriceps, .gluteMaximus],
                secondaryMuscles: [.hamstrings],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                forceType: .push,
                mechanics: .compound,
                stance: .split,
                rangeOfMotion: .full,
                difficulty: .intermediate,
                tags: ["unilateral"],
                laterality: .unilateral,
                repCountingStyle: .perSide,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "Deadlift",
                primaryMuscles: [.erectorSpinae, .gluteMaximus, .hamstrings],
                secondaryMuscles: [.trapezius, .forearms],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .mixed,
                stance: .standing,
                rangeOfMotion: .full,
                difficulty: .advanced
            ),
            Exercise(
                name: "Back Squat",
                primaryMuscles: [.quadriceps, .gluteMaximus],
                secondaryMuscles: [.hamstrings, .erectorSpinae],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                forceType: .push,
                mechanics: .compound,
                gripStyle: .pronated,
                stance: .standing,
                rangeOfMotion: .full,
                difficulty: .intermediate
            ),
            Exercise(
                name: "Leg Press",
                primaryMuscles: [.quadriceps],
                secondaryMuscles: [.gluteMaximus, .hamstrings],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .squat,
                forceType: .push,
                mechanics: .compound,
                difficulty: .beginner,
                isPlateLoaded: true
            ),
            Exercise(
                name: "Romanian Deadlift",
                primaryMuscles: [.hamstrings, .gluteMaximus],
                secondaryMuscles: [.erectorSpinae],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .pronated,
                stance: .standing,
                rangeOfMotion: .full,
                variationFamilyID: "romanian-deadlift",
                difficulty: .intermediate
            ),
            Exercise(
                name: "B-Stance RDL",
                primaryMuscles: [.hamstrings, .gluteMaximus],
                secondaryMuscles: [.erectorSpinae],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                forceType: .pull,
                mechanics: .compound,
                stance: .staggered,
                rangeOfMotion: .full,
                variationFamilyID: "romanian-deadlift",
                difficulty: .intermediate,
                tags: ["unilateral", "kickstand"],
                laterality: .unilateral,
                repCountingStyle: .perSide,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "45-Degree Back Extension",
                primaryMuscles: [.erectorSpinae, .gluteMaximus],
                secondaryMuscles: [.hamstrings],
                equipmentType: .other,
                resistanceType: .bodyweight,
                movementPattern: .hinge,
                forceType: .pull,
                mechanics: .compound,
                difficulty: .beginner,
                tags: ["rehabilitation", "high-rep"]
            ),
            Exercise(
                name: "Leg Extension",
                primaryMuscles: [.quadriceps],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .other,
                forceType: .push,
                mechanics: .isolation,
                stance: .seated,
                rangeOfMotion: .full,
                variationFamilyID: "leg-extension",
                difficulty: .beginner,
                tags: ["leg-extension", "machine", "quadriceps", "isolation"]
            ),
            Exercise(
                name: "Leg Curl",
                primaryMuscles: [.hamstrings],
                equipmentType: .machine,
                resistanceType: .machine,
                forceType: .pull,
                mechanics: .isolation,
                difficulty: .beginner
            ),
            Exercise(
                name: "Standing Calf Raise",
                primaryMuscles: [.calves],
                equipmentType: .machine,
                resistanceType: .externalWeight,
                forceType: .push,
                mechanics: .isolation,
                difficulty: .beginner
            ),
            Exercise(
                name: "Seated Calf Raise",
                primaryMuscles: [.calves],
                equipmentType: .machine,
                resistanceType: .machine,
                forceType: .push,
                mechanics: .isolation,
                stance: .seated,
                rangeOfMotion: .full,
                variationFamilyID: "calf-raise",
                difficulty: .beginner
            )
        ]
    }
}

//
//  ExerciseSeedData+Pull.swift
//  GymTracker
//

import Foundation

extension ExerciseSeedData {
    static func pullTemplates() -> [Exercise] {
        [
            Exercise(
                name: "Barbell Row",
                primaryMuscles: [.latissimusDorsi, .rhomboids],
                secondaryMuscles: [.rearDeltoid, .bicep, .forearms],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .pronated,
                stance: .standing,
                rangeOfMotion: .full,
                variationFamilyID: "row",
                difficulty: .intermediate
            ),
            Exercise(
                name: "Face Pull",
                primaryMuscles: [.rearDeltoid],
                secondaryMuscles: [.trapezius, .rhomboids],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .horizontalPull,
                forceType: .pull,
                mechanics: .isolation,
                difficulty: .beginner,
                tags: ["shoulder-health"]
            ),
            Exercise(
                name: "Pull Up",
                primaryMuscles: [.latissimusDorsi],
                secondaryMuscles: [.bicep, .rhomboids],
                trackingType: .weightedBodyweight,
                equipmentType: .bodyweight,
                resistanceType: .weightedBodyweight,
                movementPattern: .verticalPull,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .pronated,
                rangeOfMotion: .full,
                variationFamilyID: "pull-up",
                difficulty: .intermediate
            ),
            Exercise(
                name: "Assisted Pull Up",
                primaryMuscles: [.latissimusDorsi],
                secondaryMuscles: [.bicep, .rhomboids],
                trackingType: .assistedBodyweight,
                equipmentType: .machine,
                resistanceType: .assistedBodyweight,
                movementPattern: .verticalPull,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .pronated,
                rangeOfMotion: .full,
                variationFamilyID: "pull-up",
                difficulty: .beginner
            ),
            Exercise(
                name: "Lat Pulldown",
                primaryMuscles: [.latissimusDorsi],
                secondaryMuscles: [.bicep, .teresMajor],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .verticalPull,
                forceType: .pull,
                mechanics: .compound,
                difficulty: .beginner
            ),
            Exercise(
                name: "Seated Cable Row",
                primaryMuscles: [.rhomboids, .latissimusDorsi],
                secondaryMuscles: [.bicep, .rearDeltoid],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .horizontalPull,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .neutral,
                stance: .seated,
                rangeOfMotion: .full,
                variationFamilyID: "row",
                difficulty: .beginner
            ),
            Exercise(
                name: "Barbell Curl",
                primaryMuscles: [.bicep],
                secondaryMuscles: [.brachialis, .brachioradialis],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                forceType: .pull,
                mechanics: .isolation,
                gripStyle: .supinated,
                stance: .standing,
                rangeOfMotion: .full,
                variationFamilyID: "curl",
                difficulty: .beginner
            ),
            Exercise(
                name: "Hammer Curl",
                primaryMuscles: [.brachialis],
                secondaryMuscles: [.bicep, .brachioradialis],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                forceType: .pull,
                mechanics: .isolation,
                gripStyle: .neutral,
                stance: .standing,
                rangeOfMotion: .full,
                variationFamilyID: "curl",
                difficulty: .beginner,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "Rear Delt Fly",
                primaryMuscles: [.rearDeltoid],
                secondaryMuscles: [.rhomboids],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                forceType: .pull,
                mechanics: .isolation,
                difficulty: .beginner,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "Chest-Supported Row",
                primaryMuscles: [.rhomboids, .latissimusDorsi],
                secondaryMuscles: [.rearDeltoid, .bicep],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
                forceType: .pull,
                mechanics: .compound,
                gripStyle: .neutral,
                stance: .prone,
                rangeOfMotion: .full,
                variationFamilyID: "row",
                difficulty: .beginner,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            )
        ]
    }
}

//
//  ExerciseSeedData+Push.swift
//  GymTracker
//

import Foundation

extension ExerciseSeedData {
    static func pushTemplates() -> [Exercise] {
        [
            Exercise(
                name: "Bench Press",
                primaryMuscles: [.middleChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                trackingType: .weightAndReps,
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                forceType: .push,
                mechanics: .compound,
                gripStyle: .pronated,
                stance: .supine,
                rangeOfMotion: .full,
                setupAngleDegrees: 0,
                variationFamilyID: "bench-press",
                difficulty: .intermediate
            ),
            Exercise(
                name: "Incline Bench Press",
                primaryMuscles: [.upperChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                forceType: .push,
                mechanics: .compound,
                gripStyle: .pronated,
                stance: .supine,
                rangeOfMotion: .full,
                setupAngleDegrees: 30,
                variationFamilyID: "bench-press",
                difficulty: .intermediate
            ),
            Exercise(
                name: "Overhead Press",
                primaryMuscles: [.frontDeltoid, .lateralDeltoid],
                secondaryMuscles: [.tricepLongHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                forceType: .push,
                mechanics: .compound,
                gripStyle: .pronated,
                stance: .standing,
                rangeOfMotion: .full,
                difficulty: .intermediate
            ),
            Exercise(
                name: "Dumbbell Incline Press",
                primaryMuscles: [.upperChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                forceType: .push,
                mechanics: .compound,
                stance: .supine,
                rangeOfMotion: .full,
                setupAngleDegrees: 30,
                variationFamilyID: "bench-press",
                difficulty: .intermediate,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "Triceps Pushdown",
                primaryMuscles: [.tricepLateralHead, .tricepMedialHead],
                secondaryMuscles: [.tricepLongHead],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .elbowExtension,
                forceType: .push,
                mechanics: .isolation,
                difficulty: .beginner
            ),
            Exercise(
                name: "Lateral Raise",
                primaryMuscles: [.lateralDeltoid],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .shoulderAbduction,
                forceType: .push,
                mechanics: .isolation,
                difficulty: .beginner,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "Dumbbell Bench Press",
                primaryMuscles: [.middleChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                forceType: .push,
                mechanics: .compound,
                stance: .supine,
                rangeOfMotion: .full,
                setupAngleDegrees: 0,
                variationFamilyID: "bench-press",
                difficulty: .beginner,
                weightEntryStyle: .perLoadUnit,
                loadUnitCount: 2
            ),
            Exercise(
                name: "Military Press",
                primaryMuscles: [.frontDeltoid, .lateralDeltoid],
                secondaryMuscles: [.tricepLongHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                forceType: .push,
                mechanics: .compound,
                difficulty: .intermediate
            )
        ]
    }
}

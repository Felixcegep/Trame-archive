//
//  ExerciseSeedData.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum ExerciseSeedData {
    static func templates() -> [ExerciceTemplate] {
        [
            ExerciceTemplate(
                name: "Bench Press",
                PrimaryMuscle: [.middleChest],
                SecondaryMuscle: [.frontDeltoid, .tricepLateralHead],
                trackingType: .weightAndReps,
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Incline Bench Press",
                PrimaryMuscle: [.upperChest],
                SecondaryMuscle: [.frontDeltoid, .tricepLateralHead],
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Deadlift",
                PrimaryMuscle: [.erectorSpinae, .gluteMaximus, .hamstrings],
                SecondaryMuscle: [.trapezius, .forearms],
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .advanced
            ),

            ExerciceTemplate(
                name: "Back Squat",
                PrimaryMuscle: [.quadriceps, .gluteMaximus],
                SecondaryMuscle: [.hamstrings, .erectorSpinae],
                resistanceType: .externalWeight,
                movementPattern: .squat,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Overhead Press",
                PrimaryMuscle: [.frontDeltoid, .lateralDeltoid],
                SecondaryMuscle: [.tricepLongHead],
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Barbell Row",
                PrimaryMuscle: [.latissimusDorsi, .rhomboids],
                SecondaryMuscle: [.rearDeltoid, .bicep, .forearms],
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Pull Up",
                PrimaryMuscle: [.latissimusDorsi],
                SecondaryMuscle: [.bicep, .rhomboids],
                trackingType: .weightedBodyweight,
                equipmentType: .bodyweight,
                resistanceType: .weightedBodyweight,
                movementPattern: .verticalPull,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Assisted Pull Up",
                PrimaryMuscle: [.latissimusDorsi],
                SecondaryMuscle: [.bicep, .rhomboids],
                trackingType: .assistedBodyweight,
                equipmentType: .machine,
                resistanceType: .assistedBodyweight,
                movementPattern: .verticalPull,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Lat Pulldown",
                PrimaryMuscle: [.latissimusDorsi],
                SecondaryMuscle: [.bicep, .teresMajor],
                resistanceType: .machine,
                movementPattern: .verticalPull,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Seated Cable Row",
                PrimaryMuscle: [.rhomboids, .latissimusDorsi],
                SecondaryMuscle: [.bicep, .rearDeltoid],
                resistanceType: .machine,
                movementPattern: .horizontalPull,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Barbell Curl",
                PrimaryMuscle: [.bicep],
                SecondaryMuscle: [.brachialis, .brachioradialis],
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Hammer Curl",
                PrimaryMuscle: [.brachialis],
                SecondaryMuscle: [.bicep, .brachioradialis],
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Triceps Pushdown",
                PrimaryMuscle: [.tricepLateralHead, .tricepMedialHead],
                SecondaryMuscle: [.tricepLongHead],
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Lateral Raise",
                PrimaryMuscle: [.lateralDeltoid],
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Rear Delt Fly",
                PrimaryMuscle: [.rearDeltoid],
                SecondaryMuscle: [.rhomboids],
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Leg Press",
                PrimaryMuscle: [.quadriceps],
                SecondaryMuscle: [.gluteMaximus, .hamstrings],
                resistanceType: .machine,
                movementPattern: .squat,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Romanian Deadlift",
                PrimaryMuscle: [.hamstrings, .gluteMaximus],
                SecondaryMuscle: [.erectorSpinae],
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Leg Extension",
                PrimaryMuscle: [.quadriceps],
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Leg Curl",
                PrimaryMuscle: [.hamstrings],
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Standing Calf Raise",
                PrimaryMuscle: [.calves],
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Crunch",
                PrimaryMuscle: [.rectusAbdominis],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Plank",
                PrimaryMuscle: [.transverseAbdominis],
                SecondaryMuscle: [.rectusAbdominis, .obliques],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Treadmill Run",
                PrimaryMuscle: [.quadriceps, .hamstrings, .calves],
                SecondaryMuscle: [.gluteMaximus],
                category: .cardio,
                trackingType: .durationAndDistance,
                equipmentType: .cardioMachine,
                difficulty: .beginner,
                tags: ["cardio"]
            )
        ]
    }
}

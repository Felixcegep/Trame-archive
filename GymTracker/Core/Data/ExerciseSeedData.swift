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
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Goblet Stiletto Squat",
                PrimaryMuscle: [.quadriceps],
                SecondaryMuscle: [.gluteMaximus],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                difficulty: .beginner,
                tags: ["front-loaded", "heels-elevated"]
            ),

            ExerciceTemplate(
                name: "Bulgarian Split Squat",
                PrimaryMuscle: [.quadriceps, .gluteMaximus],
                SecondaryMuscle: [.hamstrings],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                difficulty: .intermediate,
                tags: ["unilateral"]
            ),

            ExerciceTemplate(
                name: "Deadlift",
                PrimaryMuscle: [.erectorSpinae, .gluteMaximus, .hamstrings],
                SecondaryMuscle: [.trapezius, .forearms],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .advanced
            ),

            ExerciceTemplate(
                name: "Back Squat",
                PrimaryMuscle: [.quadriceps, .gluteMaximus],
                SecondaryMuscle: [.hamstrings, .erectorSpinae],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Overhead Press",
                PrimaryMuscle: [.frontDeltoid, .lateralDeltoid],
                SecondaryMuscle: [.tricepLongHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Barbell Row",
                PrimaryMuscle: [.latissimusDorsi, .rhomboids],
                SecondaryMuscle: [.rearDeltoid, .bicep, .forearms],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Dumbbell Incline Press",
                PrimaryMuscle: [.upperChest],
                SecondaryMuscle: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Face Pull",
                PrimaryMuscle: [.rearDeltoid],
                SecondaryMuscle: [.trapezius, .rhomboids],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .horizontalPull,
                difficulty: .beginner,
                tags: ["shoulder-health"]
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
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .verticalPull,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Seated Cable Row",
                PrimaryMuscle: [.rhomboids, .latissimusDorsi],
                SecondaryMuscle: [.bicep, .rearDeltoid],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .horizontalPull,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Barbell Curl",
                PrimaryMuscle: [.bicep],
                SecondaryMuscle: [.brachialis, .brachioradialis],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Hammer Curl",
                PrimaryMuscle: [.brachialis],
                SecondaryMuscle: [.bicep, .brachioradialis],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Triceps Pushdown",
                PrimaryMuscle: [.tricepLateralHead, .tricepMedialHead],
                SecondaryMuscle: [.tricepLongHead],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Lateral Raise",
                PrimaryMuscle: [.lateralDeltoid],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Rear Delt Fly",
                PrimaryMuscle: [.rearDeltoid],
                SecondaryMuscle: [.rhomboids],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Leg Press",
                PrimaryMuscle: [.quadriceps],
                SecondaryMuscle: [.gluteMaximus, .hamstrings],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .squat,
                difficulty: .beginner,
                isPlateLoaded: true
            ),

            ExerciceTemplate(
                name: "Romanian Deadlift",
                PrimaryMuscle: [.hamstrings, .gluteMaximus],
                SecondaryMuscle: [.erectorSpinae],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "B-Stance RDL",
                PrimaryMuscle: [.hamstrings, .gluteMaximus],
                SecondaryMuscle: [.erectorSpinae],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .intermediate,
                tags: ["unilateral", "kickstand"]
            ),

            ExerciceTemplate(
                name: "45-Degree Back Extension",
                PrimaryMuscle: [.erectorSpinae, .gluteMaximus],
                SecondaryMuscle: [.hamstrings],
                equipmentType: .other,
                resistanceType: .bodyweight,
                movementPattern: .hinge,
                difficulty: .beginner,
                tags: ["rehabilitation", "high-rep"]
            ),

            ExerciceTemplate(
                name: "Leg Extension",
                PrimaryMuscle: [.quadriceps],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Leg Curl",
                PrimaryMuscle: [.hamstrings],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Copenhagen Plank",
                PrimaryMuscle: [.adductors],
                SecondaryMuscle: [.obliques, .gluteMedius],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .intermediate,
                tags: ["hip-health"]
            ),

            ExerciceTemplate(
                name: "Standing Calf Raise",
                PrimaryMuscle: [.calves],
                equipmentType: .machine,
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
                name: "Dumbbell Bench Press",
                PrimaryMuscle: [.middleChest],
                SecondaryMuscle: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .beginner
            ),

            ExerciceTemplate(
                name: "Military Press",
                PrimaryMuscle: [.frontDeltoid, .lateralDeltoid],
                SecondaryMuscle: [.tricepLongHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                difficulty: .intermediate
            ),

            ExerciceTemplate(
                name: "Chest-Supported Row",
                PrimaryMuscle: [.rhomboids, .latissimusDorsi],
                SecondaryMuscle: [.rearDeltoid, .bicep],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
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

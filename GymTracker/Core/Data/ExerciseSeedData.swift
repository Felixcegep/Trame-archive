//
//  ExerciseSeedData.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum ExerciseSeedData {
    static func templates() -> [Exercise] {
        [
            Exercise(
                name: "Bench Press",
                primaryMuscles: [.middleChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                trackingType: .weightAndReps,
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Incline Bench Press",
                primaryMuscles: [.upperChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Goblet Stiletto Squat",
                primaryMuscles: [.quadriceps],
                secondaryMuscles: [.gluteMaximus],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
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
                difficulty: .intermediate,
                tags: ["unilateral"]
            ),

            Exercise(
                name: "Deadlift",
                primaryMuscles: [.erectorSpinae, .gluteMaximus, .hamstrings],
                secondaryMuscles: [.trapezius, .forearms],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .advanced
            ),

            Exercise(
                name: "Back Squat",
                primaryMuscles: [.quadriceps, .gluteMaximus],
                secondaryMuscles: [.hamstrings, .erectorSpinae],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .squat,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Overhead Press",
                primaryMuscles: [.frontDeltoid, .lateralDeltoid],
                secondaryMuscles: [.tricepLongHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Barbell Row",
                primaryMuscles: [.latissimusDorsi, .rhomboids],
                secondaryMuscles: [.rearDeltoid, .bicep, .forearms],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Dumbbell Incline Press",
                primaryMuscles: [.upperChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Face Pull",
                primaryMuscles: [.rearDeltoid],
                secondaryMuscles: [.trapezius, .rhomboids],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .horizontalPull,
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
                difficulty: .beginner
            ),

            Exercise(
                name: "Lat Pulldown",
                primaryMuscles: [.latissimusDorsi],
                secondaryMuscles: [.bicep, .teresMajor],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .verticalPull,
                difficulty: .beginner
            ),

            Exercise(
                name: "Seated Cable Row",
                primaryMuscles: [.rhomboids, .latissimusDorsi],
                secondaryMuscles: [.bicep, .rearDeltoid],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .horizontalPull,
                difficulty: .beginner
            ),

            Exercise(
                name: "Barbell Curl",
                primaryMuscles: [.bicep],
                secondaryMuscles: [.brachialis, .brachioradialis],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Hammer Curl",
                primaryMuscles: [.brachialis],
                secondaryMuscles: [.bicep, .brachioradialis],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Triceps Pushdown",
                primaryMuscles: [.tricepLateralHead, .tricepMedialHead],
                secondaryMuscles: [.tricepLongHead],
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Lateral Raise",
                primaryMuscles: [.lateralDeltoid],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Rear Delt Fly",
                primaryMuscles: [.rearDeltoid],
                secondaryMuscles: [.rhomboids],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Leg Press",
                primaryMuscles: [.quadriceps],
                secondaryMuscles: [.gluteMaximus, .hamstrings],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .squat,
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
                difficulty: .intermediate
            ),

            Exercise(
                name: "B-Stance RDL",
                primaryMuscles: [.hamstrings, .gluteMaximus],
                secondaryMuscles: [.erectorSpinae],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .hinge,
                difficulty: .intermediate,
                tags: ["unilateral", "kickstand"]
            ),

            Exercise(
                name: "45-Degree Back Extension",
                primaryMuscles: [.erectorSpinae, .gluteMaximus],
                secondaryMuscles: [.hamstrings],
                equipmentType: .other,
                resistanceType: .bodyweight,
                movementPattern: .hinge,
                difficulty: .beginner,
                tags: ["rehabilitation", "high-rep"]
            ),

            Exercise(
                name: "Leg Extension",
                primaryMuscles: [.quadriceps],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Leg Curl",
                primaryMuscles: [.hamstrings],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Copenhagen Plank",
                primaryMuscles: [.adductors],
                secondaryMuscles: [.obliques, .gluteMedius],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .intermediate,
                tags: ["hip-health"]
            ),

            Exercise(
                name: "Standing Calf Raise",
                primaryMuscles: [.calves],
                equipmentType: .machine,
                resistanceType: .externalWeight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Crunch",
                primaryMuscles: [.rectusAbdominis],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Dumbbell Bench Press",
                primaryMuscles: [.middleChest],
                secondaryMuscles: [.frontDeltoid, .tricepLateralHead],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .beginner
            ),

            Exercise(
                name: "Military Press",
                primaryMuscles: [.frontDeltoid, .lateralDeltoid],
                secondaryMuscles: [.tricepLongHead],
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .verticalPush,
                difficulty: .intermediate
            ),

            Exercise(
                name: "Chest-Supported Row",
                primaryMuscles: [.rhomboids, .latissimusDorsi],
                secondaryMuscles: [.rearDeltoid, .bicep],
                equipmentType: .dumbbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPull,
                difficulty: .beginner
            ),

            Exercise(
                name: "Plank",
                primaryMuscles: [.transverseAbdominis],
                secondaryMuscles: [.rectusAbdominis, .obliques],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Side Plank",
                primaryMuscles: [.obliques, .gluteMedius],
                secondaryMuscles: [.transverseAbdominis],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .beginner,
                tags: ["pelvic-stability", "rehabilitation"]
            ),

            Exercise(
                name: "Clamshell",
                primaryMuscles: [.gluteMedius, .abductors],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .isolation,
                difficulty: .beginner,
                tags: ["hip-stability", "rehabilitation"]
            ),

            Exercise(
                name: "Pelvic Tilt",
                primaryMuscles: [.transverseAbdominis],
                secondaryMuscles: [.gluteMaximus],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .beginner,
                tags: ["mobility", "rehabilitation"]
            ),

            Exercise(
                name: "Bird Dog",
                primaryMuscles: [.transverseAbdominis, .gluteMaximus],
                secondaryMuscles: [.erectorSpinae],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .beginner,
                tags: ["pelvic-stability", "rehabilitation"]
            ),

            Exercise(
                name: "Glute Bridge",
                primaryMuscles: [.gluteMaximus],
                secondaryMuscles: [.hamstrings],
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .hinge,
                difficulty: .beginner,
                tags: ["bilateral", "rehabilitation"]
            ),

            Exercise(
                name: "Seated Calf Raise",
                primaryMuscles: [.calves],
                equipmentType: .machine,
                resistanceType: .machine,
                movementPattern: .isolation,
                difficulty: .beginner
            ),

            Exercise(
                name: "Treadmill Run",
                primaryMuscles: [.quadriceps, .hamstrings, .calves],
                secondaryMuscles: [.gluteMaximus],
                category: .cardio,
                trackingType: .durationAndDistance,
                equipmentType: .cardioMachine,
                difficulty: .beginner,
                tags: ["cardio"]
            )
        ]
    }
}

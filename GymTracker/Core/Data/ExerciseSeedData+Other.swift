//
//  ExerciseSeedData+Other.swift
//  GymTracker
//

import Foundation

extension ExerciseSeedData {
    static func otherTemplates() -> [Exercise] {
        var copenhagenPlank = Exercise(
            name: "Copenhagen Plank",
            primaryMuscles: [.adductors],
            secondaryMuscles: [.obliques, .gluteMedius],
            trackingType: .duration,
            equipmentType: .bodyweight,
            resistanceType: .bodyweight,
            movementPattern: .antiLateralFlexion,
            forceType: .staticHold,
            mechanics: .compound,
            difficulty: .intermediate,
            tags: ["hip-health", "adductors", "core"],
            laterality: .unilateral,
            repCountingStyle: .perSide
        )
        copenhagenPlank.frenchName = "Planche de Copenhague"
        copenhagenPlank.searchAliases = ["copenhagen adduction", "adductor plank", "planche de copenhague", "copenhague"]

        return [
            copenhagenPlank,
            Exercise(
                name: "Crunch",
                primaryMuscles: [.rectusAbdominis],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .spinalFlexion,
                forceType: .pull,
                mechanics: .isolation,
                difficulty: .beginner
            ),
            Exercise(
                name: "Plank",
                primaryMuscles: [.transverseAbdominis],
                secondaryMuscles: [.rectusAbdominis, .obliques],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiExtension,
                forceType: .staticHold,
                mechanics: .compound,
                difficulty: .beginner
            ),
            Exercise(
                name: "Side Plank",
                primaryMuscles: [.obliques, .gluteMedius],
                secondaryMuscles: [.transverseAbdominis],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiLateralFlexion,
                forceType: .staticHold,
                mechanics: .compound,
                difficulty: .beginner,
                tags: ["pelvic-stability", "rehabilitation"]
            ),
            Exercise(
                name: "Clamshell",
                primaryMuscles: [.gluteMedius, .abductors],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .hipAbduction,
                forceType: .push,
                mechanics: .isolation,
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
                mechanics: .isolation,
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
                mechanics: .compound,
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
                forceType: .pull,
                mechanics: .compound,
                difficulty: .beginner,
                tags: ["bilateral", "rehabilitation"]
            ),
            Exercise(
                name: "Treadmill Run",
                primaryMuscles: [.quadriceps, .hamstrings, .calves],
                secondaryMuscles: [.gluteMaximus],
                category: .cardio,
                trackingType: .durationAndDistance,
                equipmentType: .cardioMachine,
                movementPattern: .locomotion,
                mechanics: .compound,
                difficulty: .beginner,
                tags: ["cardio"]
            ),
            Exercise(
                name: "Stationary Bike",
                primaryMuscles: [.quadriceps, .hamstrings, .calves],
                secondaryMuscles: [.gluteMaximus],
                category: .cardio,
                trackingType: .calories,
                equipmentType: .cardioMachine,
                movementPattern: .locomotion,
                mechanics: .compound,
                difficulty: .beginner,
                tags: ["cardio"]
            )
        ]
    }
}

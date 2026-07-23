enum WorkoutTemplateSeedData {
    private struct Prescription {
        let exerciseName: String
        let sets: Int
        let minimum: Int
        let maximum: Int
        let rpe: Double
        let restSeconds: Int
        let notes: String?
    }

    static let collectionName = "Upper/Lower Program – 4 Days"
    static let seededTemplateNames = [
        "Day 1 – Lower Body (Squat Focus)",
        "Day 2 – Upper Body (Push/Pull)",
        "Day 3 – Lower Body (Posterior Chain)",
        "Day 4 – Upper Body (Vertical Push/Pull)"
    ]

    private static let definitions: [(name: String, prescriptions: [Prescription])] = [
        (
            "Day 1 – Lower Body (Squat Focus)",
            [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Heels elevated, dumbbell in front, neutral pelvis."),
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Lean torso forward; work each leg."),
                Prescription(exerciseName: "Leg Extension", sets: 2, minimum: 12, maximum: 15, rpe: 9, restSeconds: 90, notes: nil),
                Prescription(exerciseName: "Copenhagen Plank", sets: 3, minimum: 20, maximum: 30, rpe: 7, restSeconds: 60, notes: "Seconds per side.")
            ]
        ),
        (
            "Day 2 – Upper Body (Push/Pull)",
            [
                Prescription(exerciseName: "Bench Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Superset A1 with Barbell Row."),
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Superset A2 with Bench Press."),
                Prescription(exerciseName: "Dumbbell Incline Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Use a steep incline. Superset B1 with Lat Pulldown."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B2 with Dumbbell Incline Press."),
                Prescription(exerciseName: "Face Pull", sets: 2, minimum: 15, maximum: 15, rpe: 7, restSeconds: 60, notes: "Pull toward the forehead.")
            ]
        ),
        (
            "Day 3 – Lower Body (Posterior Chain)",
            [
                Prescription(exerciseName: "B-Stance RDL", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Rear foot is a kickstand; hinge through the front leg."),
                Prescription(exerciseName: "45-Degree Back Extension", sets: 3, minimum: 15, maximum: 20, rpe: 8.5, restSeconds: 90, notes: "Squeeze glutes at the top without hyperextending."),
                Prescription(exerciseName: "Leg Curl", sets: 3, minimum: 10, maximum: 12, rpe: 9, restSeconds: 90, notes: nil),
                Prescription(exerciseName: "Standing Calf Raise", sets: 2, minimum: 15, maximum: 15, rpe: 8, restSeconds: 60, notes: "Crunches are an alternative.")
            ]
        ),
        (
            "Day 4 – Upper Body (Vertical Push/Pull)",
            [
                Prescription(exerciseName: "Military Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Standing barbell or seated dumbbells. Superset A1 with Pull Up."),
                Prescription(exerciseName: "Pull Up", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Weighted or bodyweight. Superset A2 with Military Press."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 10, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B1 with Chest-Supported Row."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 3, minimum: 10, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B2 with Dumbbell Bench Press."),
                Prescription(exerciseName: "Lateral Raise", sets: 3, minimum: 12, maximum: 15, rpe: 9, restSeconds: 60, notes: nil)
            ]
        )
    ]

    static func templates(using exercises: [Exercise]) -> [WorkoutTemplate] {
        let exercisesByName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return definitions.compactMap { definition -> WorkoutTemplate? in
            let selectedExercises = definition.prescriptions.compactMap { exercisesByName[$0.exerciseName] }
            guard selectedExercises.count == definition.prescriptions.count else { return nil }

            let templateExercises: [TemplateExercise] = definition.prescriptions.enumerated().compactMap { index, prescription in
                guard let exercise = exercisesByName[prescription.exerciseName] else { return nil }
                return TemplateExercise(
                    exercise: exercise,
                    order: index,
                    targetSets: prescription.sets,
                    repRangeMinimum: prescription.minimum,
                    repRangeMaximum: prescription.maximum,
                    restSeconds: prescription.restSeconds,
                    targetRPE: prescription.rpe,
                    notes: prescription.notes
                )
            }
            return WorkoutTemplate(
                name: definition.name,
                exercises: selectedExercises,
                templateExercises: templateExercises
            )
        }
    }
}

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

    private static let definitions: [(name: String, prescriptions: [Prescription])] = [
        (
            "Jour 1 - Bas du Corps (Squat/Genoux)",
            [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Heels elevated, dumbbell in front, neutral pelvis."),
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Lean torso forward; work each leg."),
                Prescription(exerciseName: "Leg Extension", sets: 2, minimum: 12, maximum: 15, rpe: 9, restSeconds: 90, notes: nil),
                Prescription(exerciseName: "Copenhagen Plank", sets: 3, minimum: 20, maximum: 30, rpe: 7, restSeconds: 60, notes: "Seconds per side.")
            ]
        ),
        (
            "Jour 2 - Haut du Corps (Poussée/Tirage)",
            [
                Prescription(exerciseName: "Bench Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Superset A1 with Barbell Row."),
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Superset A2 with Bench Press."),
                Prescription(exerciseName: "Dumbbell Incline Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Use a steep incline. Superset B1 with Lat Pulldown."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B2 with Dumbbell Incline Press."),
                Prescription(exerciseName: "Face Pull", sets: 2, minimum: 15, maximum: 15, rpe: 7, restSeconds: 60, notes: "Pull toward the forehead.")
            ]
        ),
        (
            "Jour 3 - Bas du Corps (Chaîne Postérieure)",
            [
                Prescription(exerciseName: "B-Stance RDL", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Rear foot is a kickstand; hinge through the front leg."),
                Prescription(exerciseName: "45-Degree Back Extension", sets: 3, minimum: 15, maximum: 20, rpe: 8.5, restSeconds: 90, notes: "Squeeze glutes at the top without hyperextending."),
                Prescription(exerciseName: "Leg Curl", sets: 3, minimum: 10, maximum: 12, rpe: 9, restSeconds: 90, notes: nil),
                Prescription(exerciseName: "Standing Calf Raise", sets: 2, minimum: 15, maximum: 15, rpe: 8, restSeconds: 60, notes: "Crunches are an alternative.")
            ]
        ),
        (
            "Jour 4 - Haut du Corps (Poussée Verticale/Tirage)",
            [
                Prescription(exerciseName: "Military Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Standing barbell or seated dumbbells. Superset A1 with Pull Up."),
                Prescription(exerciseName: "Pull Up", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Weighted or bodyweight. Superset A2 with Military Press."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 10, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B1 with Chest-Supported Row."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 3, minimum: 10, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B2 with Dumbbell Bench Press."),
                Prescription(exerciseName: "Lateral Raise", sets: 3, minimum: 12, maximum: 15, rpe: 9, restSeconds: 60, notes: nil)
            ]
        )
    ]

    static func templates(using exercises: [ExerciceTemplate]) -> [WorkoutTemplate] {
        let exercisesByName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })

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

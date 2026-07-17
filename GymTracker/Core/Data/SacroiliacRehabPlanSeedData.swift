import Foundation

/// A conservative four-day program that preserves the supplied SI-health
/// constraints as prescription notes. It is a reusable plan only: starting it
/// still snapshots every target into the user's independent workout history.
enum SacroiliacRehabPlanSeedData {
    static let planName = "Split 4 jours — Réadaptation sacro-iliaque gauche"

    private struct ExercisePrescription {
        let name: String
        let sets: Int
        let minimum: Int
        let maximum: Int
        let restSeconds: Int
        let note: String
        let role: ExerciseRole
    }

    private struct Session {
        let name: String
        let dayOffset: Int
        let note: String
        let exercises: [ExercisePrescription]
    }

    private static let preparation: [ExercisePrescription] = [
        .init(name: "Side Plank", sets: 2, minimum: 15, maximum: 20, restSeconds: 45, note: "15–20 seconds per side. Stabilize the quadratus lumborum and glute medius; stop with left low-back or glute discomfort.", role: .preparation),
        .init(name: "Clamshell", sets: 2, minimum: 20, maximum: 20, restSeconds: 45, note: "20 controlled reps per side. Activate hip external rotators without forcing the left side.", role: .preparation),
        .init(name: "Pelvic Tilt", sets: 1, minimum: 10, maximum: 10, restSeconds: 30, note: "10 slow, gentle anterior/posterior tilts on the floor. No load.", role: .preparation),
        .init(name: "Bird Dog", sets: 2, minimum: 8, maximum: 8, restSeconds: 45, note: "8 slow controlled reps per side. Keep the pelvis level; do not chase leg hyperextension.", role: .preparation)
    ]

    private static let sessions: [Session] = [
        .init(
            name: "Jour 1 — Bas du corps (dominante genou)",
            dayOffset: 0,
            note: "Preparation is mandatory before this session. Brace gently before every set. Any low-back or left-glute discomfort ends the set immediately.",
            exercises: preparation + [
                .init(name: "Leg Press", sets: 3, minimum: 8, maximum: 10, restSeconds: 120, note: "Bilateral, guided and symmetric. A fitball wall squat is an alternative. Avoid asymmetric shear and axial pelvic loading.", role: .main),
                .init(name: "Leg Extension", sets: 3, minimum: 12, maximum: 15, restSeconds: 90, note: "Isolation; keep the pelvis quiet.", role: .secondary),
                .init(name: "Copenhagen Plank", sets: 3, minimum: 15, maximum: 20, restSeconds: 60, note: "15–20 seconds per side. Place the knee—not the foot—on the bench to shorten the lever and protect the adductor/SI region.", role: .secondary),
                .init(name: "Seated Calf Raise", sets: 3, minimum: 15, maximum: 15, restSeconds: 60, note: "Seated machine or dumbbell variation; avoid loading the back.", role: .accessory)
            ]
        ),
        .init(
            name: "Jour 2 — Haut du corps (tirage)",
            dayOffset: 1,
            note: "Use supported or seated positions. Any low-back or left-glute discomfort ends the set immediately.",
            exercises: [
                .init(name: "Chest-Supported Row", sets: 3, minimum: 6, maximum: 8, restSeconds: 120, note: "Chest supported on a 30–45° incline bench; unload the pelvis and lumbar spine.", role: .main),
                .init(name: "Lat Pulldown", sets: 3, minimum: 8, maximum: 10, restSeconds: 120, note: "Seated and stable.", role: .main),
                .init(name: "Dumbbell Bench Press", sets: 3, minimum: 8, maximum: 10, restSeconds: 120, note: "Keep a neutral pelvis.", role: .secondary),
                .init(name: "Dumbbell Incline Press", sets: 3, minimum: 10, maximum: 10, restSeconds: 90, note: "Use an incline bench and stay seated/stable.", role: .secondary),
                .init(name: "Face Pull", sets: 3, minimum: 15, maximum: 15, restSeconds: 60, note: "High cable, seated if needed; controlled shoulder-health accessory.", role: .accessory)
            ]
        ),
        .init(
            name: "Jour 3 — Bas du corps (dominante hanche)",
            dayOffset: 3,
            note: "Preparation is mandatory before this session. Brace gently before every set. Any low-back or left-glute discomfort ends the set immediately.",
            exercises: preparation + [
                .init(name: "Glute Bridge", sets: 3, minimum: 10, maximum: 12, restSeconds: 120, note: "Bilateral and symmetric. Drive evenly through both heels; squeeze both glutes without lumbar hyperextension.", role: .main),
                .init(name: "45-Degree Back Extension", sets: 3, minimum: 15, maximum: 20, restSeconds: 90, note: "Replace immediately with slow Bird Dog on the floor if descent or ascent causes any left-sided pinch.", role: .secondary),
                .init(name: "Leg Curl", sets: 3, minimum: 12, maximum: 12, restSeconds: 90, note: "Seated or lying, bilateral and symmetric.", role: .secondary),
                .init(name: "Plank", sets: 3, minimum: 30, maximum: 45, restSeconds: 60, note: "30–45 seconds. Maintain alignment and steady breathing.", role: .accessory)
            ]
        ),
        .init(
            name: "Jour 4 — Haut du corps (poussée)",
            dayOffset: 5,
            note: "No standing overhead press. Any low-back or left-glute discomfort ends the set immediately.",
            exercises: [
                .init(name: "Military Press", sets: 3, minimum: 8, maximum: 10, restSeconds: 120, note: "Seated with an 85° backrest. Keep back and pelvis firmly against the pad to avoid sacral shear.", role: .main),
                .init(name: "Pull Up", sets: 3, minimum: 6, maximum: 8, restSeconds: 120, note: "Bodyweight or assisted; use the assisted variation if needed.", role: .main),
                .init(name: "Dumbbell Incline Press", sets: 3, minimum: 10, maximum: 10, restSeconds: 90, note: "Stable, seated incline press.", role: .secondary),
                .init(name: "Seated Cable Row", sets: 3, minimum: 10, maximum: 10, restSeconds: 90, note: "Keep feet braced and torso supported/still.", role: .secondary),
                .init(name: "Lateral Raise", sets: 3, minimum: 12, maximum: 15, restSeconds: 60, note: "Perform seated with no momentum.", role: .accessory)
            ]
        )
    ]

    static func makePlan(using exercises: [Exercise]) -> WorkoutPlan? {
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        guard sessions.allSatisfy({ session in
            session.exercises.allSatisfy { byName[$0.name] != nil }
        }) else { return nil }

        let weeklyRPETargets: [Double] = [6.5, 7, 8, 5.5]
        let weeks = (0..<4).map { weekIndex in
            PlanWeek(
                weekIndex: weekIndex,
                name: weekName(for: weekIndex),
                notes: weekNote(for: weekIndex),
                plannedWorkouts: sessions.enumerated().map { workoutIndex, session in
                    PlannedWorkout(
                        name: session.name,
                        orderIndex: workoutIndex,
                        dayOffset: session.dayOffset,
                        estimatedDurationSeconds: 3_600,
                        notes: session.note,
                        plannedExercises: session.exercises.enumerated().compactMap { exerciseIndex, prescription in
                            guard let exercise = byName[prescription.name] else { return nil }
                            return PlannedExercise(
                                exercise: exercise,
                                orderIndex: exerciseIndex,
                                role: prescription.role,
                                targetSets: prescription.sets,
                                repRangeMinimum: prescription.minimum,
                                repRangeMaximum: prescription.maximum,
                                restSeconds: prescription.restSeconds,
                                targetRPE: weeklyRPETargets[weekIndex],
                                notes: prescription.note,
                                progressionRule: .none
                            )
                        }
                    )
                }
            )
        }

        return WorkoutPlan(
            name: planName,
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            requiredEquipment: [.bodyweight, .cable, .dumbbell, .machine],
            daysPerWeek: 4,
            durationWeeks: 4,
            notes: "Objective: hypertrophy, strength, bilateral symmetry, and left SI rehabilitation. Stop a set immediately with low-back or left-glute discomfort. Week 1: RPE 6–7; Week 2: RPE 7 only if symptom-free; Week 3: RPE 8 controlled; Week 4: RPE 5–6 with 30% load reduction. This is a training prescription, not medical diagnosis or treatment.",
            blocks: [
                PlanBlock(
                    name: "Reprise et montée contrôlée",
                    phaseType: .hypertrophy,
                    orderIndex: 0,
                    goal: "Technique, symptom-free loading, and controlled RPE progression.",
                    weeks: Array(weeks.prefix(3))
                ),
                PlanBlock(
                    name: "Décharge",
                    phaseType: .deload,
                    orderIndex: 1,
                    goal: "Consolidate recovery with lower effort and load.",
                    notes: "Reduce working loads by 30% and keep effort at RPE 5–6.",
                    deloadVolumeReductionPercent: 0,
                    deloadIntensityReductionPercent: 30,
                    weeks: [weeks[3]]
                )
            ]
        )
    }

    private static func weekName(for weekIndex: Int) -> String {
        ["Semaine 1 — Reprise", "Semaine 2 — Progression", "Semaine 3 — Pic contrôlé", "Semaine 4 — Décharge"][weekIndex]
    }

    private static func weekNote(for weekIndex: Int) -> String {
        [
            "RPE 6–7 maximum. Prioritize tempo, control, and confirming zero pain.",
            "RPE 7. Add load only when the left pelvis remains completely quiet.",
            "RPE 8 maximum. Use deliberate bracing and strict bilateral symmetry.",
            "RPE 5–6. Reduce working loads by 30% to consolidate recovery."
        ][weekIndex]
    }
}

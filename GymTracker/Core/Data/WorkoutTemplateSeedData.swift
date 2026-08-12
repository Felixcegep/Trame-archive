import SwiftData

enum WorkoutTemplateSeedData {
    private struct TemplateDefinition {
        let seedKey: String
        let name: String
        let prescriptions: [Prescription]
    }

    struct CollectionDefinition {
        let seedKey: String
        let name: String
        let templateSeedKeys: [String]
    }

    struct MobilityLinkDefinition {
        let templateSeedKey: String
        let preRoutineSeedKey: String?
        let postRoutineSeedKey: String?
    }

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

    static let collections: [CollectionDefinition] = [
        CollectionDefinition(
            seedKey: "workout-collection.upper-lower-four-day",
            name: "Upper/Lower Program – 4 Days",
            templateSeedKeys: [
                "workout-template.day-1--u2013--lower-body--u28-squat-focus-u29",
                "workout-template.day-2--u2013--upper-body--u28-push-slash-pull-u29",
                "workout-template.day-3--u2013--lower-body--u28-posterior-chain-u29",
                "workout-template.day-4--u2013--upper-body--u28-vertical-push-slash-pull-u29"
            ]
        ),
        CollectionDefinition(
            seedKey: "workout-collection.push--slash--pull--slash--legs-split--u2013--3-days",
            name: "Push / Pull / Legs Split – 3 Days",
            templateSeedKeys: [
                "workout-template.ppl--u2013--push-day--u28-chest-u2c--shoulders-u2c--triceps-u29",
                "workout-template.ppl--u2013--pull-day--u28-back-u2c--rear-delts-u2c--biceps-u29",
                "workout-template.ppl--u2013--leg-day--u28-quads-u2c--hamstrings-u2c--calves-u29"
            ]
        ),
        CollectionDefinition(
            seedKey: "workout-collection.full-body-express--u2013--2-days",
            name: "Full Body Express – 2 Days",
            templateSeedKeys: [
                "workout-template.full-body-a--u28-squat--u26--push-focus-u29",
                "workout-template.full-body-b--u28-hinge--u26--pull-focus-u29"
            ]
        )
    ]

    static var seededTemplateNames: [String] {
        definitions.map(\.name)
    }

    static let mobilityLinks: [MobilityLinkDefinition] = [
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.day-1--u2013--lower-body--u28-squat-focus-u29",
            preRoutineSeedKey: "mobility-routine.ankle-foot-mobilization",
            postRoutineSeedKey: "mobility-routine.post-leg-day-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.day-2--u2013--upper-body--u28-push-slash-pull-u29",
            preRoutineSeedKey: "mobility-routine.upper-body-bench-warmup",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.day-3--u2013--lower-body--u28-posterior-chain-u29",
            preRoutineSeedKey: "mobility-routine.loaded-mobility-foundations",
            postRoutineSeedKey: "mobility-routine.post-leg-day-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.day-4--u2013--upper-body--u28-vertical-push-slash-pull-u29",
            preRoutineSeedKey: "mobility-routine.overhead-shoulder-saver",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.ppl--u2013--push-day--u28-chest-u2c--shoulders-u2c--triceps-u29",
            preRoutineSeedKey: "mobility-routine.upper-body-bench-warmup",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.ppl--u2013--pull-day--u28-back-u2c--rear-delts-u2c--biceps-u29",
            preRoutineSeedKey: "mobility-routine.overhead-shoulder-saver",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.ppl--u2013--leg-day--u28-quads-u2c--hamstrings-u2c--calves-u29",
            preRoutineSeedKey: "mobility-routine.ankle-foot-mobilization",
            postRoutineSeedKey: "mobility-routine.post-leg-day-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.full-body-a--u28-squat--u26--push-focus-u29",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.full-body-b--u28-hinge--u26--pull-focus-u29",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.simple-barbell-strength-a",
            preRoutineSeedKey: "mobility-routine.squat-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.simple-barbell-strength-b",
            preRoutineSeedKey: "mobility-routine.deadlift-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.express-a",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.express-b",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.dumbbell-a",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.dumbbell-b",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.machine-a",
            preRoutineSeedKey: "mobility-routine.daily-mobility-reset",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.machine-b",
            preRoutineSeedKey: "mobility-routine.daily-mobility-reset",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.calisthenics-a",
            preRoutineSeedKey: "mobility-routine.daily-mobility-reset",
            postRoutineSeedKey: "mobility-routine.lower-back-decompression"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.calisthenics-b",
            preRoutineSeedKey: "mobility-routine.daily-mobility-reset",
            postRoutineSeedKey: "mobility-routine.lower-back-decompression"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.powerlifting-day-1--u2014--squat-priority",
            preRoutineSeedKey: "mobility-routine.squat-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.powerlifting-day-2--u2014--bench-priority",
            preRoutineSeedKey: "mobility-routine.upper-body-bench-warmup",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.powerlifting-day-3--u2014--deadlift-priority",
            preRoutineSeedKey: "mobility-routine.deadlift-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.olympic-day-1--u2014--snatch-positions",
            preRoutineSeedKey: "mobility-routine.olympic-lifting-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.olympic-day-2--u2014--clean--u26--jerk-positions",
            preRoutineSeedKey: "mobility-routine.front-rack-and-wrist-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.olympic-day-3--u2014--lift-integration",
            preRoutineSeedKey: "mobility-routine.olympic-lifting-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.strongman-day-1--u2014--overhead-strength",
            preRoutineSeedKey: "mobility-routine.front-rack-and-wrist-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.strongman-day-2--u2014--deadlift--u26--lower-body",
            preRoutineSeedKey: "mobility-routine.deadlift-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.strongman-day-3--u2014--events--u26--conditioning",
            preRoutineSeedKey: "mobility-routine.strongman-event-preparation",
            postRoutineSeedKey: nil
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.home-dumbbell-full-body",
            preRoutineSeedKey: "mobility-routine.full-body-morning-flow",
            postRoutineSeedKey: "mobility-routine.daily-mobility-reset"
        ),
        MobilityLinkDefinition(
            templateSeedKey: "workout-template.calisthenics-beginner-full-body",
            preRoutineSeedKey: "mobility-routine.daily-mobility-reset",
            postRoutineSeedKey: "mobility-routine.lower-back-decompression"
        )
    ]

    private static var definitions: [TemplateDefinition] {
        var values: [TemplateDefinition] = [
        TemplateDefinition(
            seedKey: "workout-template.day-1--u2013--lower-body--u28-squat-focus-u29",
            name: "Day 1 – Lower Body (Squat Focus)",
            prescriptions: [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Heels elevated, dumbbell in front, neutral pelvis."),
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Lean torso forward; work each leg."),
                Prescription(exerciseName: "Leg Extension", sets: 2, minimum: 12, maximum: 15, rpe: 9, restSeconds: 90, notes: nil),
                Prescription(exerciseName: "Copenhagen Plank", sets: 3, minimum: 20, maximum: 30, rpe: 7, restSeconds: 60, notes: "Seconds per side.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.day-2--u2013--upper-body--u28-push-slash-pull-u29",
            name: "Day 2 – Upper Body (Push/Pull)",
            prescriptions: [
                Prescription(exerciseName: "Bench Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Superset A1 with Barbell Row."),
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Superset A2 with Bench Press."),
                Prescription(exerciseName: "Dumbbell Incline Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Use a steep incline. Superset B1 with Lat Pulldown."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B2 with Dumbbell Incline Press."),
                Prescription(exerciseName: "Face Pull", sets: 2, minimum: 15, maximum: 15, rpe: 7, restSeconds: 60, notes: "Pull toward the forehead.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.day-3--u2013--lower-body--u28-posterior-chain-u29",
            name: "Day 3 – Lower Body (Posterior Chain)",
            prescriptions: [
                Prescription(exerciseName: "B-Stance RDL", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Rear foot is a kickstand; hinge through the front leg."),
                Prescription(exerciseName: "45-Degree Back Extension", sets: 3, minimum: 15, maximum: 20, rpe: 8.5, restSeconds: 90, notes: "Squeeze glutes at the top without hyperextending."),
                Prescription(exerciseName: "Leg Curl", sets: 3, minimum: 10, maximum: 12, rpe: 9, restSeconds: 90, notes: nil),
                Prescription(exerciseName: "Standing Calf Raise", sets: 2, minimum: 15, maximum: 15, rpe: 8, restSeconds: 60, notes: "Crunches are an alternative.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.day-4--u2013--upper-body--u28-vertical-push-slash-pull-u29",
            name: "Day 4 – Upper Body (Vertical Push/Pull)",
            prescriptions: [
                Prescription(exerciseName: "Military Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Standing barbell or seated dumbbells. Superset A1 with Pull Up."),
                Prescription(exerciseName: "Pull Up", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Weighted or bodyweight. Superset A2 with Military Press."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 10, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B1 with Chest-Supported Row."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 3, minimum: 10, maximum: 10, rpe: 8, restSeconds: 90, notes: "Superset B2 with Dumbbell Bench Press."),
                Prescription(exerciseName: "Lateral Raise", sets: 3, minimum: 12, maximum: 15, rpe: 9, restSeconds: 60, notes: nil)
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.ppl--u2013--push-day--u28-chest-u2c--shoulders-u2c--triceps-u29",
            name: "PPL – Push Day (Chest, Shoulders, Triceps)",
            prescriptions: [
                Prescription(exerciseName: "Bench Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Focus on controlled eccentric phase."),
                Prescription(exerciseName: "Dumbbell Incline Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Set bench to 30-degree incline."),
                Prescription(exerciseName: "Military Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Keep core braced throughout."),
                Prescription(exerciseName: "Lateral Raise", sets: 3, minimum: 12, maximum: 15, rpe: 9, restSeconds: 60, notes: "Slight forward torso lean."),
                Prescription(exerciseName: "Dip", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Bodyweight or weighted.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.ppl--u2013--pull-day--u28-back-u2c--rear-delts-u2c--biceps-u29",
            name: "PPL – Pull Day (Back, Rear Delts, Biceps)",
            prescriptions: [
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Torso at 45 degrees, pull to lower chest."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Full stretch at top of movement."),
                Prescription(exerciseName: "Face Pull", sets: 3, minimum: 12, maximum: 15, rpe: 8, restSeconds: 60, notes: "Pull toward forehead, hold contraction."),
                Prescription(exerciseName: "Barbell Curl", sets: 3, minimum: 10, maximum: 12, rpe: 8.5, restSeconds: 60, notes: "Strict form, avoid momentum."),
                Prescription(exerciseName: "Rear Delt Fly", sets: 3, minimum: 12, maximum: 15, rpe: 9, restSeconds: 60, notes: "Slight bend in elbows.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.ppl--u2013--leg-day--u28-quads-u2c--hamstrings-u2c--calves-u29",
            name: "PPL – Leg Day (Quads, Hamstrings, Calves)",
            prescriptions: [
                Prescription(exerciseName: "Front Squat", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Upright torso, full depth."),
                Prescription(exerciseName: "Barbell Hip Thrust", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Drive through heels, pause at top."),
                Prescription(exerciseName: "Leg Extension", sets: 3, minimum: 12, maximum: 15, rpe: 9, restSeconds: 90, notes: "Hold top contraction for 1 second."),
                Prescription(exerciseName: "Seated Leg Curl", sets: 3, minimum: 10, maximum: 12, rpe: 9, restSeconds: 90, notes: "Controlled negative."),
                Prescription(exerciseName: "Standing Calf Raise", sets: 3, minimum: 12, maximum: 15, rpe: 8.5, restSeconds: 60, notes: "Full stretch at bottom.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.full-body-a--u28-squat--u26--push-focus-u29",
            name: "Full Body A (Squat & Push Focus)",
            prescriptions: [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 10, maximum: 12, rpe: 8, restSeconds: 90, notes: "Heels elevated, dumbbell close to chest."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Neutral or 45-degree grip."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 90, notes: "Incline bench support."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 30, maximum: 45, rpe: 7, restSeconds: 60, notes: "Hold for 30-45 seconds.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.full-body-b--u28-hinge--u26--pull-focus-u29",
            name: "Full Body B (Hinge & Pull Focus)",
            prescriptions: [
                Prescription(exerciseName: "B-Stance RDL", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Hinge at hips, kickstand back foot."),
                Prescription(exerciseName: "Overhead Press", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Standing barbell press."),
                // "Pull Up" (unpunctuated), not "Pull-Up": that's the legacy
                // spelling ExerciseSeedData.templates() keeps as the seeded
                // Exercise.name after deduping it against
                // ExerciseCatalogSeedData's "Pull-Up" -- see
                // ExerciseSeedData.templates()'s comment. The catalog
                // spelling no longer exists as a seeded exercise, so a
                // Prescription naming it here would silently drop this
                // exercise from the template.
                Prescription(exerciseName: "Pull Up", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Full range of motion."),
                Prescription(exerciseName: "Hanging Knee Raise", sets: 3, minimum: 10, maximum: 12, rpe: 8, restSeconds: 60, notes: "Control the descent.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.simple-barbell-strength-a",
            name: "Simple Barbell Strength A",
            prescriptions: [
                Prescription(exerciseName: "Back Squat", sets: 3, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Drive out of the hole with chest up."),
                Prescription(exerciseName: "Bench Press", sets: 3, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Touch lower chest with control."),
                Prescription(exerciseName: "Deadlift", sets: 1, minimum: 5, maximum: 5, rpe: 7.5, restSeconds: 180, notes: "Single working set after thorough warm-up."),
                Prescription(exerciseName: "Lat Pulldown", sets: 2, minimum: 8, maximum: 12, rpe: 8, restSeconds: 90, notes: "Full overhead stretch.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.simple-barbell-strength-b",
            name: "Simple Barbell Strength B",
            prescriptions: [
                Prescription(exerciseName: "Back Squat", sets: 3, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Match Workout A stance and depth."),
                Prescription(exerciseName: "Overhead Press", sets: 3, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Strict press, brace glutes and core."),
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 6, maximum: 8, rpe: 7.5, restSeconds: 120, notes: "Torso at 45 degrees."),
                Prescription(exerciseName: "Romanian Deadlift", sets: 2, minimum: 8, maximum: 8, rpe: 7, restSeconds: 120, notes: "Focus on hamstring stretch.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.express-a",
            name: "Express A",
            prescriptions: [
                Prescription(exerciseName: "Leg Press", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 120, notes: "Full comfortable depth."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Neutral or 45-degree grip."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Incline bench chest support."),
                Prescription(exerciseName: "Romanian Deadlift", sets: 2, minimum: 8, maximum: 12, rpe: 7, restSeconds: 120, notes: "Hinge at hips."),
                Prescription(exerciseName: "Plank", sets: 2, minimum: 30, maximum: 45, rpe: 7, restSeconds: 60, notes: "Hold 30-45 seconds.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.express-b",
            name: "Express B",
            prescriptions: [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Heels elevated."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Seated chest up."),
                Prescription(exerciseName: "Dumbbell Shoulder Press", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Seated overhead press."),
                Prescription(exerciseName: "Barbell Hip Thrust", sets: 2, minimum: 10, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Pause at top."),
                Prescription(exerciseName: "Farmer's Carry", sets: 3, minimum: 20, maximum: 30, rpe: 7, restSeconds: 90, notes: "Walk 20-30 meters controlled.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.dumbbell-a",
            name: "Dumbbell A",
            prescriptions: [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 8, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Hold dumbbell at chest."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 8, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Use floor press if no bench is available."),
                Prescription(exerciseName: "Single-Arm Dumbbell Row", sets: 3, minimum: 8, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Support non-working hand on bench."),
                Prescription(exerciseName: "Romanian Deadlift", sets: 3, minimum: 8, maximum: 15, rpe: 7, restSeconds: 90, notes: "Keep dumbbells close to legs."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 20, maximum: 60, rpe: 7, restSeconds: 60, notes: "Hold 20-60 seconds.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.dumbbell-b",
            name: "Dumbbell B",
            prescriptions: [
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Work each leg."),
                Prescription(exerciseName: "Dumbbell Shoulder Press", sets: 3, minimum: 8, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Seated or standing."),
                Prescription(exerciseName: "Dumbbell Pullover", sets: 3, minimum: 10, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Controlled shoulder extension."),
                Prescription(exerciseName: "Barbell Hip Thrust", sets: 3, minimum: 10, maximum: 20, rpe: 7.5, restSeconds: 90, notes: "Use dumbbell across hips if needed."),
                Prescription(exerciseName: "Side Plank", sets: 3, minimum: 20, maximum: 45, rpe: 7, restSeconds: 60, notes: "Seconds per side.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.machine-a",
            name: "Machine A",
            prescriptions: [
                Prescription(exerciseName: "Leg Press", sets: 3, minimum: 10, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Symmetric foot placement."),
                Prescription(exerciseName: "Machine Chest Press", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Smooth, controlled press."),
                Prescription(exerciseName: "Seated Cable Row", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Brace feet and pull to torso."),
                Prescription(exerciseName: "Seated Leg Curl", sets: 2, minimum: 10, maximum: 15, rpe: 8, restSeconds: 60, notes: "Squeeze hamstrings."),
                Prescription(exerciseName: "Cable Chest Press", sets: 2, minimum: 10, maximum: 15, rpe: 7, restSeconds: 60, notes: "Anti-rotation/core control.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.machine-b",
            name: "Machine B",
            prescriptions: [
                Prescription(exerciseName: "Hack Squat", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 120, notes: "Full depth on machine track."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Pull smoothly to upper chest."),
                Prescription(exerciseName: "Machine Shoulder Press", sets: 3, minimum: 8, maximum: 12, rpe: 7.5, restSeconds: 90, notes: "Seated overhead press machine."),
                Prescription(exerciseName: "45-Degree Back Extension", sets: 2, minimum: 10, maximum: 15, rpe: 7, restSeconds: 90, notes: "Focus on glute squeeze."),
                Prescription(exerciseName: "Cable Crunch", sets: 2, minimum: 10, maximum: 15, rpe: 8, restSeconds: 60, notes: "Flex spine under cable load.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.calisthenics-a",
            name: "Calisthenics A",
            prescriptions: [
                Prescription(exerciseName: "Bodyweight Squat", sets: 3, minimum: 5, maximum: 12, rpe: 7, restSeconds: 60, notes: "Controlled depth."),
                Prescription(exerciseName: "Push-Up", sets: 3, minimum: 5, maximum: 12, rpe: 7, restSeconds: 60, notes: "Hands under shoulders."),
                Prescription(exerciseName: "Ring Row", sets: 3, minimum: 5, maximum: 12, rpe: 7, restSeconds: 60, notes: "Adjust incline to target rep count."),
                Prescription(exerciseName: "Single-Leg Glute Bridge", sets: 3, minimum: 8, maximum: 15, rpe: 7, restSeconds: 60, notes: "Work each leg."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 20, maximum: 60, rpe: 6, restSeconds: 60, notes: "Hold 20-60 seconds.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.calisthenics-b",
            name: "Calisthenics B",
            prescriptions: [
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 5, maximum: 12, rpe: 7, restSeconds: 60, notes: "Bodyweight split squat."),
                Prescription(exerciseName: "Pseudo Planche Push-Up", sets: 3, minimum: 5, maximum: 10, rpe: 7, restSeconds: 90, notes: "Lean forward to increase load."),
                Prescription(exerciseName: "Pull Up", sets: 3, minimum: 3, maximum: 8, rpe: 7, restSeconds: 90, notes: "Use assistance if needed."),
                Prescription(exerciseName: "Single-Leg Hip Hinge", sets: 3, minimum: 8, maximum: 12, rpe: 7, restSeconds: 60, notes: "Hinge on standing leg."),
                Prescription(exerciseName: "Side Plank", sets: 3, minimum: 20, maximum: 45, rpe: 6, restSeconds: 60, notes: "Seconds per side.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.powerlifting-day-1--u2014--squat-priority",
            name: "Powerlifting Day 1 — Squat Priority",
            prescriptions: [
                Prescription(exerciseName: "Back Squat", sets: 4, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "1x5 top set @ RPE 7, then 3x5 back-off sets."),
                Prescription(exerciseName: "Bench Press", sets: 4, minimum: 6, maximum: 6, rpe: 7, restSeconds: 180, notes: "Strict pause on chest."),
                Prescription(exerciseName: "Romanian Deadlift", sets: 3, minimum: 8, maximum: 8, rpe: 7.5, restSeconds: 150, notes: "Controlled eccentric."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 3, minimum: 8, maximum: 12, rpe: 8, restSeconds: 90, notes: "Upper back accessory."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 30, maximum: 45, rpe: 7, restSeconds: 60, notes: "Bracing stability.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.powerlifting-day-2--u2014--bench-priority",
            name: "Powerlifting Day 2 — Bench Priority",
            prescriptions: [
                Prescription(exerciseName: "Bench Press", sets: 4, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "1x5 top set @ RPE 7, then 3x5 back-off sets."),
                Prescription(exerciseName: "Pause Squat", sets: 3, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "2-second pause in bottom."),
                Prescription(exerciseName: "Overhead Press", sets: 3, minimum: 6, maximum: 10, rpe: 8, restSeconds: 120, notes: "Overhead strength accessory."),
                Prescription(exerciseName: "Lat Pulldown", sets: 3, minimum: 8, maximum: 12, rpe: 8, restSeconds: 90, notes: "Lat accessory."),
                Prescription(exerciseName: "Close-Grip Bench Press", sets: 2, minimum: 10, maximum: 15, rpe: 8, restSeconds: 90, notes: "Tricep accessory.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.powerlifting-day-3--u2014--deadlift-priority",
            name: "Powerlifting Day 3 — Deadlift Priority",
            prescriptions: [
                Prescription(exerciseName: "Deadlift", sets: 4, minimum: 4, maximum: 5, rpe: 7, restSeconds: 180, notes: "1x5 top set @ RPE 7, then 3x4 back-off sets."),
                Prescription(exerciseName: "Pause Bench Press", sets: 4, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Competition pause volume."),
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 8, maximum: 8, rpe: 8, restSeconds: 120, notes: "Unilateral leg strength."),
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 8, maximum: 12, rpe: 8, restSeconds: 120, notes: "Back thickness accessory."),
                Prescription(exerciseName: "Hanging Knee Raise", sets: 3, minimum: 8, maximum: 15, rpe: 8, restSeconds: 60, notes: "Core stability.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.olympic-day-1--u2014--snatch-positions",
            name: "Olympic Day 1 — Snatch Positions",
            prescriptions: [
                Prescription(exerciseName: "Muscle Snatch", sets: 3, minimum: 3, maximum: 3, rpe: 6, restSeconds: 90, notes: "Light technique load."),
                Prescription(exerciseName: "Hang Snatch", sets: 5, minimum: 2, maximum: 2, rpe: 6.5, restSeconds: 120, notes: "Above-knee position focus."),
                Prescription(exerciseName: "Overhead Squat", sets: 3, minimum: 3, maximum: 3, rpe: 6.5, restSeconds: 120, notes: "Position and balance control."),
                Prescription(exerciseName: "Front Squat", sets: 3, minimum: 5, maximum: 5, rpe: 7, restSeconds: 150, notes: "Squat strength base."),
                Prescription(exerciseName: "45-Degree Back Extension", sets: 3, minimum: 10, maximum: 15, rpe: 7.5, restSeconds: 90, notes: "Posterior chain accessory.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.olympic-day-2--u2014--clean--u26--jerk-positions",
            name: "Olympic Day 2 — Clean & Jerk Positions",
            prescriptions: [
                Prescription(exerciseName: "Hang Clean", sets: 5, minimum: 2, maximum: 2, rpe: 6.5, restSeconds: 120, notes: "Clean turnover practice."),
                Prescription(exerciseName: "Split Jerk", sets: 5, minimum: 2, maximum: 2, rpe: 6.5, restSeconds: 120, notes: "Footwork and extension."),
                Prescription(exerciseName: "Snatch Pull", sets: 3, minimum: 3, maximum: 3, rpe: 7, restSeconds: 150, notes: "Extension speed."),
                Prescription(exerciseName: "Bulgarian Split Squat", sets: 3, minimum: 8, maximum: 8, rpe: 7.5, restSeconds: 90, notes: "Single leg balance.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.olympic-day-3--u2014--lift-integration",
            name: "Olympic Day 3 — Lift Integration",
            prescriptions: [
                Prescription(exerciseName: "Snatch", sets: 5, minimum: 2, maximum: 2, rpe: 7, restSeconds: 150, notes: "Full snatch technique."),
                Prescription(exerciseName: "Clean and Jerk", sets: 5, minimum: 2, maximum: 2, rpe: 7, restSeconds: 180, notes: "Clean and jerk integration."),
                Prescription(exerciseName: "Back Squat", sets: 4, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Squat strength."),
                Prescription(exerciseName: "Barbell Row", sets: 3, minimum: 8, maximum: 10, rpe: 8, restSeconds: 120, notes: "Upper back strength.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.strongman-day-1--u2014--overhead-strength",
            name: "Strongman Day 1 — Overhead Strength",
            prescriptions: [
                Prescription(exerciseName: "Overhead Press", sets: 4, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Axle or barbell press."),
                Prescription(exerciseName: "Close-Grip Bench Press", sets: 3, minimum: 6, maximum: 8, rpe: 8, restSeconds: 120, notes: "Tricep press strength."),
                Prescription(exerciseName: "Chest-Supported Row", sets: 4, minimum: 8, maximum: 12, rpe: 8, restSeconds: 90, notes: "Upper back volume."),
                Prescription(exerciseName: "Dip", sets: 3, minimum: 10, maximum: 15, rpe: 8, restSeconds: 90, notes: "Press accessory."),
                Prescription(exerciseName: "Farmer's Carry", sets: 4, minimum: 20, maximum: 20, rpe: 7.5, restSeconds: 120, notes: "20-meter heavy carry.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.strongman-day-2--u2014--deadlift--u26--lower-body",
            name: "Strongman Day 2 — Deadlift & Lower Body",
            prescriptions: [
                Prescription(exerciseName: "Deadlift", sets: 4, minimum: 4, maximum: 4, rpe: 7, restSeconds: 180, notes: "Conventional or axle deadlift."),
                Prescription(exerciseName: "Front Squat", sets: 3, minimum: 5, maximum: 8, rpe: 7.5, restSeconds: 150, notes: "Front-rack quad strength."),
                Prescription(exerciseName: "Romanian Deadlift", sets: 3, minimum: 8, maximum: 8, rpe: 7.5, restSeconds: 120, notes: "Hamstrings and glutes."),
                Prescription(exerciseName: "Seated Leg Curl", sets: 3, minimum: 10, maximum: 15, rpe: 8, restSeconds: 90, notes: "Hamstring isolation."),
                Prescription(exerciseName: "Farmer's Carry", sets: 3, minimum: 20, maximum: 40, rpe: 8, restSeconds: 90, notes: "Grip hold/carry.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.strongman-day-3--u2014--events--u26--conditioning",
            name: "Strongman Day 3 — Events & Conditioning",
            prescriptions: [
                Prescription(exerciseName: "Farmer's Carry", sets: 4, minimum: 25, maximum: 30, rpe: 8, restSeconds: 150, notes: "25-30 meter loaded carry."),
                Prescription(exerciseName: "Power Clean", sets: 5, minimum: 3, maximum: 3, rpe: 7.5, restSeconds: 120, notes: "Explosive pull/load practice."),
                Prescription(exerciseName: "Single-Arm Dumbbell Row", sets: 3, minimum: 8, maximum: 12, rpe: 8, restSeconds: 90, notes: "Unilateral row strength."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 30, maximum: 45, rpe: 7, restSeconds: 60, notes: "Anti-extension core control.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.home-dumbbell-full-body",
            name: "Home Dumbbell Full Body",
            prescriptions: [
                Prescription(exerciseName: "Goblet Stiletto Squat", sets: 3, minimum: 10, maximum: 12, rpe: 7, restSeconds: 90, notes: "Keep the dumbbell close and move through a comfortable depth."),
                Prescription(exerciseName: "Dumbbell Bench Press", sets: 3, minimum: 8, maximum: 12, rpe: 7, restSeconds: 90, notes: "Use a floor press if a bench is unavailable."),
                Prescription(exerciseName: "B-Stance RDL", sets: 3, minimum: 8, maximum: 10, rpe: 7, restSeconds: 90, notes: "Use one or two dumbbells and keep the rear foot light."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 30, maximum: 45, rpe: 6, restSeconds: 60, notes: "Maintain steady breathing and a long spine.")
            ]
        ),
        TemplateDefinition(
            seedKey: "workout-template.calisthenics-beginner-full-body",
            name: "Calisthenics Beginner Full Body",
            prescriptions: [
                Prescription(exerciseName: "Bodyweight Squat", sets: 3, minimum: 10, maximum: 15, rpe: 6, restSeconds: 60, notes: "Use a chair or box target if needed."),
                Prescription(exerciseName: "Push-Up", sets: 3, minimum: 6, maximum: 12, rpe: 6, restSeconds: 60, notes: "Elevate the hands to make the movement easier."),
                // "Assisted Pull Up" (unpunctuated) -- see the "Pull Up" note
                // above; same legacy-vs-catalog spelling split applies here.
                Prescription(exerciseName: "Assisted Pull Up", sets: 3, minimum: 6, maximum: 10, rpe: 6, restSeconds: 90, notes: "Use assistance that allows smooth, controlled reps."),
                Prescription(exerciseName: "Single-Leg Glute Bridge", sets: 3, minimum: 10, maximum: 15, rpe: 6, restSeconds: 60, notes: "Pause briefly at the top."),
                Prescription(exerciseName: "Plank", sets: 3, minimum: 20, maximum: 30, rpe: 6, restSeconds: 60, notes: "Stop before form breaks down.")
            ]
        )
        ]

        #if DEBUG
        // Manual counterpart of `active-all-tracking-types`: selectable from
        // Train → Workouts so every Active Workout input surface can be tried
        // without launching through UI-test arguments. It is debug-only and
        // therefore never becomes part of the shipped built-in catalogue.
        values.append(
            TemplateDefinition(
                seedKey: "workout-template.debug-test-workout",
                name: "testWorkout",
                prescriptions: [
                    Prescription(exerciseName: "Bench Press", sets: 2, minimum: 8, maximum: 8, rpe: 7, restSeconds: 120, notes: "Weight and repetitions."),
                    Prescription(exerciseName: "Push-Up", sets: 2, minimum: 10, maximum: 10, rpe: 7, restSeconds: 60, notes: "Repetitions only."),
                    Prescription(exerciseName: "Weighted Pull-Up", sets: 2, minimum: 6, maximum: 6, rpe: 7, restSeconds: 90, notes: "Body weight plus added weight."),
                    Prescription(exerciseName: "Assisted Pull Up", sets: 2, minimum: 8, maximum: 8, rpe: 7, restSeconds: 90, notes: "Body weight with assistance."),
                    Prescription(exerciseName: "Plank", sets: 2, minimum: 90, maximum: 90, rpe: 7, restSeconds: 60, notes: "Duration; try typing 130 for 1:30."),
                    Prescription(exerciseName: "Treadmill Run", sets: 2, minimum: 90, maximum: 90, rpe: 7, restSeconds: 60, notes: "Duration and distance."),
                    Prescription(exerciseName: "Stationary Bike", sets: 2, minimum: 100, maximum: 100, rpe: 7, restSeconds: 60, notes: "Calories.")
                ]
            )
        )
        #endif

        return values
    }

    static func seededTemplates(using exercises: [Exercise]) -> [(seedKey: String, template: WorkoutTemplate)] {
        let exercisesByName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return definitions.compactMap { definition -> (seedKey: String, template: WorkoutTemplate)? in
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
            return (
                seedKey: definition.seedKey,
                template: WorkoutTemplate(
                    name: definition.name,
                    exercises: selectedExercises,
                    templateExercises: templateExercises
                )
            )
        }
    }

    static func templates(using exercises: [Exercise]) -> [WorkoutTemplate] {
        seededTemplates(using: exercises).map(\.template)
    }
}

@MainActor
enum WorkoutTemplateMobilitySeedLinker {
    private struct ResolvedLink {
        let definition: WorkoutTemplateSeedData.MobilityLinkDefinition
        let template: WorkoutTemplate
        let preRoutine: MobilityRoutine?
        let postRoutine: MobilityRoutine?
    }

    /// Resolves the complete manifest-backed link graph before mutating any
    /// template or definition slot. Active run slots are immutable evidence
    /// and are intentionally outside this migration.
    static func apply(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        try registry.validateUniqueKeys(WorkoutTemplateSeedData.mobilityLinks.map(\.templateSeedKey))

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        let resolvedLinks = try WorkoutTemplateSeedData.mobilityLinks.map { definition in
            let template = try resolveTemplate(
                definition.templateSeedKey,
                templates: templates,
                registry: registry
            )
            let preRoutine = try resolveRoutine(
                definition.preRoutineSeedKey,
                ownerKey: definition.templateSeedKey,
                routines: routines,
                registry: registry
            )
            let postRoutine = try resolveRoutine(
                definition.postRoutineSeedKey,
                ownerKey: definition.templateSeedKey,
                routines: routines,
                registry: registry
            )
            return ResolvedLink(
                definition: definition,
                template: template,
                preRoutine: preRoutine,
                postRoutine: postRoutine
            )
        }

        let planRecords = try context.fetch(FetchDescriptor<SystemSeedRecord>())
            .filter { $0.entityKind == .repeatingPlan && $0.isSystemProvided }
        let plans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        let seededPlans = try planRecords.map { record -> RepeatingPlan in
            guard let plan = plans.first(where: { $0.id == record.entityID }) else {
                throw SystemSeedError.danglingEntity(key: record.seedKey, entityID: record.entityID)
            }
            return plan
        }

        var report = SystemSeedInstallReport()
        for link in resolvedLinks {
            if link.template.preWorkoutMobilityRoutine?.id != link.preRoutine?.id
                || link.template.postWorkoutMobilityRoutine?.id != link.postRoutine?.id {
                link.template.preWorkoutMobilityRoutine = link.preRoutine
                link.template.postWorkoutMobilityRoutine = link.postRoutine
                report.updated += 1
            } else {
                report.unchanged += 1
            }

            for plan in seededPlans {
                for slot in plan.slots where slot.templateIDSnapshot == link.template.id {
                    slot.preWorkoutMobilityRoutine = link.preRoutine
                    slot.preWorkoutMobilityRoutineIDSnapshot = link.preRoutine?.id
                    slot.preWorkoutMobilityRoutineNameSnapshot = link.preRoutine?.name
                    slot.postWorkoutMobilityRoutine = link.postRoutine
                    slot.postWorkoutMobilityRoutineIDSnapshot = link.postRoutine?.id
                    slot.postWorkoutMobilityRoutineNameSnapshot = link.postRoutine?.name
                }
            }
        }
        return report
    }

    private static func resolveTemplate(
        _ key: String,
        templates: [WorkoutTemplate],
        registry: SystemSeedRegistry
    ) throws -> WorkoutTemplate {
        guard
            let record = try registry.record(for: key, expectedKind: .workoutTemplate),
            let template = templates.first(where: { $0.id == record.entityID })
        else {
            throw SystemSeedError.unresolvedDependency(key: key, dependency: key)
        }
        return template
    }

    private static func resolveRoutine(
        _ key: String?,
        ownerKey: String,
        routines: [MobilityRoutine],
        registry: SystemSeedRegistry
    ) throws -> MobilityRoutine? {
        guard let key else { return nil }
        guard
            let record = try registry.record(for: key, expectedKind: .mobilityRoutine),
            let routine = routines.first(where: { $0.id == record.entityID })
        else {
            throw SystemSeedError.unresolvedDependency(key: ownerKey, dependency: key)
        }
        return routine
    }
}

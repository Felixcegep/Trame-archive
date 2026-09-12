#if DEBUG
import Foundation
import SwiftData

enum StrengthStabilityProgramSeederError: LocalizedError {
    case missingCatalogueNames([String])

    var errorDescription: String? {
        switch self {
        case .missingCatalogueNames(let names):
            let sorted = names.sorted()
            return "Missing catalogue exercises or mobility definitions: \(sorted.joined(separator: ", "))."
        }
    }
}

/// DEBUG-only personal repeating strength program seeded on demand from
/// Settings → Advanced. Not part of the bundled system catalogue.
@MainActor
enum StrengthStabilityProgramSeeder {
    static let planName = "Strength & Stability"
    static let seedMarker = "strength-stability-dev-seed"

    static let templateNames = [
        "Upper / OHP",
        "Lower / Quads + Abductors",
        "Upper / Bench",
        "Posterior Chain / Deadlift + Abductors"
    ]

    private struct Prescription {
        let candidateNames: [String]
        let label: String
        let sets: Int
        let minimum: Int
        let maximum: Int
        let rpe: Double?
        let restSeconds: Int
        let notes: String?
        let stimulus: TrainingStimulus?

        init(
            _ candidateNames: [String],
            label: String? = nil,
            sets: Int,
            minimum: Int,
            maximum: Int,
            rpe: Double? = nil,
            restSeconds: Int = 90,
            notes: String? = nil,
            stimulus: TrainingStimulus? = nil
        ) {
            self.candidateNames = candidateNames
            self.label = label ?? candidateNames.first ?? "Exercise"
            self.sets = sets
            self.minimum = minimum
            self.maximum = maximum
            self.rpe = rpe
            self.restSeconds = restSeconds
            self.notes = notes
            self.stimulus = stimulus
        }
    }

    private struct MobilityItemSpec {
        let definitionName: String
        let repetitions: Int?
        let durationSeconds: Int?
        let side: MobilitySide
        let cycleCount: Int
        let notes: String?
    }

    private struct MobilityRoutineSpec {
        let name: String
        let purpose: MobilityRoutinePurpose
        let notes: String?
        let items: [MobilityItemSpec]
    }

    static func seed(in context: ModelContext) throws {
        try removePreviousSeed(from: context)

        var exercises = try context.fetch(FetchDescriptor<Exercise>())
        if !exercises.contains(where: { CatalogueResolver.normalized($0.name) == CatalogueResolver.normalized("Pallof Press") }) {
            let pallof = Exercise(
                name: "Pallof Press",
                primaryMuscles: [.obliques, .transverseAbdominis],
                secondaryMuscles: [.rectusAbdominis, .gluteMedius],
                trackingType: .weightAndReps,
                equipmentType: .cable,
                resistanceType: .machine,
                movementPattern: .antiRotation,
                forceType: .push,
                mechanics: .isolation,
                stance: .standing,
                isCustom: true,
                laterality: .unilateral,
                repCountingStyle: .perSide
            )
            pallof.searchAliases = ["pallof", "anti rotation press"]
            context.insert(pallof)
            exercises.append(pallof)
        }
        let mobilityDefinitions = try context.fetch(FetchDescriptor<MobilityDefinition>())
        let resolver = CatalogueResolver(exercises: exercises, mobilityDefinitions: mobilityDefinitions)

        let recoveryRoutine = try makeMobilityRoutine(
            spec: MobilityRoutineSpec(
                name: "Strength & Stability recovery",
                purpose: .development,
                notes: "Optional recovery. 5 min easy cardio before the stretch.",
                items: [
                    MobilityItemSpec(definitionName: "90/90 Hip Switch", repetitions: 8, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "Couch Stretch", repetitions: nil, durationSeconds: 30, side: .bilateral, cycleCount: 1, notes: "Per side."),
                    MobilityItemSpec(definitionName: "Knee-to-Wall Ankle Mobilization", repetitions: 10, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil)
                ]
            ),
            resolver: resolver,
            context: context
        )

        let ohpMobility = try makeMobilityRoutine(
            spec: MobilityRoutineSpec(
                name: "Strength & Stability — OHP prep",
                purpose: .preparation,
                notes: nil,
                items: [
                    MobilityItemSpec(definitionName: "Thoracic Rotation", repetitions: 8, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "Wall Slides", repetitions: 10, durationSeconds: nil, side: .bilateral, cycleCount: 2, notes: nil)
                ]
            ),
            resolver: resolver,
            context: context
        )

        let squatMobility = try makeMobilityRoutine(
            spec: MobilityRoutineSpec(
                name: "Strength & Stability — Squat prep",
                purpose: .preparation,
                notes: nil,
                items: [
                    MobilityItemSpec(definitionName: "Knee-to-Wall Ankle Mobilization", repetitions: 10, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "90/90 Hip Switch", repetitions: 8, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "Tactical Frog", repetitions: 10, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: "Adductor rock back."),
                    MobilityItemSpec(definitionName: "Fire Hydrants", repetitions: 10, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: "Abductor activation.")
                ]
            ),
            resolver: resolver,
            context: context
        )

        let benchMobility = try makeMobilityRoutine(
            spec: MobilityRoutineSpec(
                name: "Strength & Stability — Bench prep",
                purpose: .preparation,
                notes: nil,
                items: [
                    MobilityItemSpec(definitionName: "Thoracic Rotation", repetitions: 8, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "Shoulder CARs", repetitions: 5, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "Wall Slides", repetitions: 10, durationSeconds: nil, side: .bilateral, cycleCount: 1, notes: "Optional.")
                ]
            ),
            resolver: resolver,
            context: context
        )

        let deadliftMobility = try makeMobilityRoutine(
            spec: MobilityRoutineSpec(
                name: "Strength & Stability — Deadlift prep",
                purpose: .preparation,
                notes: nil,
                items: [
                    MobilityItemSpec(definitionName: "90/90 Hip Switch", repetitions: 8, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil),
                    MobilityItemSpec(definitionName: "Tactical Frog", repetitions: 10, durationSeconds: nil, side: .alternating, cycleCount: 1, notes: nil)
                ]
            ),
            resolver: resolver,
            context: context
        )

        let posteriorPrescriptions: [Prescription] = [
            Prescription(["Glute Bridge"], sets: 2, minimum: 10, maximum: 10, notes: "Warm-up / activation."),
            Prescription(["Bird Dog"], sets: 2, minimum: 6, maximum: 6, notes: "Warm-up / activation. Per side."),
            Prescription(
                ["Deadlift"],
                sets: 3,
                minimum: 5,
                maximum: 5,
                rpe: 6.5,
                restSeconds: 180,
                notes: deadliftNotes(),
                stimulus: .strength
            ),
            Prescription(["Leg Curl", "Seated Leg Curl"], label: "Leg Curl", sets: 3, minimum: 10, maximum: 15, notes: "Double progression on accessories.", stimulus: .hypertrophy),
            Prescription(["Barbell Hip Thrust"], sets: 3, minimum: 8, maximum: 10, notes: "Double progression on accessories.", stimulus: .hypertrophy),
            Prescription(["Hip Abduction Machine"], sets: 3, minimum: 15, maximum: 20, notes: "Double progression on accessories.", stimulus: .hypertrophy),
            Prescription(["Pallof Press"], sets: 3, minimum: 10, maximum: 15, notes: "Per side. Anti-rotation trunk stability.", stimulus: .hypertrophy)
        ]

        let templates: [(name: String, prescriptions: [Prescription], mobility: MobilityRoutine)] = [
            (
                templateNames[0],
                [
                    Prescription(["Band Pull-Apart"], sets: 2, minimum: 15, maximum: 15, notes: "Warm-up / activation."),
                    Prescription(["Overhead Press"], sets: 4, minimum: 5, maximum: 6, rpe: 7, restSeconds: 180, notes: "Main lift. RPE 6–8. 3–4 progressive warm-up sets. Keep technically clean.", stimulus: .strength),
                    Prescription(["Chest-Supported Row"], sets: 3, minimum: 8, maximum: 10, notes: "Chest support reduces lower-back fatigue.", stimulus: .hypertrophy),
                    Prescription(["Dumbbell Incline Press", "Incline Dumbbell Bench Press"], label: "Incline DB Press", sets: 3, minimum: 8, maximum: 10, stimulus: .hypertrophy),
                    Prescription(["Lat Pulldown"], sets: 3, minimum: 8, maximum: 12, stimulus: .hypertrophy),
                    Prescription(["Lateral Raise"], sets: 3, minimum: 15, maximum: 20, stimulus: .hypertrophy),
                    Prescription(["Barbell Curl"], sets: 3, minimum: 10, maximum: 15, notes: "Direct biceps; triceps already get OHP/incline work.", stimulus: .hypertrophy)
                ],
                ohpMobility
            ),
            (
                templateNames[1],
                [
                    Prescription(["Bodyweight Squat"], sets: 1, minimum: 10, maximum: 10, notes: "Warm-up / activation."),
                    Prescription(["High-Bar Back Squat"], sets: 4, minimum: 5, maximum: 5, rpe: 7, restSeconds: 180, notes: "Main lift. RPE 6–8. 3–4 progressive warm-up sets. Start unilateral work later on the left.", stimulus: .strength),
                    Prescription(["Bulgarian Split Squat"], sets: 3, minimum: 8, maximum: 8, notes: "Per leg. Start left, match right. Keep pelvis stable.", stimulus: .hypertrophy),
                    Prescription(["Leg Extension"], sets: 3, minimum: 10, maximum: 15, notes: "Preferred over leg press here.", stimulus: .hypertrophy),
                    Prescription(["Hip Abduction Machine"], sets: 3, minimum: 15, maximum: 20, stimulus: .hypertrophy),
                    Prescription(["Side Plank"], sets: 3, minimum: 30, maximum: 45, notes: "30–45 sec per side.", stimulus: .hypertrophy)
                ],
                squatMobility
            ),
            (
                templateNames[2],
                [
                    Prescription(["Band Pull-Apart"], sets: 2, minimum: 15, maximum: 15, notes: "Warm-up / activation."),
                    Prescription(["Bench Press"], sets: 4, minimum: 5, maximum: 6, rpe: 7, restSeconds: 180, notes: "Main lift. RPE 6–8. 3–4 progressive warm-up sets.", stimulus: .strength),
                    Prescription(["Seated Cable Row"], sets: 3, minimum: 8, maximum: 12, stimulus: .hypertrophy),
                    Prescription(["Pull Up"], sets: 3, minimum: 8, maximum: 12, stimulus: .hypertrophy),
                    Prescription(["Dumbbell Shoulder Press", "Military Press", "Overhead Press"], label: "Seated DB OHP", sets: 3, minimum: 8, maximum: 10, notes: "Lighter secondary shoulder work.", stimulus: .hypertrophy),
                    Prescription(["Rear Delt Fly"], sets: 3, minimum: 15, maximum: 20, stimulus: .hypertrophy),
                    Prescription(["Triceps Pushdown"], sets: 3, minimum: 10, maximum: 15, stimulus: .hypertrophy)
                ],
                benchMobility
            ),
            (
                templateNames[3],
                posteriorPrescriptions,
                deadliftMobility
            )
        ]

        let builtTemplates: [WorkoutTemplate] = try templates.map { name, prescriptions, mobility in
            let template = WorkoutTemplate(
                name: name,
                exercises: [],
                templateExercises: try makeTemplateExercises(prescriptions, resolver: resolver),
                isBuiltIn: false
            )
            context.insert(template)
            try WorkoutMobilityLinkService.set(mobility, for: .beforeWorkout, on: template, using: context)
            return template
        }

        let slots = builtTemplates.enumerated().map { index, template in
            RepeatingPlanSlot(orderIndex: index, workoutTemplate: template)
        }

        let plan = RepeatingPlan(
            name: planName,
            goal: .generalStrength,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell, .dumbbell, .cable, .machine, .other],
            notes: planNotes(),
            isBuiltIn: false,
            slots: slots
        )
        context.insert(plan)
        context.insert(recoveryRoutine)

        for slot in slots {
            if let routine = slot.preWorkoutMobilityRoutine {
                try WorkoutMobilityLinkService.set(routine, for: .beforeWorkout, on: slot, using: context)
            }
        }

        try context.save()
    }

    private static func deadliftNotes() -> String {
        "Main lift. RPE 6–7. Moderate load, no grinders. Symmetrical setup. Reduce load if left lower back takes over. Do not stack RDL/back extension/reverse hyper. 3–4 progressive warm-up sets."
    }

    private static func planNotes() -> String {
        """
        Train these four sessions in order whenever you train: Upper / OHP → Lower / Quads + Abductors → Upper / Bench → Posterior Chain / Deadlift + Abductors. Rest days are optional walking/hip mobility, not extra sessions.

        Goals: strength and hypertrophy with hip abductors, pelvic stability, posterior chain work, and reducing left-lower-back compensation. Main lifts at RPE 6–8 (deadlift 6–7). Double progression on accessories. Start unilateral work on the left and match the right. Do not aggressively stretch the lumbar spine.

        \(seedMarker)
        """
    }

    private static func removePreviousSeed(from context: ModelContext) throws {
        let plans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        for plan in plans where !plan.isBuiltIn && plan.name == planName {
            context.delete(plan)
        }

        let knownTemplateNames = Set(templateNames)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        for template in templates where !template.isBuiltIn && knownTemplateNames.contains(template.name) {
            context.delete(template)
        }

        let routineNamePrefixes = [
            "Strength & Stability —",
            "Strength & Stability recovery"
        ]
        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        for routine in routines where routineNamePrefixes.contains(where: { routine.name.hasPrefix($0) || routine.name == $0 }) {
            context.delete(routine)
        }

        try context.save()
    }

    private static func makeTemplateExercises(
        _ prescriptions: [Prescription],
        resolver: CatalogueResolver
    ) throws -> [TemplateExercise] {
        try prescriptions.enumerated().map { index, prescription in
            let exercise = try resolver.requireExercise(prescription.candidateNames, label: prescription.label)
            return TemplateExercise(
                exercise: exercise,
                order: index,
                targetSets: prescription.sets,
                repRangeMinimum: prescription.minimum,
                repRangeMaximum: prescription.maximum,
                restSeconds: prescription.restSeconds,
                targetRPE: prescription.rpe,
                notes: prescription.notes,
                stimulus: prescription.stimulus
            )
        }
    }

    private static func makeMobilityRoutine(
        spec: MobilityRoutineSpec,
        resolver: CatalogueResolver,
        context: ModelContext
    ) throws -> MobilityRoutine {
        let routine = MobilityRoutine(name: spec.name, notes: spec.notes, purpose: spec.purpose)
        routine.items = try spec.items.enumerated().map { index, item in
            let definition = try resolver.requireMobilityDefinition(item.definitionName)
            let routineItem = MobilityRoutineItem(
                definition: definition,
                orderIndex: index,
                targetDurationSeconds: item.durationSeconds,
                targetRepetitions: item.repetitions,
                side: item.side,
                notes: item.notes
            )
            routineItem.cycleCount = item.cycleCount
            return routineItem
        }
        context.insert(routine)
        return routine
    }

    private struct CatalogueResolver {
        private let exercisesByKey: [String: Exercise]
        private let mobilityByKey: [String: MobilityDefinition]

        init(exercises: [Exercise], mobilityDefinitions: [MobilityDefinition]) {
            exercisesByKey = Self.index(exercises) { exercise in
                [exercise.name] + exercise.searchAliases
            }
            mobilityByKey = Self.index(mobilityDefinitions) { definition in
                [definition.name]
            }
        }

        func requireExercise(_ candidates: [String], label: String) throws -> Exercise {
            if let exercise = optionalExercise(candidates) {
                return exercise
            }
            throw StrengthStabilityProgramSeederError.missingCatalogueNames([label])
        }

        func optionalExercise(_ candidates: [String]) -> Exercise? {
            for candidate in candidates {
                if let exercise = exercisesByKey[Self.normalized(candidate)] {
                    return exercise
                }
            }
            return nil
        }

        func requireMobilityDefinition(_ name: String) throws -> MobilityDefinition {
            if let definition = mobilityByKey[Self.normalized(name)] {
                return definition
            }
            throw StrengthStabilityProgramSeederError.missingCatalogueNames([name])
        }

        private static func index<T>(_ values: [T], names: (T) -> [String]) -> [String: T] {
            var result: [String: T] = [:]
            for value in values {
                for name in names(value) {
                    result[normalized(name)] = value
                }
            }
            return result
        }

        static func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }
    }
}
#endif

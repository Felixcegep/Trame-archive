//
//  ExerciseCatalogSeedData.swift
//  GymTracker
//
//  The first 50 entries from GymTracker_200_Exercises_import_ready.json.
//  Research aliases and rationales remain in the source metadata file until
//  the exercise model gains first-class alias/provenance fields.
//

enum ExerciseCatalogSeedData {
    private struct Definition {
        let name: String
        let primaryMuscles: [Muscle]
        let secondaryMuscles: [Muscle]?
        let category: ExerciseCategory
        let trackingType: TrackingType
        let equipmentType: EquipmentType
        let resistanceType: ResistanceType
        let movementPattern: MovementPattern
        let forceType: ForceType
        let mechanics: ExerciseMechanics
        let gripStyle: GripStyle?
        let stance: ExerciseStance?
        let rangeOfMotion: RangeOfMotion?
        let setupAngleDegrees: Int?
        let variationFamilyID: String?
        let difficulty: Difficulty
        let tags: [String]
        let isPlateLoaded: Bool?
        let laterality: Laterality
        let repCountingStyle: RepCountingStyle
        let weightEntryStyle: WeightEntryStyle
        let loadUnitCount: Int

        init(
            name: String,
            primaryMuscles: [Muscle],
            secondaryMuscles: [Muscle]? = nil,
            category: ExerciseCategory = .strength,
            trackingType: TrackingType = .weightAndReps,
            equipmentType: EquipmentType,
            resistanceType: ResistanceType,
            movementPattern: MovementPattern,
            forceType: ForceType,
            mechanics: ExerciseMechanics,
            gripStyle: GripStyle? = nil,
            stance: ExerciseStance? = nil,
            rangeOfMotion: RangeOfMotion? = nil,
            setupAngleDegrees: Int? = nil,
            variationFamilyID: String? = nil,
            difficulty: Difficulty,
            tags: [String],
            isPlateLoaded: Bool? = nil,
            laterality: Laterality = .bilateral,
            repCountingStyle: RepCountingStyle = .total,
            weightEntryStyle: WeightEntryStyle = .totalLoad,
            loadUnitCount: Int = 1
        ) {
            self.name = name
            self.primaryMuscles = primaryMuscles
            self.secondaryMuscles = secondaryMuscles
            self.category = category
            self.trackingType = trackingType
            self.equipmentType = equipmentType
            self.resistanceType = resistanceType
            self.movementPattern = movementPattern
            self.forceType = forceType
            self.mechanics = mechanics
            self.gripStyle = gripStyle
            self.stance = stance
            self.rangeOfMotion = rangeOfMotion
            self.setupAngleDegrees = setupAngleDegrees
            self.variationFamilyID = variationFamilyID
            self.difficulty = difficulty
            self.tags = tags
            self.isPlateLoaded = isPlateLoaded
            self.laterality = laterality
            self.repCountingStyle = repCountingStyle
            self.weightEntryStyle = weightEntryStyle
            self.loadUnitCount = loadUnitCount
        }

        func makeExercise() -> Exercise {
            Exercise(
                name: name,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                category: category,
                trackingType: trackingType,
                equipmentType: equipmentType,
                resistanceType: resistanceType,
                movementPattern: movementPattern,
                forceType: forceType,
                mechanics: mechanics,
                gripStyle: gripStyle,
                stance: stance,
                rangeOfMotion: rangeOfMotion,
                setupAngleDegrees: setupAngleDegrees,
                variationFamilyID: variationFamilyID,
                difficulty: difficulty,
                tags: tags,
                isPlateLoaded: isPlateLoaded,
                laterality: laterality,
                repCountingStyle: repCountingStyle,
                weightEntryStyle: weightEntryStyle,
                loadUnitCount: loadUnitCount
            )
        }
    }

    static func templates() -> [Exercise] {
        definitions.map { $0.makeExercise() }
    }

    private static let definitions: [Definition] = [
        // Horizontal push
        .init(name: "Bench Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 0, variationFamilyID: "bench-press", difficulty: .intermediate, tags: ["bench-press", "barbell", "horizontal-push", "middlechest", "compound"], isPlateLoaded: true),
        .init(name: "Incline Bench Press", primaryMuscles: [.upperChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 30, variationFamilyID: "incline-bench-press", difficulty: .intermediate, tags: ["incline-bench-press", "barbell", "horizontal-push", "upperchest", "compound"], isPlateLoaded: true),
        .init(name: "Close-Grip Bench Press", primaryMuscles: [.tricepLateralHead], secondaryMuscles: [.middleChest, .frontDeltoid, .tricepLongHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, variationFamilyID: "bench-press", difficulty: .intermediate, tags: ["close-grip-bench-press", "barbell", "horizontal-push", "triceplateralhead", "compound"], isPlateLoaded: true),
        .init(name: "Floor Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .partial, setupAngleDegrees: 0, variationFamilyID: "floor-press", difficulty: .intermediate, tags: ["floor-press", "barbell", "horizontal-push", "middlechest", "compound"], isPlateLoaded: true),
        .init(name: "Dumbbell Bench Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 0, variationFamilyID: "dumbbell-bench-press", difficulty: .intermediate, tags: ["dumbbell-bench-press", "dumbbell", "horizontal-push", "middlechest", "compound"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Incline Dumbbell Bench Press", primaryMuscles: [.upperChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 30, variationFamilyID: "incline-dumbbell-bench-press", difficulty: .intermediate, tags: ["incline-dumbbell-bench-press", "dumbbell", "horizontal-push", "upperchest", "compound"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Dumbbell Floor Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .partial, setupAngleDegrees: 0, variationFamilyID: "dumbbell-floor-press", difficulty: .intermediate, tags: ["dumbbell-floor-press", "dumbbell", "horizontal-push", "middlechest", "compound"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Smith Machine Bench Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .machine, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 0, variationFamilyID: "smith-machine-bench-press", difficulty: .intermediate, tags: ["smith-machine-bench-press", "machine", "horizontal-push", "middlechest", "compound"], isPlateLoaded: true),
        .init(name: "Machine Chest Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .machine, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 0, variationFamilyID: "machine-chest-press", difficulty: .intermediate, tags: ["machine-chest-press", "machine", "horizontal-push", "middlechest", "compound"]),
        .init(name: "Cable Chest Press", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], equipmentType: .cable, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "cable-chest-press", difficulty: .intermediate, tags: ["cable-chest-press", "cable", "horizontal-push", "middlechest", "compound"]),
        .init(name: "Push-Up", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .prone, rangeOfMotion: .full, variationFamilyID: "push-up", difficulty: .beginner, tags: ["push-up", "bodyweight", "horizontal-push", "middlechest", "compound"]),
        .init(name: "Incline Push-Up", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .prone, rangeOfMotion: .full, setupAngleDegrees: 30, variationFamilyID: "push-up", difficulty: .beginner, tags: ["incline-push-up", "bodyweight", "horizontal-push", "middlechest", "compound"]),
        .init(name: "Decline Push-Up", primaryMuscles: [.upperChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .prone, rangeOfMotion: .full, setupAngleDegrees: -30, variationFamilyID: "push-up", difficulty: .intermediate, tags: ["decline-push-up", "bodyweight", "horizontal-push", "upperchest", "compound"]),
        .init(name: "Weighted Push-Up", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead], trackingType: .weightedBodyweight, equipmentType: .bodyweight, resistanceType: .weightedBodyweight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .prone, rangeOfMotion: .full, variationFamilyID: "push-up", difficulty: .advanced, tags: ["weighted-push-up", "bodyweight", "horizontal-push", "middlechest", "compound"]),
        .init(name: "Chest Fly", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .supine, rangeOfMotion: .full, setupAngleDegrees: 0, variationFamilyID: "chest-fly", difficulty: .beginner, tags: ["chest-fly", "dumbbell", "horizontal-push", "middlechest", "isolation"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Cable Fly", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid], equipmentType: .cable, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "cable-fly", difficulty: .beginner, tags: ["cable-fly", "cable", "horizontal-push", "middlechest", "isolation"]),
        .init(name: "Low-to-High Cable Fly", primaryMuscles: [.upperChest], secondaryMuscles: [.frontDeltoid], equipmentType: .cable, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: 30, variationFamilyID: "low-to-high-cable-fly", difficulty: .beginner, tags: ["low-to-high-cable-fly", "cable", "horizontal-push", "upperchest", "isolation"]),
        .init(name: "High-to-Low Cable Fly", primaryMuscles: [.lowerChest], secondaryMuscles: [.frontDeltoid], equipmentType: .cable, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: -30, variationFamilyID: "high-to-low-cable-fly", difficulty: .beginner, tags: ["high-to-low-cable-fly", "cable", "horizontal-push", "lowerchest", "isolation"]),
        .init(name: "Pec Deck Fly", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid], equipmentType: .machine, resistanceType: .machine, movementPattern: .horizontalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, setupAngleDegrees: 0, variationFamilyID: "pec-deck-fly", difficulty: .beginner, tags: ["pec-deck-fly", "machine", "horizontal-push", "middlechest", "isolation"]),
        .init(name: "Medicine Ball Chest Pass", primaryMuscles: [.middleChest], secondaryMuscles: [.frontDeltoid, .tricepLateralHead, .rectusAbdominis], category: .sport, equipmentType: .medicineBall, resistanceType: .externalWeight, movementPattern: .horizontalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "medicine-ball-chest-pass", difficulty: .intermediate, tags: ["medicine-ball-chest-pass", "medicine-ball", "horizontal-push", "middlechest", "compound", "sport"], weightEntryStyle: .perLoadUnit),

        // Vertical push and shoulder accessories
        .init(name: "Overhead Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "overhead-press", difficulty: .intermediate, tags: ["overhead-press", "barbell", "vertical-push", "frontdeltoid", "compound"], isPlateLoaded: true),
        .init(name: "Seated Overhead Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .pronated, stance: .seated, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "seated-overhead-press", difficulty: .intermediate, tags: ["seated-overhead-press", "barbell", "vertical-push", "frontdeltoid", "compound"], isPlateLoaded: true),
        .init(name: "Push Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.frontDeltoid, .tricepLateralHead, .quadriceps, .gluteMaximus], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .mixed, mechanics: .compound, gripStyle: .pronated, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "push-press", difficulty: .advanced, tags: ["push-press", "barbell", "vertical-push", "frontdeltoid", "compound"], isPlateLoaded: true),
        .init(name: "Dumbbell Shoulder Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "dumbbell-shoulder-press", difficulty: .intermediate, tags: ["dumbbell-shoulder-press", "dumbbell", "vertical-push", "frontdeltoid", "compound"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Arnold Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .mixed, stance: .seated, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "arnold-press", difficulty: .intermediate, tags: ["arnold-press", "dumbbell", "vertical-push", "frontdeltoid", "compound"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Single-Arm Dumbbell Shoulder Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "single-arm-dumbbell-shoulder-press", difficulty: .intermediate, tags: ["single-arm-dumbbell-shoulder-press", "dumbbell", "vertical-push", "frontdeltoid", "compound"], laterality: .unilateral, repCountingStyle: .perSide, weightEntryStyle: .perLoadUnit),
        .init(name: "Machine Shoulder Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .machine, resistanceType: .machine, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "machine-shoulder-press", difficulty: .intermediate, tags: ["machine-shoulder-press", "machine", "vertical-push", "frontdeltoid", "compound"]),
        .init(name: "Smith Machine Overhead Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.lateralDeltoid, .tricepLateralHead, .tricepLongHead], equipmentType: .machine, resistanceType: .machine, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, setupAngleDegrees: 90, variationFamilyID: "smith-machine-overhead-press", difficulty: .intermediate, tags: ["smith-machine-overhead-press", "machine", "vertical-push", "frontdeltoid", "compound"]),
        .init(name: "Landmine Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.upperChest, .tricepLateralHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: 45, variationFamilyID: "landmine-press", difficulty: .intermediate, tags: ["landmine-press", "barbell", "vertical-push", "frontdeltoid", "compound"], isPlateLoaded: true),
        .init(name: "Single-Arm Landmine Press", primaryMuscles: [.frontDeltoid], secondaryMuscles: [.upperChest, .tricepLateralHead], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .compound, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, setupAngleDegrees: 45, variationFamilyID: "single-arm-landmine-press", difficulty: .intermediate, tags: ["single-arm-landmine-press", "barbell", "vertical-push", "frontdeltoid", "compound"], isPlateLoaded: true, laterality: .unilateral, repCountingStyle: .perSide),
        .init(name: "Lateral Raise", primaryMuscles: [.lateralDeltoid], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "lateral-raise", difficulty: .beginner, tags: ["lateral-raise", "dumbbell", "vertical-push", "lateraldeltoid", "isolation"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Front Raise", primaryMuscles: [.frontDeltoid], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .verticalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "front-raise", difficulty: .beginner, tags: ["front-raise", "dumbbell", "vertical-push", "frontdeltoid", "isolation"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Rear Delt Fly", primaryMuscles: [.rearDeltoid], secondaryMuscles: [.trapezius, .rhomboids], equipmentType: .dumbbell, resistanceType: .externalWeight, movementPattern: .horizontalPull, forceType: .pull, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "rear-delt-fly", difficulty: .beginner, tags: ["rear-delt-fly", "dumbbell", "horizontal-pull", "reardeltoid", "isolation"], weightEntryStyle: .perLoadUnit, loadUnitCount: 2),
        .init(name: "Cable Lateral Raise", primaryMuscles: [.lateralDeltoid], equipmentType: .cable, resistanceType: .machine, movementPattern: .verticalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "lateral-raise", difficulty: .beginner, tags: ["cable-lateral-raise", "cable", "vertical-push", "lateraldeltoid", "isolation"], laterality: .unilateral, repCountingStyle: .perSide),
        .init(name: "Cable Front Raise", primaryMuscles: [.frontDeltoid], equipmentType: .cable, resistanceType: .machine, movementPattern: .verticalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "front-raise", difficulty: .beginner, tags: ["cable-front-raise", "cable", "vertical-push", "frontdeltoid", "isolation"], laterality: .unilateral, repCountingStyle: .perSide),
        .init(name: "Cable Rear Delt Fly", primaryMuscles: [.rearDeltoid], secondaryMuscles: [.trapezius, .rhomboids], equipmentType: .cable, resistanceType: .machine, movementPattern: .horizontalPull, forceType: .pull, mechanics: .isolation, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "rear-delt-fly", difficulty: .beginner, tags: ["cable-rear-delt-fly", "cable", "horizontal-pull", "reardeltoid", "isolation"], laterality: .unilateral, repCountingStyle: .perSide),
        .init(name: "Machine Lateral Raise", primaryMuscles: [.lateralDeltoid], equipmentType: .machine, resistanceType: .machine, movementPattern: .verticalPush, forceType: .push, mechanics: .isolation, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, variationFamilyID: "lateral-raise", difficulty: .beginner, tags: ["machine-lateral-raise", "machine", "vertical-push", "lateraldeltoid", "isolation"]),
        .init(name: "Machine Rear Delt Fly", primaryMuscles: [.rearDeltoid], secondaryMuscles: [.trapezius, .rhomboids], equipmentType: .machine, resistanceType: .machine, movementPattern: .horizontalPull, forceType: .pull, mechanics: .isolation, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, variationFamilyID: "rear-delt-fly", difficulty: .beginner, tags: ["machine-rear-delt-fly", "machine", "horizontal-pull", "reardeltoid", "isolation"]),
        .init(name: "Face Pull", primaryMuscles: [.rearDeltoid], secondaryMuscles: [.trapezius, .rhomboids, .teresMajor], equipmentType: .cable, resistanceType: .machine, movementPattern: .horizontalPull, forceType: .pull, mechanics: .compound, gripStyle: .neutral, stance: .standing, rangeOfMotion: .full, variationFamilyID: "face-pull", difficulty: .beginner, tags: ["face-pull", "cable", "horizontal-pull", "reardeltoid", "compound"]),
        .init(name: "Upright Row", primaryMuscles: [.lateralDeltoid], secondaryMuscles: [.trapezius, .bicep], equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .pronated, stance: .standing, rangeOfMotion: .full, variationFamilyID: "upright-row", difficulty: .intermediate, tags: ["upright-row", "barbell", "vertical-pull", "lateraldeltoid", "compound"], isPlateLoaded: true),

        // Vertical pull
        .init(name: "Pull-Up", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .pronated, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .advanced, tags: ["pull-up", "bodyweight", "vertical-pull", "latissimusdorsi", "compound"]),
        .init(name: "Chin-Up", primaryMuscles: [.bicep], secondaryMuscles: [.latissimusDorsi, .teresMajor], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .supinated, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .advanced, tags: ["chin-up", "bodyweight", "vertical-pull", "bicep", "compound"]),
        .init(name: "Neutral-Grip Pull-Up", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .neutral, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .advanced, tags: ["neutral-grip-pull-up", "bodyweight", "vertical-pull", "latissimusdorsi", "compound"]),
        .init(name: "Weighted Pull-Up", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], trackingType: .weightedBodyweight, equipmentType: .bodyweight, resistanceType: .weightedBodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .pronated, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .advanced, tags: ["weighted-pull-up", "bodyweight", "vertical-pull", "latissimusdorsi", "compound"]),
        .init(name: "Weighted Chin-Up", primaryMuscles: [.bicep], secondaryMuscles: [.latissimusDorsi, .teresMajor], trackingType: .weightedBodyweight, equipmentType: .bodyweight, resistanceType: .weightedBodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .supinated, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .advanced, tags: ["weighted-chin-up", "bodyweight", "vertical-pull", "bicep", "compound"]),
        .init(name: "Assisted Pull-Up", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], trackingType: .assistedBodyweight, equipmentType: .machine, resistanceType: .assistedBodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .pronated, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .beginner, tags: ["assisted-pull-up", "machine", "vertical-pull", "latissimusdorsi", "compound"]),
        .init(name: "Assisted Chin-Up", primaryMuscles: [.bicep], secondaryMuscles: [.latissimusDorsi, .teresMajor], trackingType: .assistedBodyweight, equipmentType: .machine, resistanceType: .assistedBodyweight, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .supinated, rangeOfMotion: .full, variationFamilyID: "pull-up", difficulty: .beginner, tags: ["assisted-chin-up", "machine", "vertical-pull", "bicep", "compound"]),
        .init(name: "Lat Pulldown", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], equipmentType: .cable, resistanceType: .machine, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .pronated, stance: .seated, rangeOfMotion: .full, variationFamilyID: "lat-pulldown", difficulty: .beginner, tags: ["lat-pulldown", "cable", "vertical-pull", "latissimusdorsi", "compound"]),
        .init(name: "Close-Grip Lat Pulldown", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], equipmentType: .cable, resistanceType: .machine, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, variationFamilyID: "lat-pulldown", difficulty: .beginner, tags: ["close-grip-lat-pulldown", "cable", "vertical-pull", "latissimusdorsi", "compound"]),
        .init(name: "Single-Arm Lat Pulldown", primaryMuscles: [.latissimusDorsi], secondaryMuscles: [.bicep, .teresMajor], equipmentType: .cable, resistanceType: .machine, movementPattern: .verticalPull, forceType: .pull, mechanics: .compound, gripStyle: .neutral, stance: .seated, rangeOfMotion: .full, variationFamilyID: "lat-pulldown", difficulty: .intermediate, tags: ["single-arm-lat-pulldown", "cable", "vertical-pull", "latissimusdorsi", "compound"], laterality: .unilateral, repCountingStyle: .perSide)
    ]
}

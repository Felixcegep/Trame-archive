import Foundation

#if !GYMTRACKER_EXTENSION

/// Small, non-branded recipes used by tests and previews. They intentionally
/// exercise different rule combinations instead of embedding program logic.
enum ProgramFixtureCatalog {
    /// Every supported fixture used by simulation and preview acceptance
    /// tests. A new recipe belongs here before it can be considered catalog
    /// coverage complete.
    static func all(exerciseIDs: [String: UUID]) -> [ProgramDefinitionPayload] {
        [
            beginnerFiveByFive(exerciseIDs: exerciseIDs),
            doubleProgression(exerciseIDs: exerciseIDs),
            stageProgression(exerciseIDs: exerciseIDs),
            trainingMaxCycle(exerciseIDs: exerciseIDs),
            topSetBackOff(exerciseIDs: exerciseIDs),
            bodyweightVariation(exerciseIDs: exerciseIDs),
            olympicWeightlifting(exerciseIDs: exerciseIDs),
            weeklyHeavyLightMedium(exerciseIDs: exerciseIDs),
            amrapWave(exerciseIDs: exerciseIDs),
            blockPeriodized(exerciseIDs: exerciseIDs),
            conditioningProgression(exerciseIDs: exerciseIDs),
            waveLoading(exerciseIDs: exerciseIDs),
            mixedAcceptance(exerciseIDs: exerciseIDs)
        ]
    }

    static func beginnerFiveByFive(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let rules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            ),
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .failureCountReached(3),
                successAction: .reduceLoadPercentage(0.1),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )
        ]
        let squat = exercise(id: exerciseIDs["squat"]!, key: "squat", sets: fixedSets(5, reps: 5, load: .trainingMax, exposureKey: "squat"), rules: rules)
        let bench = exercise(id: exerciseIDs["bench"]!, key: "bench", sets: fixedSets(5, reps: 5, load: .trainingMax, exposureKey: "bench"), rules: rules)
        let row = exercise(id: exerciseIDs["row"]!, key: "row", sets: fixedSets(5, reps: 5, load: .previousOccurrence, exposureKey: "row"), rules: rules)
        let bSquat = exercise(id: exerciseIDs["squat"]!, key: "squat", sets: fixedSets(5, reps: 5, load: .trainingMax, exposureKey: "squat"), rules: rules)
        return definition(name: "Beginner 5×5", workouts: [
            workout("A", exercises: [squat, bench, row]),
            workout("B", exercises: [bSquat, exercise(id: exerciseIDs["press"]!, key: "press", sets: fixedSets(5, reps: 5)), exercise(id: exerciseIDs["deadlift"]!, key: "deadlift", sets: fixedSets(1, reps: 5))])
        ])
    }

    static func doubleProgression(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .allSetsReachedUpperRepBound,
            successAction: .addLoad(2.5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let exercise = self.exercise(
            id: exerciseIDs["press"]!,
            key: "upper-press",
            sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .range(minimum: 8, maximum: 12), load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "upper-press"), rounding: .nearestIncrement(2.5))),
                    SetPrescriptionDefinition(orderIndex: 1, repetitions: .range(minimum: 8, maximum: 12), load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "upper-press"), rounding: .nearestIncrement(2.5)))],
            rules: [rule]
        )
        return definition(name: "Double Progression Upper", workouts: [workout("Upper", exercises: [exercise])])
    }

    static func stageProgression(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let rules = [
            ProgressionRuleDefinition(metric: .load, trigger: .failureCountReached(1), successAction: .changeStage("6x2"), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .load, trigger: .failureCountReached(2), successAction: .changeStage("10x1"), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .load, trigger: .failureCountReached(3), successAction: .startDeload, cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        ]
        let exercise = self.exercise(id: exerciseIDs["squat"]!, key: "staged-squat", sets: fixedSets(3, reps: 5), rules: rules)
        return definition(name: "Stage Progression", workouts: [workout("Stage", exercises: [exercise])])
    }

    static func trainingMaxCycle(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let percentages = [0.65, 0.75, 0.85]
        let cycleRule = ProgressionRuleDefinition(
            metric: .trainingMax,
            trigger: .cycleCompleted,
            successAction: .updateTrainingMax(
                .add(
                    .source(.trainingMax(exposureKey: "tm-squat")),
                    .source(.constant(5))
                )
            ),
            cadence: .nextCycle,
            scope: .cycle,
            applicationMode: .automatic
        )
        let weeks = percentages.enumerated().map { index, percentage in
            ProgramWeekDefinition(
                weekIndex: index,
                workouts: [workout("Week \(index + 1)", exercises: [
                    exercise(id: exerciseIDs["squat"]!, key: "tm-squat", sets: [
                        SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "tm-squat"), percentage: percentage)),
                        SetPrescriptionDefinition(orderIndex: 1, role: .amrap, repetitions: .amrap(minimum: 5, maximum: nil), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "tm-squat"), percentage: percentage))
                    ], rules: [cycleRule], initialTrainingMax: 200)
                ])]
            )
        }
        return definition(name: "Training Max Cycle", weeks: weeks)
    }

    static func topSetBackOff(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let exercise = self.exercise(id: exerciseIDs["bench"]!, key: "bench-top", sets: [
            SetPrescriptionDefinition(orderIndex: 0, role: .topSet, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "bench-top")), targetRPE: 8),
            SetPrescriptionDefinition(orderIndex: 1, role: .backOff, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .topSet, exposureKey: "bench-top"), percentage: 0.9, rounding: .nearestIncrement(2.5)), generatesAfterSourceCompletion: true)
        ])
        return definition(name: "Top Set Back-Off", workouts: [workout("Strength", exercises: [exercise])])
    }

    static func bodyweightVariation(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let rule = ProgressionRuleDefinition(metric: .exerciseVariation, trigger: .technicalQualityReached, successAction: .advanceExerciseVariation, cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        let exercise = self.exercise(id: exerciseIDs["assisted"]!, key: "pull-up", sets: fixedSets(3, reps: 8), rules: [rule], alternatives: [exerciseIDs["band"]!, exerciseIDs["bodyweight"]!, exerciseIDs["weighted"]!])
        return definition(name: "Bodyweight Ladder", workouts: [workout("Pull", exercises: [exercise])])
    }

    static func olympicWeightlifting(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let missedAttemptRules = [
            ProgressionRuleDefinition(
                metric: .successfulAttempts,
                trigger: .successfulAttemptRatioReached(0.9),
                successAction: .addLoad(2.5),
                cadence: .nextWorkout,
                scope: .exerciseExposure,
                applicationMode: .recommendation
            ),
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .failureCountReached(1),
                successAction: .repeatPrescription,
                cadence: .nextWorkout,
                scope: .exerciseExposure,
                applicationMode: .automatic
            ),
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .failureCountReached(2),
                successAction: .reduceLoadPercentage(0.05),
                cadence: .nextWorkout,
                scope: .exerciseExposure,
                applicationMode: .automatic
            ),
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .failureCountReached(3),
                successAction: .endExercise,
                cadence: .nextWorkout,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )
        ]
        let snatch = exercise(id: exerciseIDs["snatch"]!, key: "snatch", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .technique, repetitions: .fixed(1), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "snatch"), percentage: 0.75))], rules: missedAttemptRules, initialTrainingMax: 100, initialActualOneRepMax: 100)
        let pull = exercise(id: exerciseIDs["pull"]!, key: "snatch-pull", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(3), load: LoadPrescription(reference: .init(kind: .exerciseOneRepMax, exerciseID: exerciseIDs["snatch"]!), percentage: 1.05))], initialTrainingMax: 100)
        let complex = exercise(id: exerciseIDs["complex"]!, key: "snatch-complex", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .technique, repetitions: .sequence([RepComponent(exerciseID: exerciseIDs["pull"]!, repetitions: 1), RepComponent(exerciseID: exerciseIDs["snatch"]!, repetitions: 1)]))])
        let max = exercise(id: exerciseIDs["clean"]!, key: "clean-daily-max", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .dailyMaximum, repetitions: .fixed(1))])
        return definition(name: "Olympic Weightlifting", workouts: [workout("Platform", exercises: [snatch, pull, complex, max])])
    }

    static func mixedAcceptance(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let squat = exercise(id: exerciseIDs["squat"]!, key: "mixed-squat", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "mixed-squat"), percentage: 0.8))], rules: [ProgressionRuleDefinition(metric: .load, trigger: .allRequiredSetsCompleted, successAction: .addLoad(2.5), failureAction: .repeatPrescription, cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)])
        let bench = exercise(id: exerciseIDs["bench"]!, key: "mixed-bench", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .topSet, repetitions: .fixed(5), targetRPE: 8), SetPrescriptionDefinition(orderIndex: 1, role: .backOff, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .topSet, exposureKey: "mixed-bench"), percentage: 0.9), generatesAfterSourceCompletion: true)])
        let row = exercise(id: exerciseIDs["row"]!, key: "mixed-row", sets: fixedSets(3, reps: 8, range: true))
        let plank = exercise(id: exerciseIDs["plank"]!, key: "mixed-plank", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .duration(seconds: 30))])
        let complex = exercise(id: exerciseIDs["complex"]!, key: "mixed-complex", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .sequence([RepComponent(exerciseID: exerciseIDs["clean"]!, repetitions: 1), RepComponent(exerciseID: exerciseIDs["jerk"]!, repetitions: 1)]))])
        return definition(name: "Mixed Program Acceptance", workouts: [workout("Mixed", exercises: [squat, bench, row, plank, complex])])
    }

    static func weeklyHeavyLightMedium(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let weeklyRule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .weekCompleted,
            successAction: .addLoad(2.5),
            cadence: .nextWeek,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let volume = exercise(id: exerciseIDs["squat"]!, key: "hlm-volume", sets: fixedSets(5, reps: 5), rules: [weeklyRule], initialLoad: 100)
        let recovery = exercise(id: exerciseIDs["squat"]!, key: "hlm-recovery", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .anotherPlannedExercise, exposureKey: "hlm-volume"), percentage: 0.8))])
        let intensity = exercise(id: exerciseIDs["squat"]!, key: "hlm-intensity", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "hlm-intensity"), rounding: .nearestIncrement(2.5)))], initialLoad: 140)
        return definition(name: "Heavy Light Medium", weeks: [ProgramWeekDefinition(weekIndex: 0, workouts: [
            ProgramWorkoutDefinition(orderIndex: 0, name: "Volume", dayOffset: 0, role: "volume", plannedExercises: [volume]),
            ProgramWorkoutDefinition(orderIndex: 1, name: "Recovery", dayOffset: 2, role: "recovery", plannedExercises: [recovery]),
            ProgramWorkoutDefinition(orderIndex: 2, name: "Intensity", dayOffset: 4, role: "intensity", plannedExercises: [intensity])
        ])])
    }

    static func amrapWave(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let waveRule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .extraRepetitionsCompleted(2),
            successAction: .advanceWave,
            cadence: .nextWave,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let waves = (0..<3).map { week in
            let baseReps = max(1, 5 - week)
            let load = LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "amrap-wave"), rounding: .nearestIncrement(2.5))
            return ProgramWaveDefinition(orderIndex: week, name: "Wave \(week + 1)", plannedSets: [
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(baseReps), load: load),
                SetPrescriptionDefinition(orderIndex: 1, role: .amrap, repetitions: .amrap(minimum: baseReps, maximum: nil), load: load)
            ])
        }
        let weeks = (0..<3).map { week in
            var exercise = self.exercise(id: exerciseIDs["squat"]!, key: "amrap-wave", sets: [], rules: [waveRule], initialLoad: 100)
            exercise.waves = waves.map { wave in
                var copy = wave
                copy.id = UUID()
                copy.plannedSets = wave.plannedSets.map { set in
                    var setCopy = set
                    setCopy.id = UUID()
                    return setCopy
                }
                return copy
            }
            return ProgramWeekDefinition(weekIndex: week, name: "Wave \(week + 1)", workouts: [workout("AMRAP Wave \(week + 1)", exercises: [exercise])])
        }
        return definition(name: "AMRAP Wave", weeks: weeks)
    }

    static func blockPeriodized(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let blockRule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .blockCompleted,
            successAction: .advanceBlock,
            cadence: .nextBlock,
            scope: .block,
            applicationMode: .automatic
        )
        let phases: [(String, PlanPhaseType, Int, Int)] = [
            ("Hypertrophy", .hypertrophy, 4, 10),
            ("Strength", .strength, 4, 5),
            ("Peaking", .peaking, 3, 2),
            ("Deload", .deload, 1, 3)
        ]
        let blocks = phases.enumerated().map { index, phase in
            let weeks = (0..<phase.2).map { weekIndex in
                let exercise = self.exercise(
                    id: exerciseIDs["squat"]!,
                    key: "block-\(index)-squat",
                    sets: fixedSets(index == 3 ? 2 : 4, reps: phase.3),
                    rules: [blockRule],
                    initialTrainingMax: 200
                )
                return ProgramWeekDefinition(
                    weekIndex: weekIndex,
                    name: "\(phase.0) \(weekIndex + 1)",
                    workouts: [workout(phase.0, exercises: [exercise])]
                )
            }
            return ProgramBlockDefinition(orderIndex: index, name: phase.0, phaseType: phase.1, weeks: weeks)
        }
        return definition(name: "Block Periodized Strength", blocks: blocks, durationWeeks: 12)
    }

    static func conditioningProgression(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let durationRule = ProgressionRuleDefinition(metric: .duration, trigger: .allRequiredSetsCompleted, successAction: .addDuration(60), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        let distanceRule = ProgressionRuleDefinition(metric: .distance, trigger: .allRequiredSetsCompleted, successAction: .addDistance(250), cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        let plank = exercise(id: exerciseIDs["plank"]!, key: "plank-duration", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .duration(seconds: 30))], rules: [durationRule])
        let carry = exercise(id: exerciseIDs["carry"]!, key: "carry-distance", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .distance(meters: 20))], rules: [distanceRule])
        return definition(name: "Conditioning Progression", workouts: [workout("Conditioning", exercises: [plank, carry])])
    }

    static func waveLoading(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .allRequiredSetsCompleted,
            successAction: .advanceWave,
            cadence: .nextWave,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let waves = [
            ProgramWaveDefinition(orderIndex: 0, name: "Wave 1", plannedSets: [
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .fixedLoad), fixedValue: 100, rounding: .nearestIncrement(2.5))),
                SetPrescriptionDefinition(orderIndex: 1, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .fixedLoad), fixedValue: 100, rounding: .nearestIncrement(2.5)))
            ]),
            ProgramWaveDefinition(orderIndex: 1, name: "Wave 2", plannedSets: [
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(3), load: LoadPrescription(reference: .init(kind: .fixedLoad), fixedValue: 110, rounding: .nearestIncrement(2.5))),
                SetPrescriptionDefinition(orderIndex: 1, repetitions: .fixed(3), load: LoadPrescription(reference: .init(kind: .fixedLoad), fixedValue: 110, rounding: .nearestIncrement(2.5)))
            ])
        ]
        var waveExercise = self.exercise(id: exerciseIDs["squat"]!, key: "wave-squat", sets: [], rules: [rule], initialLoad: 100)
        waveExercise.waves = waves
        return definition(name: "Wave Loading", workouts: [workout("Wave", exercises: [waveExercise])])
    }

    private static func definition(name: String, workouts: [ProgramWorkoutDefinition]) -> ProgramDefinitionPayload {
        let normalizedWorkouts = workouts.enumerated().map { workoutIndex, workout in
            var normalized = workout
            normalized.orderIndex = workoutIndex
            normalized.dayOffset = workoutIndex
            normalized.plannedExercises = workout.plannedExercises.enumerated().map { exerciseIndex, exercise in
                var normalizedExercise = exercise
                normalizedExercise.orderIndex = exerciseIndex
                return normalizedExercise
            }
            return normalized
        }
        return definition(name: name, weeks: [ProgramWeekDefinition(weekIndex: 0, workouts: normalizedWorkouts)])
    }

    private static func definition(name: String, weeks: [ProgramWeekDefinition]) -> ProgramDefinitionPayload {
        definition(name: name, blocks: [ProgramBlockDefinition(orderIndex: 0, name: "Main", weeks: weeks)], durationWeeks: max(1, weeks.count))
    }

    private static func definition(name: String, blocks: [ProgramBlockDefinition], durationWeeks: Int) -> ProgramDefinitionPayload {
        ProgramDefinitionPayload(name: name, durationWeeks: durationWeeks, supportedDaysPerWeek: [max(1, blocks.first?.weeks.first?.workouts.count ?? 1)], blocks: blocks)
    }

    private static func workout(_ name: String, exercises: [ProgramExerciseDefinition]) -> ProgramWorkoutDefinition {
        ProgramWorkoutDefinition(orderIndex: 0, name: name, dayOffset: 0, plannedExercises: exercises)
    }

    private static func exercise(id: UUID, key: String, sets: [SetPrescriptionDefinition], rules: [ProgressionRuleDefinition] = [], alternatives: [UUID] = [], initialLoad: Double? = nil, initialTrainingMax: Double? = nil, initialEstimatedOneRepMax: Double? = nil, initialActualOneRepMax: Double? = nil) -> ProgramExerciseDefinition {
        ProgramExerciseDefinition(exerciseID: id, exposureKey: key, orderIndex: 0, plannedSets: sets, progressionRules: rules, alternativeExerciseIDs: alternatives, initialLoad: initialLoad, initialTrainingMax: initialTrainingMax, initialEstimatedOneRepMax: initialEstimatedOneRepMax, initialActualOneRepMax: initialActualOneRepMax)
    }

    private static func fixedSets(_ count: Int, reps: Int, load: LoadReferenceKind = .manual, exposureKey: String? = nil, range: Bool = false) -> [SetPrescriptionDefinition] {
        (0..<count).map { index in
            SetPrescriptionDefinition(orderIndex: index, repetitions: range ? .range(minimum: reps - 2, maximum: reps + 2) : .fixed(reps), load: LoadPrescription(reference: .init(kind: load, exposureKey: exposureKey)))
        }
    }
}
#endif

import Foundation

/// Small, non-branded recipes used by tests and previews. They intentionally
/// exercise different rule combinations instead of embedding program logic.
enum ProgramFixtureCatalog {
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
        let squat = exercise(id: exerciseIDs["squat"]!, key: "squat", sets: fixedSets(5, reps: 5, load: .trainingMax), rules: rules)
        let bench = exercise(id: exerciseIDs["bench"]!, key: "bench", sets: fixedSets(5, reps: 5, load: .trainingMax), rules: rules)
        let row = exercise(id: exerciseIDs["row"]!, key: "row", sets: fixedSets(5, reps: 5, load: .previousOccurrence), rules: rules)
        let bSquat = exercise(id: exerciseIDs["squat"]!, key: "squat", sets: fixedSets(5, reps: 5, load: .trainingMax), rules: rules)
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
        let weeks = percentages.enumerated().map { index, percentage in
            ProgramWeekDefinition(
                weekIndex: index,
                workouts: [workout("Week \(index + 1)", exercises: [
                    exercise(id: exerciseIDs["squat"]!, key: "tm-squat", sets: [
                        SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "tm-squat"), percentage: percentage)),
                        SetPrescriptionDefinition(orderIndex: 1, role: .amrap, repetitions: .amrap(minimum: 5, maximum: nil), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "tm-squat"), percentage: percentage))
                    ])
                ])]
            )
        }
        return definition(name: "Training Max Cycle", weeks: weeks)
    }

    static func topSetBackOff(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let exercise = self.exercise(id: exerciseIDs["bench"]!, key: "bench-top", sets: [
            SetPrescriptionDefinition(orderIndex: 0, role: .topSet, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "bench-top")), targetRPE: 8),
            SetPrescriptionDefinition(orderIndex: 1, role: .backOff, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .topSet, exposureKey: "bench-top"), percentage: 0.9, rounding: .nearestIncrement(2.5)))
        ])
        return definition(name: "Top Set Back-Off", workouts: [workout("Strength", exercises: [exercise])])
    }

    static func bodyweightVariation(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let rule = ProgressionRuleDefinition(metric: .exerciseVariation, trigger: .technicalQualityReached, successAction: .advanceExerciseVariation, cadence: .nextExerciseOccurrence, scope: .exerciseExposure, applicationMode: .automatic)
        let exercise = self.exercise(id: exerciseIDs["assisted"]!, key: "pull-up", sets: fixedSets(3, reps: 8), rules: [rule], alternatives: [exerciseIDs["band"]!, exerciseIDs["bodyweight"]!, exerciseIDs["weighted"]!])
        return definition(name: "Bodyweight Ladder", workouts: [workout("Pull", exercises: [exercise])])
    }

    static func olympicWeightlifting(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let snatch = exercise(id: exerciseIDs["snatch"]!, key: "snatch", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .technique, repetitions: .fixed(1), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "snatch"), percentage: 0.75))])
        let pull = exercise(id: exerciseIDs["pull"]!, key: "snatch-pull", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(3), load: LoadPrescription(reference: .init(kind: .exerciseOneRepMax, exerciseID: exerciseIDs["snatch"]!), percentage: 1.05))])
        let complex = exercise(id: exerciseIDs["complex"]!, key: "snatch-complex", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .technique, repetitions: .sequence([RepComponent(exerciseID: exerciseIDs["pull"]!, repetitions: 1), RepComponent(exerciseID: exerciseIDs["snatch"]!, repetitions: 1)]))])
        let max = exercise(id: exerciseIDs["clean"]!, key: "clean-daily-max", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .dailyMaximum, repetitions: .fixed(1))])
        return definition(name: "Olympic Weightlifting", workouts: [workout("Platform", exercises: [snatch, pull, complex, max])])
    }

    static func mixedAcceptance(exerciseIDs: [String: UUID]) -> ProgramDefinitionPayload {
        let squat = exercise(id: exerciseIDs["squat"]!, key: "mixed-squat", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "mixed-squat"), percentage: 0.8))])
        let bench = exercise(id: exerciseIDs["bench"]!, key: "mixed-bench", sets: [SetPrescriptionDefinition(orderIndex: 0, role: .topSet, repetitions: .fixed(5), targetRPE: 8), SetPrescriptionDefinition(orderIndex: 1, role: .backOff, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .topSet, exposureKey: "mixed-bench"), percentage: 0.9))])
        let row = exercise(id: exerciseIDs["row"]!, key: "mixed-row", sets: fixedSets(3, reps: 8, range: true))
        let plank = exercise(id: exerciseIDs["plank"]!, key: "mixed-plank", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .duration(seconds: 30))])
        let complex = exercise(id: exerciseIDs["complex"]!, key: "mixed-complex", sets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .sequence([RepComponent(exerciseID: exerciseIDs["clean"]!, repetitions: 1), RepComponent(exerciseID: exerciseIDs["jerk"]!, repetitions: 1)]))])
        return definition(name: "Mixed Program Acceptance", workouts: [workout("Mixed", exercises: [squat, bench, row, plank, complex])])
    }

    private static func definition(name: String, workouts: [ProgramWorkoutDefinition]) -> ProgramDefinitionPayload {
        definition(name: name, weeks: [ProgramWeekDefinition(weekIndex: 0, workouts: workouts)])
    }

    private static func definition(name: String, weeks: [ProgramWeekDefinition]) -> ProgramDefinitionPayload {
        ProgramDefinitionPayload(name: name, durationWeeks: max(1, weeks.count), supportedDaysPerWeek: [max(1, weeks.first?.workouts.count ?? 1)], blocks: [ProgramBlockDefinition(orderIndex: 0, name: "Main", weeks: weeks)])
    }

    private static func workout(_ name: String, exercises: [ProgramExerciseDefinition]) -> ProgramWorkoutDefinition {
        ProgramWorkoutDefinition(orderIndex: 0, name: name, dayOffset: 0, plannedExercises: exercises)
    }

    private static func exercise(id: UUID, key: String, sets: [SetPrescriptionDefinition], rules: [ProgressionRuleDefinition] = [], alternatives: [UUID] = []) -> ProgramExerciseDefinition {
        ProgramExerciseDefinition(exerciseID: id, exposureKey: key, orderIndex: 0, plannedSets: sets, progressionRules: rules, alternativeExerciseIDs: alternatives)
    }

    private static func fixedSets(_ count: Int, reps: Int, load: LoadReferenceKind = .manual, range: Bool = false) -> [SetPrescriptionDefinition] {
        (0..<count).map { index in
            SetPrescriptionDefinition(orderIndex: index, repetitions: range ? .range(minimum: reps - 2, maximum: reps + 2) : .fixed(reps), load: LoadPrescription(reference: .init(kind: load)))
        }
    }
}

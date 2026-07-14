import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutIntegrityTests: XCTestCase {
    func testDeletingWorkoutCascadesEntriesAndSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let workout = makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        context.delete(workout)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciceEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciceTemplate>()).count, 1)
    }

    func testOrphanCleanupDeletesUnownedEntriesAndSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetition: 8, weight: 50, usedMetric: .metric)]
        context.insert(exercise)
        context.insert(entry)
        try context.save()

        let result = try DataMaintenanceService.cleanupOrphans(using: context)

        XCTAssertEqual(result.deletedExercises, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciceEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
    }

    func testPreviousPerformanceUsesLatestCompletedWorkoutAndStoredIdentity() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let olderWorkout = makeWorkout(with: exercise, reps: 8, weight: 100)
        olderWorkout.status = .completed
        olderWorkout.startTime = Date.now.addingTimeInterval(-86_400)
        olderWorkout.endTime = olderWorkout.startTime.addingTimeInterval(3_600)
        context.insert(exercise)
        context.insert(olderWorkout)
        try context.save()

        let performance = try ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: exercise, before: .now)

        XCTAssertEqual(performance?.completedSetCount, 1)
        XCTAssertEqual(performance?.sets.first?.repetitions, 8)
        XCTAssertEqual(performance?.sets.first?.weight, 100)
        XCTAssertEqual(performance?.sets.first?.weightType, .kg)
    }

    func testUnitConversionPreservesEquivalentLoad() {
        XCTAssertEqual(UnitConversion.weight(100, from: .kg, to: .lbs), 220.462_26, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.weight(220.462_26, from: .lbs, to: .kg), 100, accuracy: 0.001)
    }

    func testRestTimerControllerTransitionsThroughPauseAndResume() {
        let controller = RestTimerController()
        let endDate = Date.now.addingTimeInterval(90)

        controller.start(until: endDate)
        XCTAssertEqual(controller.endDate, endDate)
        XCTAssertTrue(controller.isVisible)

        controller.pause(remaining: 45)
        XCTAssertEqual(controller.pausedRemaining, 45)
        XCTAssertNil(controller.endDate)

        controller.extendPaused(by: 15)
        XCTAssertEqual(controller.pausedRemaining, 60)

        controller.cancel()
        XCTAssertFalse(controller.isVisible)
    }

    func testDoubleProgressionIncreasesOnlyAfterAllRequiredSetsReachCeiling() {
        let performance = PreviousExercisePerformance(
            workoutDate: .now,
            sets: [
                PreviousSetPerformance(orderIndex: 0, repetitions: 12, weight: 100, weightType: .lbs, duration: nil, distance: nil, distanceType: .miles, setType: .normal),
                PreviousSetPerformance(orderIndex: 1, repetitions: 12, weight: 100, weightType: .lbs, duration: nil, distance: nil, distanceType: .miles, setType: .normal),
                PreviousSetPerformance(orderIndex: 2, repetitions: 12, weight: 100, weightType: .lbs, duration: nil, distance: nil, distanceType: .miles, setType: .normal)
            ]
        )

        let recommendation = DoubleProgressionEngine.recommend(
            from: performance,
            requiredSets: 3,
            repCeiling: 12,
            increment: 5
        )

        XCTAssertEqual(recommendation?.decision, .increase)
        XCTAssertEqual(recommendation?.recommendedLoad, 105)
        XCTAssertTrue(recommendation?.explanation.contains("105 lbs recommended") == true)
    }

    func testDoubleProgressionHoldsLoadWhenAnyRequiredSetIsBelowTheRepCeiling() {
        let performance = PreviousExercisePerformance(
            workoutDate: .now,
            sets: [
                previousSet(order: 0, reps: 12, weight: 100),
                previousSet(order: 1, reps: 11, weight: 100),
                previousSet(order: 2, reps: 12, weight: 100)
            ]
        )

        let recommendation = DoubleProgressionEngine.recommend(
            from: performance,
            requiredSets: 3,
            repCeiling: 12,
            increment: Constants.Progression.imperialIncrementLbs
        )

        XCTAssertEqual(recommendation?.decision, .hold)
        XCTAssertEqual(recommendation?.recommendedLoad, 100)
        XCTAssertEqual(recommendation?.evidence.completedSets, 3)
    }

    func testDoubleProgressionRequiresTheFullRequiredSetPrefix() {
        let performance = PreviousExercisePerformance(
            workoutDate: .now,
            sets: [
                previousSet(order: 0, reps: 12, weight: 100),
                previousSet(order: 1, reps: 12, weight: 100)
            ]
        )

        XCTAssertNil(
            DoubleProgressionEngine.recommend(
                from: performance,
                requiredSets: 3,
                repCeiling: 12,
                increment: Constants.Progression.imperialIncrementLbs
            )
        )
    }

    func testProgressionSnapshotExcludesWarmupsAndPreservesTheStartedTemplateEvidence() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let priorWorkout = Workout(nom: "Prior", endTime: .now)
        priorWorkout.startTime = .now.addingTimeInterval(-86_400)
        let priorEntry = ExerciceEntry(exercice: exercise, usedMetric: .imperial)
        priorEntry.sets = [
            ExerciseSet(repetition: 20, weight: 45, done: true, setType: .warmup, orderIndex: 0, usedMetric: .imperial),
            ExerciseSet(repetition: 12, weight: 100, done: true, orderIndex: 1, usedMetric: .imperial),
            ExerciseSet(repetition: 12, weight: 100, done: true, orderIndex: 2, usedMetric: .imperial)
        ]
        priorWorkout.exercises = [priorEntry]

        let templateExercise = TemplateExercise(
            exercise: exercise,
            order: 0,
            targetSets: 2,
            repRangeMinimum: 8,
            repRangeMaximum: 12
        )
        let template = WorkoutTemplate(
            name: "Progression",
            exercises: [exercise],
            templateExercises: [templateExercise]
        )
        let activeWorkout = Workout(template: template, unitSystem: .metric)

        context.insert(exercise)
        context.insert(priorWorkout)
        context.insert(template)
        try context.save()

        ProgressionSnapshotService(modelContext: context)
            .applyRecommendations(to: activeWorkout, from: template)

        let entry = try XCTUnwrap(activeWorkout.orderedExercises.first)
        XCTAssertEqual(entry.recommendedDecision, .increase)
        XCTAssertEqual(entry.recommendedLoad, 105)
        XCTAssertEqual(entry.recommendedUnit, .lbs)
        XCTAssertEqual(entry.recommendationRequiredSets, 2)
        XCTAssertEqual(entry.recommendationCompletedSets, 2)

        templateExercise.progressionRule = .none
        templateExercise.repRangeMaximum = 1
        XCTAssertEqual(entry.recommendedDecision, .increase)
        XCTAssertEqual(entry.recommendationRepCeiling, 12)
    }

    func testProgressionSnapshotSkipsDisabledAndAssistedBodyweightExercises() throws {
        let context = try makeContext()
        let disabledExercise = makeExercise()
        let assistedExercise = ExerciceTemplate(
            name: "Assisted Pull-up",
            PrimaryMuscle: [.latissimusDorsi],
            trackingType: .assistedBodyweight
        )

        let disabled = TemplateExercise(exercise: disabledExercise, order: 0, progressionRule: .none)
        let assisted = TemplateExercise(exercise: assistedExercise, order: 1)
        let service = ProgressionSnapshotService(modelContext: context)

        XCTAssertNil(
            service.recommendation(
                for: disabledExercise,
                rule: disabled.progressionRule,
                requiredSets: 3,
                repCeiling: 12,
                startedAt: .now
            )
        )
        XCTAssertNil(
            service.recommendation(
                for: assistedExercise,
                rule: assisted.progressionRule,
                requiredSets: 3,
                repCeiling: 12,
                startedAt: .now
            )
        )
    }

    func testApplyRecommendationConvertsOnlyIncompleteSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let openSet = ExerciseSet(repetition: 0, weight: 0, orderIndex: 0, usedMetric: .metric)
        let completedSet = ExerciseSet(repetition: 8, weight: 80, done: true, orderIndex: 1, usedMetric: .imperial)
        let entry = ExerciceEntry(exercice: exercise, sets: [openSet, completedSet], usedMetric: .metric)
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 105
        entry.recommendedUnit = .lbs
        let workout = Workout(nom: "Active")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context)
            .applyRecommendation(to: entry)

        XCTAssertEqual(openSet.weight, UnitConversion.weight(105, from: .lbs, to: .kg), accuracy: 0.001)
        XCTAssertEqual(completedSet.weight, 80)
    }

    func testLegacyBackupDefaultsTemplateProgressionToDoubleProgression() throws {
        let context = try makeContext()
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [
                ExerciseTemplateDTO(
                    name: "Bench Press",
                    primaryMuscles: [Muscle.upperChest.rawValue],
                    secondaryMuscles: nil,
                    category: nil,
                    trackingType: TrackingType.weightAndReps.rawValue,
                    equipmentType: nil,
                    resistanceType: nil,
                    movementPattern: nil,
                    difficulty: nil,
                    tags: [],
                    isFavorite: false,
                    isPlateLoaded: false,
                    isCustom: true,
                    isArchived: false
                )
            ],
            templates: [
                WorkoutTemplateDTO(
                    name: "Legacy Template",
                    templateExercises: [
                        TemplateExerciseDTO(
                            exerciseName: "Bench Press",
                            orderIndex: 0,
                            targetSets: 3,
                            repRangeMinimum: 8,
                            repRangeMaximum: 12,
                            restSeconds: 90,
                            targetRPE: nil,
                            targetRIR: nil,
                            notes: nil,
                            progressionRule: nil
                        )
                    ]
                )
            ],
            collections: [],
            workouts: []
        )

        try backup.restore(to: context)

        XCTAssertEqual(
            try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutTemplate>()).first)
                .orderedTemplateExercises.first?.progressionRule,
            .doubleProgression
        )
    }

    func testBackupRoundTripsProgressionRuleAndRecommendationSnapshot() throws {
        let source = try makeContext()
        let exercise = makeExercise()
        let templateExercise = TemplateExercise(
            exercise: exercise,
            order: 0,
            progressionRule: .none
        )
        let template = WorkoutTemplate(
            name: "Progression Template",
            exercises: [exercise],
            templateExercises: [templateExercise]
        )
        let workout = makeWorkout(with: exercise)
        let entry = try XCTUnwrap(workout.exercises.first)
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 105
        entry.recommendedUnit = .lbs
        entry.recommendationPriorLoad = 100
        entry.recommendationRequiredSets = 3
        entry.recommendationRepCeiling = 12
        entry.recommendationCompletedSets = 3
        entry.recommendationPriorWorkoutDate = Date(timeIntervalSince1970: 1_700_000_000)
        source.insert(exercise)
        source.insert(template)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)
        let restored = try makeContext()
        try decoded.restore(to: restored)

        let restoredTemplate = try XCTUnwrap(
            restored.fetch(FetchDescriptor<WorkoutTemplate>())
                .first { $0.name == "Progression Template" }
        )
        XCTAssertEqual(
            restoredTemplate.orderedTemplateExercises.first?.progressionRule,
            ProgressionRule.none
        )

        let restoredEntry = try XCTUnwrap(
            restored.fetch(FetchDescriptor<Workout>()).first?.orderedExercises.first
        )
        XCTAssertEqual(restoredEntry.recommendedDecision, .increase)
        XCTAssertEqual(restoredEntry.recommendedLoad, 105)
        XCTAssertEqual(restoredEntry.recommendedUnit, .lbs)
        XCTAssertEqual(restoredEntry.recommendationPriorLoad, 100)
        XCTAssertEqual(restoredEntry.recommendationRequiredSets, 3)
        XCTAssertEqual(restoredEntry.recommendationRepCeiling, 12)
        XCTAssertEqual(restoredEntry.recommendationCompletedSets, 3)
        XCTAssertEqual(
            restoredEntry.recommendationPriorWorkoutDate,
            Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            ExerciceTemplate.self,
            ExerciceEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeExercise() -> ExerciceTemplate {
        ExerciceTemplate(name: "Bench Press", PrimaryMuscle: [.upperChest])
    }

    private func makeWorkout(
        with exercise: ExerciceTemplate,
        reps: Float = 8,
        weight: Float = 50
    ) -> Workout {
        let set = ExerciseSet(repetition: reps, weight: weight, done: true, usedMetric: .metric)
        let entry = ExerciceEntry(exercice: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(nom: "Test Workout", endTime: .now)
        workout.exercises = [entry]
        return workout
    }

    private func previousSet(order: Int, reps: Float, weight: Float) -> PreviousSetPerformance {
        PreviousSetPerformance(
            orderIndex: order,
            repetitions: reps,
            weight: weight,
            weightType: .lbs,
            duration: nil,
            distance: nil,
            distanceType: .miles,
            setType: .normal
        )
    }
}

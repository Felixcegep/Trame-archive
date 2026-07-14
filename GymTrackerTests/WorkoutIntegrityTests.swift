import Foundation
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

    func testExerciseActiveDurationAccumulatesAcrossSelectionsAndRelaunches() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        context.insert(exercise)
        context.insert(entry)

        entry.startActiveDuration(at: startedAt)
        entry.stopActiveDuration(at: startedAt.addingTimeInterval(42))
        entry.startActiveDuration(at: startedAt.addingTimeInterval(60))
        try context.save()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciceEntry>()).first)
        XCTAssertEqual(restored.activeDuration(at: startedAt.addingTimeInterval(78)), 60, accuracy: 0.001)

        restored.stopActiveDuration(at: startedAt.addingTimeInterval(78))
        XCTAssertEqual(restored.accumulatedActiveDuration, 60, accuracy: 0.001)
        XCTAssertNil(restored.activeDurationStartedAt)
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

    func testKeepLastRecommendationConvertsOnlyIncompleteSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let openSet = ExerciseSet(repetition: 0, weight: 0, orderIndex: 0, usedMetric: .metric)
        let completedSet = ExerciseSet(repetition: 8, weight: 80, done: true, orderIndex: 1, usedMetric: .imperial)
        let entry = ExerciceEntry(exercice: exercise, sets: [openSet, completedSet], usedMetric: .metric)
        entry.recommendationPriorLoad = 100
        entry.recommendedUnit = .lbs
        let workout = Workout(nom: "Active")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context)
            .applyPriorRecommendationLoad(to: entry)

        XCTAssertEqual(openSet.weight, UnitConversion.weight(100, from: .lbs, to: .kg), accuracy: 0.001)
        XCTAssertEqual(completedSet.weight, 80)
    }

    func testRecommendationPresentationDistinguishesInsufficientHistoryFromIneligible() {
        let exercise = makeExercise()
        let eligible = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        eligible.prescribedSets = 3
        eligible.prescribedRepRangeMaximum = 12
        eligible.prescribedProgressionRule = .doubleProgression

        guard case .insufficientHistory? = RecommendationPresentationState(entry: eligible) else {
            return XCTFail("Expected an insufficient-history presentation")
        }

        eligible.prescribedProgressionRule = .none
        XCTAssertNil(RecommendationPresentationState(entry: eligible))
    }

    func testPlannedWorkoutSnapshotsProgressionAndPreservesRule() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let priorWorkout = Workout(nom: "Prior", endTime: .now)
        priorWorkout.startTime = .now.addingTimeInterval(-86_400)
        let priorEntry = ExerciceEntry(exercice: exercise, usedMetric: .imperial)
        priorEntry.sets = (0..<3).map {
            ExerciseSet(repetition: 12, weight: 100, done: true, orderIndex: $0, usedMetric: .imperial)
        }
        priorWorkout.exercises = [priorEntry]

        let templateExercise = TemplateExercise(
            exercise: exercise,
            order: 0,
            targetSets: 3,
            repRangeMinimum: 8,
            repRangeMaximum: 12,
            progressionRule: .doubleProgression
        )
        let template = WorkoutTemplate(
            name: "Upper",
            exercises: [exercise],
            templateExercises: [templateExercise]
        )
        let plan = PlanCoordinator.createPlan(
            name: "Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [.init(dayOffset: 0, template: template)]
        )
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedExercise = try XCTUnwrap(plannedWorkout.orderedPlannedExercises.first)
        XCTAssertEqual(plannedExercise.progressionRule, .doubleProgression)

        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        context.insert(exercise)
        context.insert(priorWorkout)
        context.insert(template)
        context.insert(plan)
        try context.save()

        ProgressionSnapshotService(modelContext: context).applyRecommendations(to: workout)

        let entry = try XCTUnwrap(workout.orderedExercises.first)
        XCTAssertEqual(entry.recommendedDecision, .increase)
        XCTAssertEqual(entry.recommendedLoad, 105)
        XCTAssertEqual(entry.recommendedUnit, .lbs)
    }

    func testPlanCreationAssignsDifferentTemplatesPerTrainingDay() throws {
        let lowerExercise = ExerciceTemplate(name: "Back Squat", PrimaryMuscle: [.quadriceps])
        let upperExercise = makeExercise()
        let lower = WorkoutTemplate(
            name: "Lower",
            exercises: [lowerExercise],
            templateExercises: [TemplateExercise(exercise: lowerExercise, order: 0)]
        )
        let upper = WorkoutTemplate(
            name: "Upper",
            exercises: [upperExercise],
            templateExercises: [TemplateExercise(exercise: upperExercise, order: 0)]
        )

        let plan = PlanCoordinator.createPlan(
            name: "Upper Lower",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            durationWeeks: 2,
            dayAssignments: [
                .init(dayOffset: 4, template: upper),
                .init(dayOffset: 0, template: lower),
                .init(dayOffset: 2, template: upper)
            ]
        )

        XCTAssertEqual(plan.daysPerWeek, 3)
        XCTAssertEqual(plan.orderedWeeks.count, 2)
        for week in plan.orderedWeeks {
            XCTAssertEqual(week.orderedPlannedWorkouts.map(\.dayOffset), [0, 2, 4])
            XCTAssertEqual(week.orderedPlannedWorkouts.map(\.name), ["Lower", "Upper", "Upper"])
            XCTAssertEqual(
                week.orderedPlannedWorkouts.map { $0.orderedPlannedExercises.first?.exercise.name },
                ["Back Squat", "Bench Press", "Bench Press"]
            )
        }
    }

    func testPlannedVersusPerformedComparisonReportsMetAboveBelowAndNoTarget() {
        let exercise = makeExercise()
        let entry = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        entry.prescribedSets = 3
        entry.prescribedRepRangeMinimum = 8
        entry.prescribedRepRangeMaximum = 12
        entry.prescribedSuggestedLoad = 50
        entry.prescribedSuggestedLoadType = .kg
        entry.sets = (0..<3).map {
            ExerciseSet(repetition: 12, weight: 50, done: true, orderIndex: $0, usedMetric: .metric)
        }

        var comparison = WorkoutPerformanceComparison(exercise: entry)
        XCTAssertEqual(comparison.sets, .met)
        XCTAssertEqual(comparison.reps, .met)
        XCTAssertEqual(comparison.load, .met)
        XCTAssertEqual(comparison.overall, .met)

        entry.sets[0].repetition = 13
        comparison = WorkoutPerformanceComparison(exercise: entry)
        XCTAssertEqual(comparison.reps, .above)
        XCTAssertEqual(comparison.overall, .above)

        entry.sets[1].weight = 45
        comparison = WorkoutPerformanceComparison(exercise: entry)
        XCTAssertEqual(comparison.load, .below)
        XCTAssertEqual(comparison.overall, .below)

        let freeEntry = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        XCTAssertEqual(WorkoutPerformanceComparison(exercise: freeEntry).overall, .noTarget)
    }

    func testPlannedWorkoutSaveCompletesRunProgressAndMakesNextWorkoutAvailable() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let template = makeTemplate(exercise: exercise, targetSets: 1)
        let plan = PlanCoordinator.createPlan(
            name: "Integration Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [
                .init(dayOffset: 0, template: template),
                .init(dayOffset: 2, template: template)
            ]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(
            PlanCoordinator.plannedWorkout(for: firstProgress, in: run)
        )
        let viewModel = WorkoutViewModel()

        XCTAssertTrue(
            viewModel.startWorkout(
                from: firstPlannedWorkout,
                progress: firstProgress,
                in: run,
                using: context
            )
        )
        XCTAssertEqual(firstProgress.status, .inProgress)

        let activeWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let activeSet = try XCTUnwrap(activeWorkout.orderedExercises.first?.orderedSets.first)
        activeSet.repetition = 8
        activeSet.weight = 50
        activeSet.done = true

        XCTAssertTrue(viewModel.saveWorkout(using: context))

        XCTAssertEqual(activeWorkout.status, .completed)
        XCTAssertEqual(firstProgress.status, .completed)
        XCTAssertEqual(firstProgress.completedWorkout?.persistentModelID, activeWorkout.persistentModelID)
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(run.status, .active)
        XCTAssertEqual(run.orderedWorkoutProgress[1].status, .available)

        let savedWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(savedWorkouts.filter { $0.status == .completed }.count, 1)
        XCTAssertEqual(activeWorkout.sourcePlanRunID, run.id)
        XCTAssertEqual(activeWorkout.sourcePlannedWorkoutID, firstPlannedWorkout.id)
        XCTAssertEqual(activeWorkout.orderedExercises.map(\.exercice.name), ["Bench Press"])
        XCTAssertFalse(WorkoutViewModel().restoreActiveWorkout(using: context))
    }

    func testDiscardingPlannedWorkoutRestoresRunAvailabilityAndDeletesActiveWorkout() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let template = makeTemplate(exercise: exercise, targetSets: 1)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Recovery Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: progress, in: run))
        let viewModel = WorkoutViewModel()

        XCTAssertTrue(
            viewModel.startWorkout(
                from: plannedWorkout,
                progress: progress,
                in: run,
                using: context
            )
        )
        XCTAssertEqual(progress.status, .inProgress)

        viewModel.discardActiveWorkout(using: context)

        XCTAssertEqual(progress.status, .available)
        XCTAssertNil(progress.startedAt)
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .active }.isEmpty
        )
    }

    func testSavingWorkoutExcludesIncompleteSetsAndEmptyExercisesFromHistory() throws {
        let context = try makeContext()
        let completedExercise = makeExercise()
        let emptyExercise = ExerciceTemplate(name: "Cable Fly", PrimaryMuscle: [.upperChest])
        let workout = Workout(nom: "Partial")
        let completedEntry = ExerciceEntry(exercice: completedExercise, usedMetric: .metric)
        completedEntry.sets = [
            ExerciseSet(repetition: 8, weight: 50, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetition: 0, weight: 50, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let emptyEntry = ExerciceEntry(exercice: emptyExercise, usedMetric: .metric)
        emptyEntry.sets = [ExerciseSet(repetition: 0, weight: 20, usedMetric: .metric)]
        workout.exercises = [completedEntry, emptyEntry]

        context.insert(completedExercise)
        context.insert(emptyExercise)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        XCTAssertTrue(viewModel.saveWorkout(using: context))

        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(workout.orderedExercises.count, 1)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 1)
        XCTAssertTrue(workout.orderedExercises.first?.orderedSets.first?.done == true)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciceEntry>()).contains { $0 === completedEntry })
        XCTAssertFalse(try context.fetch(FetchDescriptor<ExerciceEntry>()).contains { $0 === emptyEntry })
    }

    func testInvalidSaveLeavesActiveDraftUntouched() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciceEntry(exercice: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetition: 0, weight: 50, done: false, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetition: 0, weight: 55, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let workout = Workout(nom: "Draft")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout

        XCTAssertFalse(viewModel.saveWorkout(using: context))
        XCTAssertTrue(viewModel.activeWorkout === workout)
        XCTAssertEqual(workout.status, .active)
        XCTAssertEqual(workout.orderedExercises.count, 1)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 2)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.map(\.weight), [50, 55])
        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).contains { $0 === workout })
    }

    func testLegacyBackupDefaultsTemplateProgressionToDoubleProgression() throws {
        let context = try makeContext()
        let backup = BackupDTO(
            version: BackupDTO.legacyVersion,
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

        let encoded = try JSONEncoder().encode(backup)
        var legacyPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyPayload.removeValue(forKey: "plans")
        legacyPayload.removeValue(forKey: "planRuns")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload)
        let decodedLegacyBackup = try JSONDecoder().decode(BackupDTO.self, from: legacyData)
        XCTAssertTrue(decodedLegacyBackup.plans.isEmpty)
        XCTAssertTrue(decodedLegacyBackup.planRuns.isEmpty)

        try decodedLegacyBackup.restore(to: context)

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

    func testBackupRoundTripsPlanRunProgressAndCompletedWorkoutIdentity() throws {
        let source = try makeContext()
        let exercise = makeExercise()
        let template = makeTemplate(exercise: exercise, targetSets: 1)
        template.name = "Backup Plan Template"
        let plan = PlanCoordinator.createPlan(
            name: "Backup Plan",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            durationWeeks: 1,
            dayAssignments: [
                .init(dayOffset: 0, template: template),
                .init(dayOffset: 2, template: template)
            ]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000)))
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let completedWorkout = Workout(plannedWorkout: firstPlannedWorkout, planRun: run, unitSystem: .metric)
        completedWorkout.status = .completed
        completedWorkout.endTime = Date(timeIntervalSince1970: 1_700_003_600)
        completedWorkout.orderedExercises.first?.orderedSets.first?.repetition = 8
        completedWorkout.orderedExercises.first?.orderedSets.first?.weight = 50
        completedWorkout.orderedExercises.first?.orderedSets.first?.done = true
        PlanCoordinator.markCompleted(firstProgress, with: completedWorkout, in: run)

        source.insert(exercise)
        source.insert(template)
        source.insert(plan)
        source.insert(run)
        source.insert(completedWorkout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        XCTAssertEqual(backup.plans.count, 1)
        XCTAssertEqual(backup.planRuns.count, 1)

        let encoded = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: encoded)
        let restored = try makeContext()
        try decoded.restore(to: restored)

        let restoredPlan = try XCTUnwrap(
            restored.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.id == plan.id }
        )
        let restoredRun = try XCTUnwrap(
            restored.fetch(FetchDescriptor<PlanRun>()).first { $0.id == run.id }
        )
        let restoredWorkout = try XCTUnwrap(
            restored.fetch(FetchDescriptor<Workout>()).first { $0.id == completedWorkout.id }
        )
        let restoredProgress = try XCTUnwrap(restoredRun.orderedWorkoutProgress.first)

        XCTAssertEqual(restoredPlan.goal, .hypertrophy)
        XCTAssertEqual(restoredPlan.experienceLevel, .intermediate)
        XCTAssertEqual(restoredRun.plan?.id, plan.id)
        XCTAssertEqual(restoredRun.sourcePlanID, plan.id)
        XCTAssertEqual(restoredRun.status, .active)
        XCTAssertEqual(restoredProgress.status, .completed)
        XCTAssertEqual(restoredProgress.plannedWorkoutID, firstPlannedWorkout.id)
        XCTAssertEqual(restoredProgress.completedWorkout?.id, completedWorkout.id)
        XCTAssertEqual(restoredWorkout.sourcePlanRunID, run.id)
        XCTAssertEqual(restoredWorkout.sourcePlannedWorkoutID, firstPlannedWorkout.id)
        XCTAssertEqual(
            restoredPlan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first?.targetSets,
            1
        )
    }

    func testInvalidPlanRunBackupDoesNotReplaceExistingData() throws {
        let context = try makeContext()
        let sentinel = ExerciceTemplate(name: "Do Not Delete", PrimaryMuscle: [.upperChest])
        context.insert(sentinel)
        try context.save()

        let missingPlanID = UUID().uuidString
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            plans: [],
            planRuns: [
                PlanRunDTO(
                    id: UUID().uuidString,
                    sourcePlanID: missingPlanID,
                    sourcePlanName: "Missing",
                    planID: missingPlanID,
                    startDate: .now,
                    endDate: nil,
                    status: PlanRunStatus.active.rawValue,
                    currentWeekIndex: 0,
                    currentWorkoutIndex: 0,
                    createdAt: .now,
                    updatedAt: .now,
                    workoutProgress: []
                )
            ]
        )

        XCTAssertThrowsError(try backup.restore(to: context)) { error in
            guard case .missingPlan(let identifier) = error as? BackupValidationError else {
                return XCTFail("Expected a missing-plan validation error, got \(error)")
            }
            XCTAssertEqual(identifier, missingPlanID)
        }
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<ExerciceTemplate>()).contains { $0.name == sentinel.name }
        )
    }

    func testBackupInterruptionBeforeCommitPreservesExistingDatabase() throws {
        let context = try makeContext()
        let sentinel = ExerciceTemplate(name: "Keep During Import", PrimaryMuscle: [.upperChest])
        context.insert(sentinel)
        try context.save()

        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(
                darkMode: false,
                restTimer: 90,
                unitSystem: UnitSystem.metric.rawValue
            ),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            plans: [],
            planRuns: []
        )

        XCTAssertThrowsError(
            try backup.restore(to: context, beforeCommit: {
                throw NSError(domain: "BackupRestoreTest", code: 1)
            })
        )
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<ExerciceTemplate>()).contains { $0.name == sentinel.name }
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
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

    private func makeTemplate(
        exercise: ExerciceTemplate,
        targetSets: Int
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: "Bench Template",
            exercises: [exercise],
            templateExercises: [
                TemplateExercise(
                    exercise: exercise,
                    order: 0,
                    targetSets: targetSets,
                    repRangeMinimum: 6,
                    repRangeMaximum: 8,
                    progressionRule: .doubleProgression
                )
            ]
        )
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

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutIntegrityTests: XCTestCase {
    func testExerciseFilteringShortCircuitsAndMatchesMuscleCriteria() {
        let benchPress = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
            equipmentType: .barbell,
            movementPattern: .horizontalPush
        )
        let row = Exercise(
            name: "Cable Row",
            primaryMuscles: [.latissimusDorsi],
            equipmentType: .cable,
            movementPattern: .horizontalPull
        )

        var scalarFilter = ExerciseFilterState()
        scalarFilter.equipment = .barbell
        XCTAssertTrue(scalarFilter.matches(benchPress, searchText: ""))
        XCTAssertFalse(scalarFilter.matches(row, searchText: ""))

        var muscleFilter = ExerciseFilterState()
        muscleFilter.bodyAreas = [.chest]
        XCTAssertTrue(muscleFilter.matches(benchPress, searchText: ""))
        XCTAssertFalse(muscleFilter.matches(row, searchText: ""))

        muscleFilter.bodyAreas = []
        XCTAssertTrue(muscleFilter.matches(benchPress, searchText: "chest"))
        XCTAssertFalse(muscleFilter.matches(row, searchText: "chest"))
    }

    func testExerciseFilteringMatchesMechanicsForceTypeAndLaterality() {
        let benchPress = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
            equipmentType: .barbell,
            movementPattern: .horizontalPush,
            forceType: .push,
            mechanics: .compound
        )
        let lateralRaise = Exercise(
            name: "Lateral Raise",
            primaryMuscles: [.lateralDeltoid],
            equipmentType: .dumbbell,
            forceType: .push,
            mechanics: .isolation
        )
        let splitSquat = Exercise(
            name: "Bulgarian Split Squat",
            primaryMuscles: [.quadriceps],
            equipmentType: .dumbbell,
            movementPattern: .squat,
            forceType: .push,
            mechanics: .compound,
            laterality: .unilateral
        )

        var mechanicsFilter = ExerciseFilterState()
        mechanicsFilter.mechanics = [.compound]
        XCTAssertTrue(mechanicsFilter.matches(benchPress, searchText: ""))
        XCTAssertFalse(mechanicsFilter.matches(lateralRaise, searchText: ""))

        var forceFilter = ExerciseFilterState()
        forceFilter.forceTypes = [.push]
        XCTAssertTrue(forceFilter.matches(benchPress, searchText: ""))
        XCTAssertTrue(forceFilter.matches(lateralRaise, searchText: ""))

        var lateralityFilter = ExerciseFilterState()
        lateralityFilter.laterality = [.unilateral]
        XCTAssertTrue(lateralityFilter.matches(splitSquat, searchText: ""))
        XCTAssertFalse(lateralityFilter.matches(benchPress, searchText: ""))
    }

    func testSeededExerciseFamiliesDescribeRelatedVariantsWithoutCollapsingIdentity() throws {
        let exercises = ExerciseSeedData.templates()
        let benchPress = try XCTUnwrap(exercises.first { $0.name == "Bench Press" })
        let dumbbellBenchPress = try XCTUnwrap(exercises.first { $0.name == "Dumbbell Bench Press" })
        let inclineBenchPress = try XCTUnwrap(exercises.first { $0.name == "Incline Bench Press" })

        XCTAssertEqual(benchPress.variationFamilyID, "bench-press")
        XCTAssertEqual(dumbbellBenchPress.variationFamilyID, "bench-press")
        XCTAssertEqual(inclineBenchPress.setupAngleDegrees, 30)
        XCTAssertEqual(benchPress.setupAngleDegrees, 0)
        XCTAssertNotEqual(benchPress.name, dumbbellBenchPress.name)
    }

    func testInitialImportedExerciseCatalogContainsFirstFiftyEntries() throws {
        let catalog = ExerciseCatalogSeedData.templates()
        let names = Set(catalog.map(\.name))

        XCTAssertEqual(catalog.count, 50)
        XCTAssertEqual(names.count, catalog.count)
        XCTAssertEqual(catalog.first?.name, "Bench Press")
        XCTAssertEqual(catalog.last?.name, "Single-Arm Lat Pulldown")

        let medicineBallPass = try XCTUnwrap(catalog.first { $0.name == "Medicine Ball Chest Pass" })
        XCTAssertEqual(medicineBallPass.displayCategory, .sport)
        XCTAssertEqual(medicineBallPass.trackingType, .weightAndReps)

        let singleArmPulldown = try XCTUnwrap(catalog.first { $0.name == "Single-Arm Lat Pulldown" })
        XCTAssertEqual(singleArmPulldown.laterality, .unilateral)
        XCTAssertEqual(singleArmPulldown.repCountingStyle, .perSide)
        XCTAssertEqual(singleArmPulldown.variationFamilyID, "lat-pulldown")

        let medicineBallPassSemantics = try XCTUnwrap(catalog.first { $0.name == "Medicine Ball Chest Pass" })
        XCTAssertEqual(medicineBallPassSemantics.weightEntryStyle, .perLoadUnit)

        let singleArmDumbbellPress = try XCTUnwrap(catalog.first { $0.name == "Single-Arm Dumbbell Shoulder Press" })
        XCTAssertEqual(singleArmDumbbellPress.weightEntryStyle, .perLoadUnit)
    }

    func testCombinedExerciseSeedDoesNotDuplicateNames() {
        let exercises = ExerciseSeedData.templates()

        XCTAssertEqual(Set(exercises.map(\.name)).count, exercises.count)
        XCTAssertTrue(exercises.contains { $0.name == "Close-Grip Bench Press" })
        XCTAssertTrue(exercises.contains { $0.name == "Single-Arm Lat Pulldown" })
    }

    func testPlanAlternativeScoringPrefersSameVariationFamily() {
        let source = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
            movementPattern: .horizontalPush,
            variationFamilyID: "bench-press"
        )
        let sameFamily = Exercise(
            name: "Dumbbell Bench Press",
            primaryMuscles: [.middleChest],
            movementPattern: .horizontalPush,
            variationFamilyID: "bench-press"
        )
        let sameMuscle = Exercise(name: "Chest Fly", primaryMuscles: [.middleChest])

        let ranked = PlanExerciseAlternativeScoringService.rankedCandidates(
            for: source,
            from: [sameMuscle, sameFamily]
        )

        XCTAssertEqual(ranked.first?.exercise.name, "Dumbbell Bench Press")
        XCTAssertEqual(ranked.first?.reason, "Same movement family")
    }

    func testExerciseArchiveServiceHidesBuiltInAndRestoresIt() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Built In", primaryMuscles: [.upperChest])
        context.insert(exercise)
        try context.save()

        try ExerciseArchiveService.hideOrDelete(exercise, using: context)
        XCTAssertTrue(exercise.isArchived)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)

        try ExerciseArchiveService.restore(exercise, using: context)
        XCTAssertFalse(exercise.isArchived)
    }

    func testExerciseRelationshipBackupRoundTripAndArchiveProtection() throws {
        let context = try makeContext()
        let source = Exercise(name: "Barbell Bench Press", primaryMuscles: [.middleChest], isCustom: true)
        let target = Exercise(name: "Dumbbell Bench Press", primaryMuscles: [.middleChest], isCustom: true)
        let relationship = ExerciseRelationship(
            sourceExercise: source,
            targetExercise: target,
            type: .substitution
        )
        context.insert(source)
        context.insert(target)
        context.insert(relationship)
        try context.save()

        try ExerciseArchiveService.hideOrDelete(source, using: context)
        XCTAssertTrue(source.isArchived)

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 60,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertEqual(backup.exerciseRelationships.count, 1)
        XCTAssertEqual(backup.exerciseRelationships.first?.type, ExerciseRelationshipType.substitution.rawValue)

        let restoredContext = try makeContext()
        try backup.restore(to: restoredContext)
        let restored = try restoredContext.fetch(FetchDescriptor<ExerciseRelationship>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.sourceExercise?.name, "Barbell Bench Press")
        XCTAssertEqual(restored.first?.targetExercise?.name, "Dumbbell Bench Press")
    }

    func testExerciseArchiveServiceDeletesUnreferencedCustomAndArchivesReferencedCustom() throws {
        let context = try makeContext()
        let unreferenced = Exercise(name: "Unused Custom", primaryMuscles: [.upperChest], isCustom: true)
        let referenced = Exercise(name: "Referenced Custom", primaryMuscles: [.upperChest], isCustom: true)
        let template = WorkoutTemplate(
            name: "Reference",
            exercises: [referenced],
            templateExercises: [TemplateExercise(exercise: referenced, order: 0)]
        )
        context.insert(unreferenced)
        context.insert(referenced)
        context.insert(template)
        try context.save()

        try ExerciseArchiveService.hideOrDelete(unreferenced, using: context)
        try ExerciseArchiveService.hideOrDelete(referenced, using: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertFalse(exercises.contains { $0.name == "Unused Custom" })
        XCTAssertTrue(exercises.first { $0.name == "Referenced Custom" }?.isArchived == true)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TemplateExercise>()).count, 1)
    }

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
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }

    func testClearAllGymDataRemovesActiveWorkoutGraphInOneTransaction() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let workout = makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
    }

    func testOrderedViewsUsePersistedIndicesAcrossTemplateWorkoutAndSets() throws {
        let context = try makeContext()
        let first = Exercise(name: "First", primaryMuscles: [.upperChest])
        let second = Exercise(name: "Second", primaryMuscles: [.latissimusDorsi])
        let third = Exercise(name: "Third", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(
            name: "Ordered Template",
            exercises: [first, second, third],
            templateExercises: [
                TemplateExercise(exercise: first, order: 2),
                TemplateExercise(exercise: second, order: 0),
                TemplateExercise(exercise: third, order: 1)
            ]
        )

        XCTAssertEqual(template.orderedTemplateExercises.map { $0.exercise.name }, ["Second", "Third", "First"])
        XCTAssertEqual(template.exercises.map(\.name), ["Second", "Third", "First"])

        let workout = Workout(template: template, unitSystem: .metric)
        XCTAssertEqual(workout.orderedExercises.map { $0.exercise.name }, ["Second", "Third", "First"])

        let entry = try XCTUnwrap(workout.orderedExercises.first)
        let late = ExerciseSet(repetitions: 12, weight: 60, done: true, orderIndex: 2, usedMetric: .metric)
        let early = ExerciseSet(repetitions: 8, weight: 40, done: true, orderIndex: 0, usedMetric: .metric)
        let middle = ExerciseSet(repetitions: 10, weight: 50, done: true, orderIndex: 1, usedMetric: .metric)
        entry.sets = [late, early, middle]

        context.insert(first)
        context.insert(second)
        context.insert(third)
        context.insert(template)
        context.insert(workout)
        try context.save()

        XCTAssertEqual(entry.orderedSets.map(\.repetitions), [8, 10, 12])
        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2])
    }

    func testAddingCopyingAndDeletingSetsKeepsContiguousOrderIndices() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 8, weight: 40, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 10, weight: 50, done: true, orderIndex: 1, usedMetric: .metric),
            ExerciseSet(repetitions: 12, weight: 60, done: true, orderIndex: 2, usedMetric: .metric)
        ]
        let workout = Workout(name: "Set Ordering")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        entry.copyLastSet()
        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2, 3])
        XCTAssertEqual(entry.orderedSets.last?.repetitions, 12)
        XCTAssertFalse(entry.orderedSets.last?.done == true)

        entry.addEmptySet()
        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2, 3, 4])

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        let activeViewModel = ActiveWorkoutViewModel(workoutVM: viewModel, modelContext: context)
        let middle = try XCTUnwrap(entry.orderedSets[1])
        activeViewModel.removeSet(entry, middle)

        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2, 3])
        XCTAssertEqual(entry.orderedSets.map(\.repetitions), [8, 12, 12, 0])
    }

    func testSwappingUnstartedExerciseResetsSetsAndRefreshesSnapshots() throws {
        let context = try makeContext()
        let source = Exercise(name: "Barbell Bench Press", primaryMuscles: [.middleChest])
        let replacement = Exercise(
            name: "Row Ergometer",
            primaryMuscles: [.latissimusDorsi],
            trackingType: .durationAndDistance,
            equipmentType: .cardioMachine
        )
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 80
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        let didSwap = ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context)
            .swapExercise(entry, with: replacement)

        XCTAssertTrue(didSwap)
        XCTAssertEqual(entry.exercise.name, "Row Ergometer")
        XCTAssertEqual(entry.nameSnapshot, "Row Ergometer")
        XCTAssertEqual(entry.trackingTypeSnapshot, .durationAndDistance)
        XCTAssertEqual(entry.orderedSets.count, 3)
        XCTAssertTrue(entry.orderedSets.allSatisfy { $0.duration == 0 && $0.distance == 0 })
        XCTAssertNil(entry.recommendedDecision)
        XCTAssertNil(entry.recommendedLoad)
    }

    func testSwappingCompletedExerciseIsRejected() throws {
        let context = try makeContext()
        let source = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let replacement = Exercise(name: "Dumbbell Bench Press", primaryMuscles: [.middleChest])
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        entry.orderedSets[0].done = true
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        let didSwap = ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context)
            .swapExercise(entry, with: replacement)

        XCTAssertFalse(didSwap)
        XCTAssertEqual(entry.exercise.name, "Bench Press")
    }

    func testDuplicateLegacyIndicesNormalizeToUniqueContiguousValues() throws {
        let exercise = makeExercise()
        let first = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
        let second = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
        first.sets = [
            ExerciseSet(repetitions: 8, weight: 40, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 10, weight: 50, orderIndex: 0, usedMetric: .metric)
        ]
        let workout = Workout(name: "Legacy Ordering")
        workout.exercises = [first, second]

        workout.normalizeExerciseOrder()

        XCTAssertEqual(Set(workout.exercises.map(\.orderIndex)), Set([0, 1]))
        XCTAssertEqual(Set(first.orderedSets.map(\.orderIndex)), Set([0, 1]))
    }

    func testExerciseAndSetOrderingPersistsAcrossDiskRelaunch() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        try withDiskContext(at: storeURL) { context in
            let first = Exercise(name: "First", primaryMuscles: [.upperChest])
            let second = Exercise(name: "Second", primaryMuscles: [.latissimusDorsi])
            let firstEntry = ExerciseEntry(exercise: first, orderIndex: 1, usedMetric: .metric)
            firstEntry.sets = [
                ExerciseSet(repetitions: 12, weight: 60, done: true, orderIndex: 1, usedMetric: .metric),
                ExerciseSet(repetitions: 8, weight: 40, done: true, orderIndex: 0, usedMetric: .metric)
            ]
            let secondEntry = ExerciseEntry(exercise: second, orderIndex: 0, usedMetric: .metric)
            let workout = Workout(name: "Persisted Ordering")
            workout.exercises = [firstEntry, secondEntry]
            context.insert(first)
            context.insert(second)
            context.insert(workout)
            workout.normalizeExerciseOrder()
            try context.save()
        }

        try withDiskContext(at: storeURL) { context in
            let workout = try XCTUnwrap(context.fetch(FetchDescriptor<Workout>()).first)
            XCTAssertEqual(workout.orderedExercises.map { $0.exercise.name }, ["Second", "First"])
            XCTAssertEqual(workout.orderedExercises.map(\.orderIndex), [0, 1])
            XCTAssertEqual(workout.orderedExercises[1].orderedSets.map(\.repetitions), [8, 12])
            XCTAssertEqual(workout.orderedExercises[1].orderedSets.map(\.orderIndex), [0, 1])
        }
    }

    func testSavingWorkoutAndHistoryUseTheSameOrderedEntriesAndSets() throws {
        let context = try makeContext()
        let first = Exercise(name: "First", primaryMuscles: [.upperChest])
        let second = Exercise(name: "Second", primaryMuscles: [.latissimusDorsi])
        let firstEntry = ExerciseEntry(exercise: first, orderIndex: 1, usedMetric: .metric)
        firstEntry.sets = [
            ExerciseSet(repetitions: 12, weight: 60, done: true, orderIndex: 1, usedMetric: .metric),
            ExerciseSet(repetitions: 8, weight: 40, done: true, orderIndex: 0, usedMetric: .metric)
        ]
        let secondEntry = ExerciseEntry(exercise: second, orderIndex: 0, usedMetric: .metric)
        secondEntry.sets = [
            ExerciseSet(repetitions: 10, weight: 50, done: true, orderIndex: 0, usedMetric: .metric)
        ]
        let workout = Workout(name: "History Ordering")
        workout.exercises = [firstEntry, secondEntry]
        context.insert(first)
        context.insert(second)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        XCTAssertTrue(viewModel.saveWorkout(using: context))

        XCTAssertEqual(workout.orderedExercises.map { $0.exercise.name }, ["Second", "First"])
        let savedFirstEntry = try XCTUnwrap(
            workout.orderedExercises.first(where: { $0.exercise.name == "First" })
        )
        XCTAssertEqual(savedFirstEntry.orderedSets.map(\.repetitions), [8, 12])

        let performance = try ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: first, before: Date(timeIntervalSinceNow: 1))
        XCTAssertEqual(performance?.sets.map(\.orderIndex), [0, 1])
        XCTAssertEqual(performance?.sets.map(\.repetitions), [8, 12])
    }

    func testOrphanCleanupDeletesUnownedEntriesAndSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetitions: 8, weight: 50, usedMetric: .metric)]
        context.insert(exercise)
        context.insert(entry)
        try context.save()

        let result = try DataMaintenanceService.cleanupOrphans(using: context)

        XCTAssertEqual(result.deletedExercises, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
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
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        context.insert(exercise)
        context.insert(entry)

        entry.startActiveDuration(at: startedAt)
        entry.stopActiveDuration(at: startedAt.addingTimeInterval(42))
        entry.startActiveDuration(at: startedAt.addingTimeInterval(60))
        try context.save()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciseEntry>()).first)
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
        let priorWorkout = Workout(name: "Prior", endTime: .now)
        priorWorkout.startTime = .now.addingTimeInterval(-86_400)
        let priorEntry = ExerciseEntry(exercise: exercise, usedMetric: .imperial)
        priorEntry.sets = [
            ExerciseSet(repetitions: 20, weight: 45, done: true, setType: .warmup, orderIndex: 0, usedMetric: .imperial),
            ExerciseSet(repetitions: 12, weight: 100, done: true, orderIndex: 1, usedMetric: .imperial),
            ExerciseSet(repetitions: 12, weight: 100, done: true, orderIndex: 2, usedMetric: .imperial)
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
        let assistedExercise = Exercise(
            name: "Assisted Pull-up",
            primaryMuscles: [.latissimusDorsi],
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
        let openSet = ExerciseSet(repetitions: 0, weight: 0, orderIndex: 0, usedMetric: .metric)
        let completedSet = ExerciseSet(repetitions: 8, weight: 80, done: true, orderIndex: 1, usedMetric: .imperial)
        let entry = ExerciseEntry(exercise: exercise, sets: [openSet, completedSet], usedMetric: .metric)
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 105
        entry.recommendedUnit = .lbs
        let workout = Workout(name: "Active")
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
        let openSet = ExerciseSet(repetitions: 0, weight: 0, orderIndex: 0, usedMetric: .metric)
        let completedSet = ExerciseSet(repetitions: 8, weight: 80, done: true, orderIndex: 1, usedMetric: .imperial)
        let entry = ExerciseEntry(exercise: exercise, sets: [openSet, completedSet], usedMetric: .metric)
        entry.recommendationPriorLoad = 100
        entry.recommendedUnit = .lbs
        let workout = Workout(name: "Active")
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
        let eligible = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        eligible.prescribedSets = 3
        eligible.prescribedRepRangeMaximum = 12
        eligible.prescribedProgressionRule = .doubleProgression

        guard case .insufficientHistory? = RecommendationPresentationState(entry: eligible) else {
            return XCTFail("Expected an insufficient-history presentation")
        }

        eligible.prescribedProgressionRule = ProgressionRule.none
        XCTAssertNil(RecommendationPresentationState(entry: eligible))
    }

    func testPlannedWorkoutSnapshotsProgressionAndPreservesRule() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let priorWorkout = Workout(name: "Prior", endTime: .now)
        priorWorkout.startTime = .now.addingTimeInterval(-86_400)
        let priorEntry = ExerciseEntry(exercise: exercise, usedMetric: .imperial)
        priorEntry.sets = (0..<3).map {
            ExerciseSet(repetitions: 12, weight: 100, done: true, orderIndex: $0, usedMetric: .imperial)
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
        let lowerExercise = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
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

    func testPlanCreationBuildsAnOrderedScheduledDeloadBlock() {
        let exercise = makeExercise()
        let template = WorkoutTemplate(
            name: "Full Body",
            exercises: [exercise],
            templateExercises: [TemplateExercise(exercise: exercise, order: 0)]
        )

        let plan = PlanCoordinator.createPlan(
            name: "Four Week Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 4,
            dayAssignments: [.init(dayOffset: 0, template: template)],
            deload: .init(
                weekIndex: 2,
                volumeReductionPercent: 50,
                intensityReductionPercent: 10
            )
        )

        XCTAssertEqual(plan.orderedBlocks.map(\.phaseType), [.accumulation, .deload, .accumulation])
        XCTAssertEqual(plan.orderedBlocks.map { $0.orderedWeeks.map(\.weekIndex) }, [[0, 1], [2], [3]])
        XCTAssertEqual(plan.orderedWeeks.map(\.weekIndex), [0, 1, 2, 3])

        let deload = plan.orderedBlocks[1]
        XCTAssertEqual(deload.effectiveDeloadVolumeReductionPercent, 50)
        XCTAssertEqual(deload.effectiveDeloadIntensityReductionPercent, 10)
    }

    func testScheduledDeloadAdjustsOnlyTheNewWorkoutSnapshot() throws {
        let exercise = makeExercise()
        let template = WorkoutTemplate(
            name: "Full Body",
            exercises: [exercise],
            templateExercises: [
                TemplateExercise(
                    exercise: exercise,
                    order: 0,
                    targetSets: 3,
                    repRangeMinimum: 6,
                    repRangeMaximum: 8
                )
            ]
        )
        let plan = PlanCoordinator.createPlan(
            name: "Deload Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [.init(dayOffset: 0, template: template)],
            deload: .init(
                weekIndex: 0,
                volumeReductionPercent: 50,
                intensityReductionPercent: 10
            )
        )
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedExercise = try XCTUnwrap(plannedWorkout.orderedPlannedExercises.first)
        plannedExercise.suggestedLoad = 100
        plannedExercise.suggestedLoadType = .kg

        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let entry = try XCTUnwrap(workout.orderedExercises.first)

        XCTAssertEqual(entry.prescribedSets, 2)
        XCTAssertEqual(entry.sets.count, 2)
        XCTAssertEqual(entry.prescribedSuggestedLoad, 90)
        XCTAssertTrue(entry.sets.allSatisfy { $0.weight == 90 })
        XCTAssertEqual(plannedExercise.targetSets, 3)
        XCTAssertEqual(plannedExercise.suggestedLoad, 100)
    }

    func testPlanEquipmentRequirementsAreNormalizedAtCreationAndEditing() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Barbell Row",
            primaryMuscles: [.latissimusDorsi],
            equipmentType: .barbell
        )
        let template = WorkoutTemplate(
            name: "Pull",
            exercises: [exercise],
            templateExercises: [TemplateExercise(exercise: exercise, order: 0)]
        )
        let plan = PlanCoordinator.createPlan(
            name: "Equipment Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            requiredEquipment: [.dumbbell, .barbell, .dumbbell],
            durationWeeks: 1,
            dayAssignments: [.init(dayOffset: 0, template: template)]
        )

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        try context.save()

        XCTAssertEqual(plan.requiredEquipment, [.barbell, .dumbbell])

        var draft = PlanEditorDraft(plan: plan)
        draft.requiredEquipment = [.cable, .barbell, .cable]
        draft.apply(to: plan, using: context)

        XCTAssertEqual(plan.requiredEquipment, [.barbell, .cable])
    }

    func testPlannedVersusPerformedComparisonReportsMetAboveBelowAndNoTarget() {
        let exercise = makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.prescribedSets = 3
        entry.prescribedRepRangeMinimum = 8
        entry.prescribedRepRangeMaximum = 12
        entry.prescribedSuggestedLoad = 50
        entry.prescribedSuggestedLoadType = .kg
        entry.sets = (0..<3).map {
            ExerciseSet(repetitions: 12, weight: 50, done: true, orderIndex: $0, usedMetric: .metric)
        }

        var comparison = WorkoutPerformanceComparison(exercise: entry)
        XCTAssertEqual(comparison.sets, .met)
        XCTAssertEqual(comparison.reps, .met)
        XCTAssertEqual(comparison.load, .met)
        XCTAssertEqual(comparison.overall, .met)

        entry.sets[0].repetitions = 13
        comparison = WorkoutPerformanceComparison(exercise: entry)
        XCTAssertEqual(comparison.reps, .above)
        XCTAssertEqual(comparison.overall, .above)

        entry.sets[1].weight = 45
        comparison = WorkoutPerformanceComparison(exercise: entry)
        XCTAssertEqual(comparison.load, .below)
        XCTAssertEqual(comparison.overall, .below)

        let freeEntry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
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
        activeSet.repetitions = 8
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
        XCTAssertEqual(activeWorkout.orderedExercises.map(\.exercise.name), ["Bench Press"])
        XCTAssertFalse(WorkoutViewModel().restoreActiveWorkout(using: context))
    }

    func testPartialPlannedWorkoutSaveKeepsOnlyCompletedSetsAndAdvancesOnce() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let template = makeTemplate(exercise: exercise, targetSets: 2)
        let plan = PlanCoordinator.createPlan(
            name: "Partial Planned Save",
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
        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(
            viewModel.startWorkout(
                from: plannedWorkout,
                progress: firstProgress,
                in: run,
                using: context
            )
        )

        let activeWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let activeEntry = try XCTUnwrap(activeWorkout.orderedExercises.first)
        let completedSet = try XCTUnwrap(activeEntry.orderedSets.first)
        completedSet.repetitions = 8
        completedSet.weight = 50
        completedSet.done = true

        XCTAssertTrue(viewModel.saveWorkout(using: context))
        XCTAssertFalse(viewModel.saveWorkout(using: context))
        XCTAssertEqual(firstProgress.status, .completed)
        XCTAssertEqual(run.orderedWorkoutProgress[1].status, .available)
        XCTAssertEqual(activeWorkout.status, .completed)
        XCTAssertEqual(activeWorkout.orderedExercises.count, 1)
        XCTAssertEqual(activeWorkout.orderedExercises.first?.orderedSets.count, 1)
        XCTAssertTrue(activeWorkout.orderedExercises.first?.orderedSets.first?.done == true)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .completed }.count,
            1
        )
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
        let emptyExercise = Exercise(name: "Cable Fly", primaryMuscles: [.upperChest])
        let workout = Workout(name: "Partial")
        let completedEntry = ExerciseEntry(exercise: completedExercise, usedMetric: .metric)
        completedEntry.sets = [
            ExerciseSet(repetitions: 8, weight: 50, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 0, weight: 50, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let emptyEntry = ExerciseEntry(exercise: emptyExercise, usedMetric: .metric)
        emptyEntry.sets = [ExerciseSet(repetitions: 0, weight: 20, usedMetric: .metric)]
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
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).contains { $0 === completedEntry })
        XCTAssertFalse(try context.fetch(FetchDescriptor<ExerciseEntry>()).contains { $0 === emptyEntry })
    }

    func testInvalidSaveLeavesActiveDraftUntouched() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 0, weight: 50, done: false, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 0, weight: 55, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let workout = Workout(name: "Draft")
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
        let alternative = Exercise(name: "Dumbbell Bench Press", primaryMuscles: [.middleChest])
        let plannedExercise = try XCTUnwrap(
            plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first
        )
        plannedExercise.stimulus = .hypertrophy
        plannedExercise.alternatives = [PlannedExerciseAlternative(exercise: alternative, orderIndex: 0)]
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000)))
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let completedWorkout = Workout(plannedWorkout: firstPlannedWorkout, planRun: run, unitSystem: .metric)
        completedWorkout.status = .completed
        completedWorkout.endTime = Date(timeIntervalSince1970: 1_700_003_600)
        completedWorkout.orderedExercises.first?.orderedSets.first?.repetitions = 8
        completedWorkout.orderedExercises.first?.orderedSets.first?.weight = 50
        completedWorkout.orderedExercises.first?.orderedSets.first?.done = true
        PlanCoordinator.markCompleted(firstProgress, with: completedWorkout, in: run)

        source.insert(exercise)
        source.insert(alternative)
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
        let restoredPlannedExercise = try XCTUnwrap(
            restoredPlan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first
        )
        XCTAssertEqual(restoredPlannedExercise.stimulus, .hypertrophy)
        XCTAssertEqual(restoredPlannedExercise.alternatives.first?.exercise.name, "Dumbbell Bench Press")
    }

    func testInvalidPlanRunBackupDoesNotReplaceExistingData() throws {
        let context = try makeContext()
        let sentinel = Exercise(name: "Do Not Delete", primaryMuscles: [.upperChest])
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
            try context.fetch(FetchDescriptor<Exercise>()).contains { $0.name == sentinel.name }
        )
    }

    func testBackupInterruptionBeforeCommitPreservesExistingDatabase() throws {
        let context = try makeContext()
        let sentinel = Exercise(name: "Keep During Import", primaryMuscles: [.upperChest])
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
            try context.fetch(FetchDescriptor<Exercise>()).contains { $0.name == sentinel.name }
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
    }

    func testBackupReplacementSurvivesDiskRelaunchWithPlanRunHistoryLinks() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let backup = try makePlanRunBackup()

        try withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Replace Me", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()
            try backup.restore(to: context)
        }

        try withDiskContext(at: storeURL) { context in
            let exercises = try context.fetch(FetchDescriptor<Exercise>())
            XCTAssertFalse(exercises.contains { $0.name == "Replace Me" })
            XCTAssertTrue(exercises.contains { $0.name == "Bench Press" })

            let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
            let run = try XCTUnwrap(context.fetch(FetchDescriptor<PlanRun>()).first)
            let workout = try XCTUnwrap(context.fetch(FetchDescriptor<Workout>()).first {
                $0.status == .completed
            })
            let completedProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)

            XCTAssertEqual(plan.name, "Backup Plan")
            XCTAssertEqual(run.plan?.id, plan.id)
            XCTAssertEqual(completedProgress.status, .completed)
            XCTAssertEqual(completedProgress.completedWorkout?.id, workout.id)
            XCTAssertEqual(workout.sourcePlanRunID, run.id)
            XCTAssertEqual(workout.sourcePlannedWorkoutID, completedProgress.plannedWorkoutID)
            XCTAssertEqual(run.orderedWorkoutProgress.dropFirst().first?.status, .available)
        }
    }

    func testCorruptDiskBackupLeavesOriginalDatabaseAfterRelaunch() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        try withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Keep Corrupt Import", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()

            XCTAssertThrowsError(
                try JSONDecoder().decode(BackupDTO.self, from: Data("not-json".utf8))
            )

            let invalidPlanID = UUID().uuidString
            let backup = BackupDTO(
                version: BackupDTO.currentVersion,
                preferences: PreferencesDTO(
                    darkMode: true,
                    restTimer: 120,
                    unitSystem: UnitSystem.imperial.rawValue
                ),
                exercises: [],
                templates: [],
                collections: [],
                workouts: [],
                plans: [],
                planRuns: [
                    PlanRunDTO(
                        id: UUID().uuidString,
                        sourcePlanID: invalidPlanID,
                        sourcePlanName: "Missing plan",
                        planID: invalidPlanID,
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

            XCTAssertThrowsError(try backup.restore(to: context))
        }

        try withDiskContext(at: storeURL) { context in
            XCTAssertTrue(
                try context.fetch(FetchDescriptor<Exercise>()).contains {
                    $0.name == "Keep Corrupt Import"
                }
            )
            XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
        }
    }

    func testInterruptedDiskBackupRestoreLeavesOriginalDatabaseAfterRelaunch() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let backup = try makePlanRunBackup()

        try withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Keep Interrupted Import", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()

            XCTAssertThrowsError(
                try backup.restore(to: context, beforeCommit: {
                    throw NSError(domain: "BackupRestoreTest", code: 2)
                })
            )
        }

        try withDiskContext(at: storeURL) { context in
            XCTAssertTrue(
                try context.fetch(FetchDescriptor<Exercise>()).contains {
                    $0.name == "Keep Interrupted Import"
                }
            )
            XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        }
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
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
            PlannedExerciseAlternative.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeDiskStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymTrackerBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("GymTracker.store")
    }

    private func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
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
            PlannedExerciseAlternative.self,
            configurations: configuration
        )
        return try body(ModelContext(container))
    }

    private func makePlanRunBackup() throws -> BackupDTO {
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
        let run = try XCTUnwrap(
            PlanCoordinator.startRun(
                for: plan,
                startDate: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(
            PlanCoordinator.plannedWorkout(for: firstProgress, in: run)
        )
        let completedWorkout = Workout(
            plannedWorkout: firstPlannedWorkout,
            planRun: run,
            unitSystem: .metric
        )
        completedWorkout.status = .completed
        completedWorkout.endTime = Date(timeIntervalSince1970: 1_700_003_600)
        let firstSet = try XCTUnwrap(completedWorkout.orderedExercises.first?.orderedSets.first)
        firstSet.repetitions = 8
        firstSet.weight = 50
        firstSet.done = true
        PlanCoordinator.markCompleted(firstProgress, with: completedWorkout, in: run)

        source.insert(exercise)
        source.insert(template)
        source.insert(plan)
        source.insert(run)
        source.insert(completedWorkout)
        try source.save()

        return try BackupDTO.create(
            from: source,
            restTimer: 120,
            darkMode: true,
            unitSystem: .imperial
        )
    }

    private func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
    }

    private func makeTemplate(
        exercise: Exercise,
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
        with exercise: Exercise,
        reps: Float = 8,
        weight: Float = 50
    ) -> Workout {
        let set = ExerciseSet(repetitions: reps, weight: weight, done: true, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Test Workout", endTime: .now)
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

    func testBackupExportKeysRemainUnchanged() throws {
        let exercise = ExerciseTemplateDTO(
            name: "Bench Press",
            primaryMuscles: ["chest"],
            secondaryMuscles: ["triceps"],
            category: "strength",
            trackingType: "weight",
            equipmentType: "barbell",
            resistanceType: nil,
            movementPattern: nil,
            difficulty: "intermediate",
            tags: ["heavy"],
            isFavorite: true,
            isPlateLoaded: true,
            isCustom: true,
            isArchived: false,
            forceType: "Push",
            mechanics: "Compound",
            laterality: "Bilateral",
            repCountingStyle: "Total",
            weightEntryStyle: "Per Load Unit",
            loadUnitCount: 2,
            gripStyle: "Pronated",
            stance: "Supine",
            rangeOfMotion: "Full",
            setupAngleDegrees: 30,
            variationFamilyID: "bench-press"
        )
        let set = ExerciseSetDTO(
            orderIndex: 0,
            weightType: "kg",
            distanceType: "km",
            repetition: 8,
            weight: 100,
            duration: 60.0,
            distance: nil,
            done: true,
            rpe: 8,
            setType: "normal",
            usedMetric: "metric"
        )
        let entry = ExerciseEntryDTO(
            orderIndex: 0,
            comment: "good set",
            exerciseName: "Bench Press",
            usedMetric: "metric",
            sets: [set],
            prescribedSets: 3,
            prescribedRepRangeMinimum: 6,
            prescribedRepRangeMaximum: 8,
            prescribedRestSeconds: 90,
            prescribedRPE: 8.0,
            prescribedRIR: nil,
            prescriptionNotes: "heavy",
            sourcePlannedExerciseID: nil,
            prescribedRole: "main",
            isPrescribedOptional: false,
            prescribedSuggestedLoad: nil,
            prescribedSuggestedLoadType: nil,
            prescribedProgressionRule: "doubleProgression",
            recommendedDecision: "increase",
            recommendedLoad: 102.5,
            recommendedUnit: "kg",
            recommendationPriorLoad: 100.0,
            recommendationRequiredSets: 3,
            recommendationRepCeiling: 8,
            recommendationCompletedSets: 3,
            recommendationPriorWorkoutDate: Date(),
            accumulatedActiveDuration: 120.0,
            activeDurationStartedAt: Date()
        )
        let workout = WorkoutDTO(
            id: UUID().uuidString,
            status: "completed",
            name: "My Workout",
            notes: "heavy day",
            startTime: Date(),
            endTime: Date(),
            restEndDate: nil,
            pausedRemainingTime: nil,
            sourceTemplateName: "My Template",
            sourcePlanID: nil,
            sourcePlanRunID: nil,
            sourcePlanBlockID: nil,
            sourcePlanWeekID: nil,
            sourcePlannedWorkoutID: nil,
            sourcePlanName: nil,
            exercises: [entry]
        )
        let backup = BackupDTO(
            version: 2,
            preferences: PreferencesDTO(darkMode: true, restTimer: 90, unitSystem: "metric"),
            exercises: [exercise],
            templates: [
                WorkoutTemplateDTO(
                    name: "My Template",
                    templateExercises: [
                        TemplateExerciseDTO(
                            exerciseName: "Bench Press",
                            orderIndex: 0,
                            targetSets: 3,
                            repRangeMinimum: 6,
                            repRangeMaximum: 8,
                            restSeconds: 90,
                            targetRPE: 8.0,
                            targetRIR: nil,
                            notes: "Focus",
                            progressionRule: "doubleProgression"
                        )
                    ]
                )
            ],
            collections: [
                WorkoutCollectionDTO(
                    name: "My Collection",
                    templateNames: ["My Template"]
                )
            ],
            workouts: [workout],
            exerciseRelationships: [
                ExerciseRelationshipDTO(
                    sourceExerciseName: "Bench Press",
                    targetExerciseName: "Dumbbell Bench Press",
                    type: "Substitution"
                )
            ]
        )

        let encoded = try JSONEncoder().encode(backup)
        let jsonObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        // Verify root keys
        XCTAssertEqual(jsonObject["version"] as? Int, 2)
        let preferences = try XCTUnwrap(jsonObject["preferences"] as? [String: Any])
        XCTAssertEqual(preferences["darkMode"] as? Bool, true)
        XCTAssertEqual(preferences["restTimer"] as? Int, 90)
        XCTAssertEqual(preferences["unitSystem"] as? String, "metric")

        let relationships = try XCTUnwrap(jsonObject["exerciseRelationships"] as? [[String: Any]])
        XCTAssertEqual(relationships.first?["sourceExerciseName"] as? String, "Bench Press")
        XCTAssertEqual(relationships.first?["type"] as? String, "Substitution")

        // Verify exercises
        let exercises = try XCTUnwrap(jsonObject["exercises"] as? [[String: Any]])
        let firstEx = try XCTUnwrap(exercises.first)
        XCTAssertEqual(firstEx["name"] as? String, "Bench Press")
        XCTAssertEqual(firstEx["primaryMuscles"] as? [String], ["chest"])
        XCTAssertEqual(firstEx["secondaryMuscles"] as? [String], ["triceps"])
        XCTAssertEqual(firstEx["isPlateLoaded"] as? Bool, true)
        XCTAssertEqual(firstEx["variationFamilyID"] as? String, "bench-press")
        XCTAssertEqual(firstEx["setupAngleDegrees"] as? Int, 30)
        XCTAssertEqual(firstEx["weightEntryStyle"] as? String, "Per Load Unit")

        // Verify templates
        let templates = try XCTUnwrap(jsonObject["templates"] as? [[String: Any]])
        let firstTemp = try XCTUnwrap(templates.first)
        XCTAssertEqual(firstTemp["name"] as? String, "My Template")
        let tempExs = try XCTUnwrap(firstTemp["templateExercises"] as? [[String: Any]])
        let firstTempEx = try XCTUnwrap(tempExs.first)
        XCTAssertEqual(firstTempEx["exerciseName"] as? String, "Bench Press")
        XCTAssertEqual(firstTempEx["progressionRule"] as? String, "doubleProgression")

        // Verify collections
        let collections = try XCTUnwrap(jsonObject["collections"] as? [[String: Any]])
        let firstColl = try XCTUnwrap(collections.first)
        XCTAssertEqual(firstColl["name"] as? String, "My Collection")
        XCTAssertEqual(firstColl["templateNames"] as? [String], ["My Template"])

        // Verify workouts
        let workouts = try XCTUnwrap(jsonObject["workouts"] as? [[String: Any]])
        let firstWorkout = try XCTUnwrap(workouts.first)
        XCTAssertEqual(firstWorkout["name"] as? String, "My Workout")
        let workoutExs = try XCTUnwrap(firstWorkout["exercises"] as? [[String: Any]])
        let firstWorkoutEx = try XCTUnwrap(workoutExs.first)
        XCTAssertEqual(firstWorkoutEx["exerciseName"] as? String, "Bench Press")
        XCTAssertEqual(firstWorkoutEx["comment"] as? String, "good set")
        let workoutSets = try XCTUnwrap(firstWorkoutEx["sets"] as? [[String: Any]])
        let firstWorkoutSet = try XCTUnwrap(workoutSets.first)
        XCTAssertEqual(firstWorkoutSet["repetition"] as? Float, 8)
        XCTAssertEqual(firstWorkoutSet["weight"] as? Float, 100)
    }

    func testWorkoutTemplateSeedingAndCollectionCreation() throws {
        let context = try makeContext()
        let exercises = ExerciseSeedData.templates()
        for exercise in exercises {
            context.insert(exercise)
        }
        try context.save()

        let seededTemplates = WorkoutTemplateSeedData.templates(using: exercises)
        XCTAssertEqual(seededTemplates.count, 4)

        let expectedNames = [
            "Day 1 – Lower Body (Squat Focus)",
            "Day 2 – Upper Body (Push/Pull)",
            "Day 3 – Lower Body (Posterior Chain)",
            "Day 4 – Upper Body (Vertical Push/Pull)"
        ]
        XCTAssertEqual(seededTemplates.map(\.name), expectedNames)

        for template in seededTemplates {
            context.insert(template)
        }
        try context.save()

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let seedNames = Set(WorkoutTemplateSeedData.seededTemplateNames)
        let programTemplates = templates.filter { seedNames.contains($0.name) }
        XCTAssertEqual(programTemplates.count, 4)

        let orderedTemplates = WorkoutTemplateSeedData.seededTemplateNames.compactMap { name in
            programTemplates.first { $0.name == name }
        }
        let collection = WorkoutCollection(name: WorkoutTemplateSeedData.collectionName, workoutTemplates: orderedTemplates)
        context.insert(collection)
        try context.save()

        let fetchedCollections = try context.fetch(FetchDescriptor<WorkoutCollection>())
        XCTAssertEqual(fetchedCollections.count, 1)
        let firstCollection = try XCTUnwrap(fetchedCollections.first)
        XCTAssertEqual(firstCollection.name, WorkoutTemplateSeedData.collectionName)
        XCTAssertEqual(Set(firstCollection.workoutTemplates.map(\.name)), Set(expectedNames))

        let existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let existingNames = Set(existingTemplates.map(\.name))

        for template in WorkoutTemplateSeedData.templates(using: exercises) where !existingNames.contains(template.name) {
            context.insert(template)
        }
        try context.save()

        let afterReSeedTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(afterReSeedTemplates.count, 4)
    }
}

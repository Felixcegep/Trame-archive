import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutIntegrityTests: XCTestCase {
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

    func testBackupDefaultsMissingPlannedExerciseStimulus() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let template = makeTemplate(exercise: exercise, targetSets: 1)
        let plan = PlanCoordinator.createPlan(
            name: "Legacy Stimulus Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [.init(dayOffset: 0, template: template)]
        )
        let plannedExercise = try XCTUnwrap(
            plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first
        )
        plannedExercise.stimulus = nil

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        try context.save()

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )

        XCTAssertEqual(
            backup.plans.first?.blocks.first?.weeks.first?.plannedWorkouts.first?.plannedExercises.first?.stimulus,
            TrainingStimulus.strength.rawValue
        )
    }

    private func makeDiskStoreURL() throws -> URL {
        try WorkoutTestFixture.makeDiskStoreURL()
    }

    private func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        try WorkoutTestFixture.withDiskContext(at: url, body)
    }

    private func makeExercise() -> Exercise {
        WorkoutTestFixture.makeExercise()
    }

    private func makeTemplate(
        exercise: Exercise,
        targetSets: Int
    ) -> WorkoutTemplate {
        WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: targetSets)
    }

    private func makeWorkout(
        with exercise: Exercise,
        reps: Float = 8,
        weight: Float = 50
    ) -> Workout {
        WorkoutTestFixture.makeWorkout(with: exercise, reps: reps, weight: weight)
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
            activeDurationStartedAt: Date(),
            originalExerciseIDSnapshot: UUID().uuidString,
            originalExerciseNameSnapshot: "Barbell Bench Press",
            selectedSubstituteExerciseIDSnapshot: UUID().uuidString,
            substitutionReason: "Shoulder-friendly variation",
            substitutionSharesProgressionState: false
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

        let workoutEntries = try XCTUnwrap(
            (jsonObject["workouts"] as? [[String: Any]])?.first?["exercises"] as? [[String: Any]]
        )
        XCTAssertEqual(workoutEntries.first?["originalExerciseNameSnapshot"] as? String, "Barbell Bench Press")
        XCTAssertEqual(workoutEntries.first?["substitutionReason"] as? String, "Shoulder-friendly variation")
        XCTAssertEqual(workoutEntries.first?["substitutionSharesProgressionState"] as? Bool, false)

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
        // The exact-order name match below already implies the count matches
        // `seededTemplateNames`, so no separate literal count assertion is
        // needed; comparing against the production list (rather than a
        // hand-copied literal) keeps this test moving in lockstep with the
        // program's actual day count instead of silently drifting from it.
        XCTAssertEqual(seededTemplates.map(\.name), WorkoutTemplateSeedData.seededTemplateNames)

        for template in seededTemplates {
            context.insert(template)
        }
        try context.save()

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let seedNames = Set(WorkoutTemplateSeedData.seededTemplateNames)
        let programTemplates = templates.filter { seedNames.contains($0.name) }
        XCTAssertEqual(
            Set(programTemplates.map(\.name)),
            seedNames,
            "Every seeded template name must be present after seeding."
        )
        XCTAssertEqual(
            programTemplates.count,
            seedNames.count,
            "Seeding must not insert more than one template per seed name."
        )

        let orderedTemplates = WorkoutTemplateSeedData.seededTemplateNames.compactMap { name in
            programTemplates.first { $0.name == name }
        }
        let collection = WorkoutCollection(name: WorkoutTemplateSeedData.collectionName, workoutTemplates: orderedTemplates)
        context.insert(collection)
        try context.save()

        let fetchedCollections = try context.fetch(FetchDescriptor<WorkoutCollection>())
        XCTAssertEqual(fetchedCollections.count, 1, "A single insert must yield a single collection.")
        let firstCollection = try XCTUnwrap(fetchedCollections.first)
        XCTAssertEqual(firstCollection.name, WorkoutTemplateSeedData.collectionName)
        XCTAssertEqual(Set(firstCollection.workoutTemplates.map(\.name)), seedNames)

        let existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let existingNames = Set(existingTemplates.map(\.name))

        for template in WorkoutTemplateSeedData.templates(using: exercises) where !existingNames.contains(template.name) {
            context.insert(template)
        }
        try context.save()

        let afterReSeedTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(
            afterReSeedTemplates.count,
            templates.count,
            "Re-seeding an already-seeded catalogue must not create duplicate templates."
        )
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}

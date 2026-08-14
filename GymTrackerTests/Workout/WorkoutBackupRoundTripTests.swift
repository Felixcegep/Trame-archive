import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutBackupRoundTripTests: XCTestCase {
    func testCurrentBackupRestoresDuplicateDisplayNamesByStableExerciseIdentity() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let customExercise = Exercise(
            name: "Bench Press",
            primaryMuscles: [.upperChest],
            isCustom: true
        )
        let template = WorkoutTestFixture.makeTemplate(exercise: customExercise, targetSets: 3)
        let workout = WorkoutTestFixture.makeWorkout(with: customExercise)
        source.insert(customExercise)
        source.insert(template)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let restoredCustom = try XCTUnwrap(
            restored.fetch(FetchDescriptor<Exercise>()).first { $0.id == customExercise.id }
        )
        XCTAssertTrue(restoredCustom.isCustom)
        XCTAssertEqual(
            try restored.fetch(FetchDescriptor<WorkoutTemplate>())
                .first { $0.name == template.name }?
                .orderedTemplateExercises.first?.exercise.id,
            restoredCustom.id
        )
        XCTAssertEqual(
            try restored.fetch(FetchDescriptor<Workout>())
                .first { $0.id == workout.id }?
                .orderedExercises.first?.exercise.id,
            restoredCustom.id
        )
    }

    func testLegacyBackupDefaultsTemplateProgressionToDoubleProgression() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let backup = BackupDTO(
            version: BackupDTO.legacyVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [
                ExerciseTemplateDTO(
                    name: "Legacy Progression Exercise",
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
                            exerciseName: "Legacy Progression Exercise",
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
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
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
        let workout = WorkoutTestFixture.makeWorkout(with: exercise)
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
        let restored = try GymTrackerTestStore.makeInMemoryContext()
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
        // The recommendation-snapshot fields on ExerciseEntry (recommendedDecision,
        // recommendedLoad, recommendedUnit, recommendationPriorLoad,
        // recommendationRequiredSets, recommendationRepCeiling,
        // recommendationCompletedSets, recommendationPriorWorkoutDate) round-trip
        // through this same BackupDTO.create → encode → decode → restore path and
        // are asserted field-by-field in
        // `BackupFieldCoverageTests.testExerciseEntryRoundTripsEveryPersistedField`.
        // A non-nil recommendation is enough evidence here that the snapshot
        // survived; this test's unique value is the TemplateExercise
        // `progressionRule` round trip asserted above, which the sentinel does
        // not cover.
        XCTAssertNotNil(restoredEntry.recommendedDecision)
    }

    func testBackupRoundTripsDeferredBackOffSnapshotWithoutDuplicatingGeneratedWork() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let dailyMaximum = ExerciseSet(
            repetitions: 1,
            weight: 100,
            done: true,
            setType: .dailyMaximum,
            orderIndex: 0,
            usedMetric: .metric
        )
        dailyMaximum.prescribedSetType = .dailyMaximum
        dailyMaximum.isSelectedDailyMaximum = true
        let entry = ExerciseEntry(exercise: exercise, sets: [dailyMaximum], usedMetric: .metric)
        entry.progressionKey = "clean"
        let deferredBackOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(2),
            load: LoadPrescription(
                reference: .init(kind: .dailyMaximum, exposureKey: "clean"),
                percentage: 0.85
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([deferredBackOff])
        let workout = Workout(name: "Clean day")
        workout.exercises = [entry]
        source.insert(exercise)
        source.insert(workout)
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try JSONDecoder().decode(BackupDTO.self, from: JSONEncoder().encode(backup)).restore(to: restored)

        let restoredWorkout = try XCTUnwrap(
            restored.fetch(FetchDescriptor<Workout>()).first { $0.id == workout.id }
        )
        let restoredEntry = try XCTUnwrap(restoredWorkout.orderedExercises.first)
        let restoredDefinitions = try JSONDecoder().decode(
            [SetPrescriptionDefinition].self,
            from: try XCTUnwrap(restoredEntry.deferredBackOffDefinitionsData)
        )
        XCTAssertEqual(restoredDefinitions, [deferredBackOff])
        XCTAssertTrue(restoredEntry.orderedSets.contains { $0.isSelectedDailyMaximum })
        XCTAssertEqual(
            restoredEntry.orderedSets.filter {
                $0.generatedBackOffDefinitionID == deferredBackOff.id
            }.count,
            1
        )

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: restoredWorkout)

        let restoredBackOffs = restoredEntry.orderedSets.filter {
            $0.generatedBackOffDefinitionID == deferredBackOff.id
        }
        XCTAssertEqual(restoredBackOffs.count, 1)
        XCTAssertEqual(restoredBackOffs.first?.prescribedSuggestedLoad ?? 0, 85, accuracy: 0.001)
    }

    func testDeferredBackOffSurvivesDiskRelaunchWithoutDuplicateGeneration() throws {
        let url = try WorkoutTestFixture.makeDiskStoreURL()
        let workoutID = UUID()
        let deferredBackOffID = UUID()

        try WorkoutTestFixture.withDiskContext(at: url) { context in
            let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
            let topSet = ExerciseSet(
                repetitions: 5,
                weight: 100,
                done: true,
                setType: .topSet,
                orderIndex: 0,
                usedMetric: .metric
            )
            topSet.prescribedSetType = .topSet
            let entry = ExerciseEntry(exercise: exercise, sets: [topSet], usedMetric: .metric)
            entry.progressionKey = "bench"
            let deferredBackOff = SetPrescriptionDefinition(
                id: deferredBackOffID,
                orderIndex: 1,
                role: .backOff,
                repetitions: .fixed(5),
                load: LoadPrescription(
                    reference: .init(kind: .topSet, exposureKey: "bench"),
                    percentage: 0.9
                ),
                generatesAfterSourceCompletion: true
            )
            entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([deferredBackOff])
            let workout = Workout(name: "Press")
            workout.exercises = [entry]
            workout.id = workoutID
            context.insert(exercise)
            context.insert(workout)
            ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
            try context.save()
        }

        try WorkoutTestFixture.withDiskContext(at: url) { context in
            let workout = try XCTUnwrap(
                context.fetch(FetchDescriptor<Workout>()).first { $0.id == workoutID }
            )
            ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
            let entry = try XCTUnwrap(workout.orderedExercises.first)
            let generated = entry.orderedSets.filter {
                $0.generatedBackOffDefinitionID == deferredBackOffID
            }
            XCTAssertEqual(generated.count, 1)
            XCTAssertEqual(generated.first?.prescribedSuggestedLoad ?? 0, 90, accuracy: 0.001)
        }
    }

    func testBackupRoundTripsPlanRunProgressAndCompletedWorkoutIdentity() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
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
        plannedExercise.plannedSets = [
            PlannedSet(
                orderIndex: 0,
                setType: .warmup,
                repetitions: 10,
                suggestedLoad: 20,
                suggestedLoadType: .kg,
                restSeconds: 45
            ),
            PlannedSet(
                orderIndex: 1,
                setType: .normal,
                repRangeMinimum: 6,
                repRangeMaximum: 8,
                suggestedLoad: 50,
                suggestedLoadType: .kg,
                targetRPE: 8,
                targetRIR: 2,
                notes: "Working set"
            )
        ]
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000)))
        run.progressionStates.append(
            PlanExerciseProgressionState(
                progressionKey: plannedExercise.progressionKey,
                scopeRaw: ProgressionScope.week.rawValue,
                scopeOwnerKey: "week:1",
                currentLoad: 55
            )
        )
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let completedWorkout = Workout(plannedWorkout: firstPlannedWorkout, planRun: run, unitSystem: .metric)
        completedWorkout.status = .completed
        completedWorkout.endTime = Date(timeIntervalSince1970: 1_700_003_600)
        completedWorkout.orderedExercises.first?.orderedSets.first?.repetitions = 8
        completedWorkout.orderedExercises.first?.orderedSets.first?.weight = 50
        completedWorkout.orderedExercises.first?.orderedSets.first?.done = true
        completedWorkout.orderedExercises.first?.orderedSets.first?.prescribedUnroundedLoad = 52.4
        completedWorkout.orderedExercises.first?.orderedSets.first?.prescriptionLoadExplanation = "Training Max 65.5 × 80% = 52.4 → rounded to 52.5."
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
        let restored = try GymTrackerTestStore.makeInMemoryContext()
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
        let restoredScopedState = try XCTUnwrap(restoredRun.progressionStates.first {
            $0.progressionKey == plannedExercise.progressionKey
                && $0.scopeRaw == ProgressionScope.week.rawValue
                && $0.scopeOwnerKey == "week:1"
        })
        XCTAssertEqual(restoredScopedState.currentLoad ?? 0, 55, accuracy: 0.001)
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
        XCTAssertEqual(restoredPlannedExercise.orderedPlannedSets.map(\.setType), [.warmup, .normal])
        XCTAssertEqual(restoredPlannedExercise.orderedPlannedSets.last?.targetRPE, 8)
        XCTAssertEqual(restoredPlannedExercise.orderedPlannedSets.last?.notes, "Working set")
        let restoredSet = try XCTUnwrap(restoredWorkout.orderedExercises.first?.orderedSets.first)
        XCTAssertEqual(restoredSet.prescribedSetType, .warmup)
        XCTAssertEqual(restoredSet.prescribedRepetitions, 10)
        XCTAssertEqual(restoredSet.prescribedRestSeconds, 45)
        XCTAssertEqual(restoredSet.prescribedUnroundedLoad, 52.4)
        XCTAssertEqual(restoredSet.prescriptionLoadExplanation, "Training Max 65.5 × 80% = 52.4 → rounded to 52.5.")
    }
}

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramDeferredPrescriptionIntegrationTests: XCTestCase {
    func testSignedProgressionOffsetsReduceTheNextPrescriptionWithoutGoingBelowSafeLimits() throws {
        let exercise = Exercise(name: "Reduced Squat", primaryMuscles: [.quadriceps])
        let firstDefinition = SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), restSeconds: 90)
        let secondDefinition = SetPrescriptionDefinition(orderIndex: 1, repetitions: .fixed(5), restSeconds: 90)
        let plannedExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            targetSets: 2,
            repRangeMinimum: 5,
            repRangeMaximum: 5,
            plannedSets: [
                PlannedSet(orderIndex: 0, repetitions: 5, restSeconds: 90, definitionData: try JSONEncoder().encode(firstDefinition)),
                PlannedSet(orderIndex: 1, repetitions: 5, restSeconds: 90, definitionData: try JSONEncoder().encode(secondDefinition))
            ],
            progressionKey: "reduced-squat"
        )
        let entry = ExerciseEntry(from: plannedExercise, orderIndex: 0, usedMetric: .metric)
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Reduction", startDate: .now)
        run.progressionStates = [PlanExerciseProgressionState(
            progressionKey: "reduced-squat",
            repetitionOffset: -2,
            setCountOffset: -1,
            restDurationOffset: -120
        )]

        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric
        )

        XCTAssertEqual(entry.orderedSets.count, 1)
        XCTAssertEqual(entry.prescribedSets, 1)
        XCTAssertEqual(entry.orderedSets.first?.prescribedRepetitions, 3)
        XCTAssertEqual(entry.orderedSets.first?.prescribedRestSeconds, 0)
    }

    func testDerivedDailyMaximumLoadDoesNotUseAnUnrelatedTopSet() throws {
        let exercise = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let dailyMaximum = ExerciseSet(repetitions: 1, weight: 100, done: true, orderIndex: 0, usedMetric: .metric)
        dailyMaximum.prescribedSetType = .dailyMaximum
        dailyMaximum.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 0,
            role: .dailyMaximum,
            repetitions: .fixed(1)
        ))
        let topSet = ExerciseSet(repetitions: 1, weight: 120, done: true, orderIndex: 1, usedMetric: .metric)
        topSet.prescribedSetType = .topSet
        topSet.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 1,
            role: .topSet,
            repetitions: .fixed(1)
        ))
        let backOff = ExerciseSet(repetitions: 2, weight: 0, done: false, orderIndex: 2, usedMetric: .metric)
        backOff.prescribedSetType = .backoff
        backOff.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 2,
            role: .backOff,
            repetitions: .fixed(2),
            load: LoadPrescription(
                reference: .init(kind: .dailyMaximum, exposureKey: "clean"),
                percentage: 0.85
            )
        ))
        let entry = ExerciseEntry(exercise: exercise, sets: [dailyMaximum, topSet, backOff], usedMetric: .metric)
        entry.progressionKey = "clean"
        let workout = Workout(name: "Olympic")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(backOff.prescribedSuggestedLoad ?? 0, 85, accuracy: 0.001)
    }

    func testDerivedDailyMaximumLoadUsesAUserAddedTechnicalMaximumAttempt() throws {
        let exercise = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let initialMaximum = ExerciseSet(
            repetitions: 1,
            weight: 100,
            setType: .dailyMaximum,
            orderIndex: 0,
            usedMetric: .metric
        )
        initialMaximum.prescribedSetType = .dailyMaximum
        initialMaximum.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 0,
            role: .dailyMaximum,
            repetitions: .fixed(1)
        ))
        initialMaximum.done = true
        let addedMaximum = initialMaximum.copy()
        addedMaximum.weight = 105
        addedMaximum.done = true
        addedMaximum.orderIndex = 1
        let backOff = ExerciseSet(repetitions: 2, weight: 0, done: false, orderIndex: 2, usedMetric: .metric)
        backOff.prescribedSetType = .backoff
        backOff.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 2,
            role: .backOff,
            repetitions: .fixed(2),
            load: LoadPrescription(
                reference: .init(kind: .dailyMaximum, exposureKey: "clean"),
                percentage: 0.8
            )
        ))
        let entry = ExerciseEntry(exercise: exercise, sets: [initialMaximum, addedMaximum, backOff], usedMetric: .metric)
        entry.progressionKey = "clean"
        let workout = Workout(name: "Olympic")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(backOff.prescribedSuggestedLoad ?? 0, 84, accuracy: 0.001)
        XCTAssertEqual(addedMaximum.prescribedSetType, .dailyMaximum)
        XCTAssertNotNil(addedMaximum.prescriptionDefinitionData)

        initialMaximum.isSelectedDailyMaximum = true
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        XCTAssertEqual(backOff.prescribedSuggestedLoad ?? 0, 80, accuracy: 0.001)
    }

    func testDeferredBackOffIsGeneratedFromTopSetAndCompletedValuesRemainFrozen() throws {
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
        topSet.prescriptionDefinitionData = try JSONEncoder().encode(
            SetPrescriptionDefinition(
                orderIndex: 0,
                role: .topSet,
                repetitions: .fixed(5)
            )
        )
        let entry = ExerciseEntry(exercise: exercise, sets: [topSet], usedMetric: .metric)
        entry.progressionKey = "bench-strength"
        let backOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([backOff])
        let workout = Workout(name: "Press")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        var generated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == backOff.id
        })
        XCTAssertEqual(entry.orderedSets.count, 2)
        XCTAssertEqual(generated.prescribedSetType, .backoff)
        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 90, accuracy: 0.001)
        XCTAssertEqual(generated.prescribedRepetitions, 5)

        topSet.done = false
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        XCTAssertFalse(entry.orderedSets.contains { $0.generatedBackOffDefinitionID == backOff.id })

        topSet.done = true
        topSet.weight = 110
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        generated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == backOff.id
        })
        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 99, accuracy: 0.001)

        generated.weight = 99
        generated.done = true
        topSet.weight = 120
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 99, accuracy: 0.001)
        XCTAssertEqual(generated.weight, 99, accuracy: 0.001)
    }

    func testDeferredBackOffRefreshKeepsOneUnfinishedSetPerDefinition() throws {
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
        entry.progressionKey = "bench-strength"
        let firstBackOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        let secondBackOff = SetPrescriptionDefinition(
            orderIndex: 2,
            role: .backOff,
            repetitions: .fixed(8),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.8
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([firstBackOff, secondBackOff])
        let workout = Workout(name: "Press")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(
            entry.orderedSets.filter { $0.generatedBackOffDefinitionID != nil }.count,
            2
        )
        XCTAssertEqual(
            Set(entry.orderedSets.compactMap(\.generatedBackOffDefinitionID)),
            Set([firstBackOff.id, secondBackOff.id])
        )

        let firstGenerated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == firstBackOff.id
        })
        let duplicate = firstGenerated.copy()
        duplicate.generatedBackOffDefinitionID = firstBackOff.id
        duplicate.done = false
        duplicate.orderIndex = (entry.sets.map(\.orderIndex).max() ?? -1) + 1
        entry.sets.append(duplicate)

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(
            entry.orderedSets.filter {
                $0.generatedBackOffDefinitionID == firstBackOff.id && !$0.done
            }.count,
            1
        )
        XCTAssertEqual(entry.orderedSets.count, 3)

        firstGenerated.done = true
        let staleUnfinished = firstGenerated.copy()
        staleUnfinished.generatedBackOffDefinitionID = firstBackOff.id
        staleUnfinished.done = false
        staleUnfinished.orderIndex = (entry.sets.map(\.orderIndex).max() ?? -1) + 1
        entry.sets.append(staleUnfinished)

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(
            entry.orderedSets.filter { $0.generatedBackOffDefinitionID == firstBackOff.id }.count,
            1
        )
        XCTAssertTrue(firstGenerated.done)
    }

    func testSnapshotDefersSourceBasedBackOffUntilItsSourceIsCompleted() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let topSet = SetPrescriptionDefinition(
            orderIndex: 0,
            role: .topSet,
            repetitions: .fixed(5)
        )
        let backOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        let planned = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            targetSets: 2,
            plannedSets: [
                PlannedSet(orderIndex: 0, definitionData: try JSONEncoder().encode(topSet)),
                PlannedSet(orderIndex: 1, definitionData: try JSONEncoder().encode(backOff))
            ],
            progressionKey: "bench-strength"
        )
        let entry = ExerciseEntry(from: planned, orderIndex: 0, usedMetric: .metric)
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Press", startDate: .now)

        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: planned,
            run: run,
            unitSystem: .metric
        )

        XCTAssertEqual(entry.orderedSets.count, 1)
        XCTAssertEqual(entry.orderedSets.first?.prescribedSetType, .topSet)
        let deferred = try XCTUnwrap(entry.deferredBackOffDefinitionsData)
        XCTAssertEqual(try JSONDecoder().decode([SetPrescriptionDefinition].self, from: deferred), [backOff])
    }

    func testDeferredTopSetBackOffPreservesTheWorkoutWeightUnit() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let topSet = ExerciseSet(
            repetitions: 5,
            weight: 225,
            done: true,
            setType: .topSet,
            orderIndex: 0,
            usedMetric: .imperial
        )
        topSet.prescribedSetType = .topSet
        let entry = ExerciseEntry(exercise: exercise, sets: [topSet], usedMetric: .imperial)
        entry.progressionKey = "bench-strength"
        let backOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([backOff])
        let workout = Workout(name: "Press")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        let generated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == backOff.id
        })
        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 202.5, accuracy: 0.001)
        XCTAssertEqual(generated.prescribedSuggestedLoadType, .lbs)
    }

    func testFutureOverrideIsInheritedAndConvertedForTheNextOccurrence() throws {
        let exercise = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        let definition = ProgramDefinitionPayload(
            name: "Override Carry Forward",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Base",
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Press",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exercise.id,
                                            exposureKey: "bench-strength",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .fixed(5),
                                                    load: LoadPrescription(
                                                        reference: .init(kind: .fixedLoad),
                                                        fixedValue: 100
                                                    )
                                                )
                                            ]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [exercise.id: exercise])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedExercise = try XCTUnwrap(plannedWorkout.orderedPlannedExercises.first)

        let previousWorkout = Workout(name: "Previous", endTime: .now)
        let previousEntry = ExerciseEntry(from: plannedExercise, orderIndex: 0, usedMetric: .imperial)
        let previousSet = try XCTUnwrap(previousEntry.orderedSets.first)
        previousSet.weight = 220.4623
        // The active-workout UI stamps the set with the unit the value was
        // entered in before storing it; an imperial override is (lb, .lbs).
        previousSet.weightType = .lbs
        previousSet.done = true
        previousSet.userOverrideAffectsFuture = true
        previousSet.isUserOverridden = true
        previousSet.userOverrideReason = "Heavier than the generated target"
        previousWorkout.exercises = [previousEntry]

        let previousProgress = PlanWorkoutProgress(plannedWorkout: plannedWorkout, weekIndex: 0, workoutIndex: 0)
        previousProgress.status = .completed
        previousProgress.completedAt = .now
        previousProgress.completedWorkout = previousWorkout
        run.workoutProgress.append(previousProgress)

        let targetEntry = ExerciseEntry(from: plannedExercise, orderIndex: 0, usedMetric: .metric)
        ProgramPrescriptionSnapshotService.apply(
            to: targetEntry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric
        )

        let targetSet = try XCTUnwrap(targetEntry.orderedSets.first)
        XCTAssertEqual(targetSet.weight, 100, accuracy: 0.01)
        XCTAssertTrue(targetSet.isUserOverridden)
        XCTAssertTrue(targetSet.userOverrideAffectsFuture)
        XCTAssertEqual(targetSet.userOverrideReason, "Heavier than the generated target")
        XCTAssertEqual(targetSet.prescribedSuggestedLoad ?? 0, 100, accuracy: 0.01)
    }


    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}

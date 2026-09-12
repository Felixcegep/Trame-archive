import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutPlanDefinitionTests: XCTestCase {
    func testPlanExerciseDraftNormalizesCorruptRepRangeForEditor() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let draft = PlanExerciseDraft(exercise: exercise, orderIndex: 0)
        var invalidDraft = draft
        invalidDraft.repRangeMinimum = 150
        invalidDraft.repRangeMaximum = -3

        invalidDraft.normalizeRepRangeForEditing()

        XCTAssertEqual(invalidDraft.repRangeMinimum, 100)
        XCTAssertEqual(invalidDraft.repRangeMaximum, 100)
        _ = context
    }

    func testPlannedWorkoutSnapshotsProgressionAndPreservesRule() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
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

    func testPlannedSetsSnapshotTheirIndependentPrescription() throws {
        let exercise = WorkoutTestFixture.makeExercise()
        let plannedExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            targetSets: 3,
            repRangeMinimum: 8,
            repRangeMaximum: 12,
            suggestedLoad: 60,
            suggestedLoadType: .kg,
            restSeconds: 120,
            plannedSets: [
                PlannedSet(
                    orderIndex: 0,
                    setType: .warmup,
                    repetitions: 10,
                    suggestedLoad: 20,
                    suggestedLoadType: .kg,
                    restSeconds: 45,
                    notes: "Prime movement"
                ),
                PlannedSet(
                    orderIndex: 1,
                    setType: .normal,
                    repRangeMinimum: 6,
                    repRangeMaximum: 8,
                    suggestedLoad: 60,
                    suggestedLoadType: .kg,
                    restSeconds: 120,
                    targetRPE: 8,
                    targetRIR: 2
                ),
                PlannedSet(
                    orderIndex: 2,
                    setType: .dropSet,
                    repetitions: 12,
                    suggestedLoad: 40,
                    suggestedLoadType: .kg,
                    isOptional: true
                )
            ]
        )
        let plannedWorkout = PlannedWorkout(
            name: "Per-set prescription",
            orderIndex: 0,
            dayOffset: 0,
            plannedExercises: [plannedExercise]
        )
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Per-set plan", startDate: .now)

        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let sets = try XCTUnwrap(workout.orderedExercises.first?.orderedSets)

        XCTAssertEqual(sets.map(\.setType), [.warmup, .normal, .dropSet])
        XCTAssertEqual(sets.map(\.repetitions), [10, 8, 12])
        XCTAssertEqual(sets.map(\.weight), [20, 60, 40])
        XCTAssertEqual(sets[0].prescribedRepetitions, 10)
        XCTAssertEqual(sets[0].prescriptionNotes, "Prime movement")
        XCTAssertEqual(sets[1].prescribedRepRangeMinimum, 6)
        XCTAssertEqual(sets[1].prescribedRPE, 8)
        XCTAssertEqual(sets[1].prescribedRIR, 2)
        XCTAssertEqual(sets[2].isPrescribedOptional, true)
    }

    func testPlanCreationAssignsDifferentTemplatesPerTrainingDay() throws {
        let lowerExercise = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
        let upperExercise = WorkoutTestFixture.makeExercise()
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

    func testFlexibleWeekCreationStoresSessionOrderWithoutWeekdayPins() throws {
        let lowerExercise = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
        let upperExercise = WorkoutTestFixture.makeExercise()
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
            name: "Flexible Upper Lower",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            durationWeeks: 1,
            dayAssignments: [
                .init(dayOffset: 0, template: lower),
                .init(dayOffset: 1, template: upper),
                .init(dayOffset: 2, template: lower)
            ],
            scheduleMode: .flexibleWeek
        )

        XCTAssertEqual(plan.scheduleMode, .flexibleWeek)
        XCTAssertEqual(plan.daysPerWeek, 3)
        let workouts = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts)
        XCTAssertEqual(workouts.map(\.dayOffset), [0, 1, 2])
        XCTAssertEqual(workouts.map(\.name), ["Lower", "Upper", "Lower"])
    }

    func testPlanCreationBuildsAnOrderedScheduledDeloadBlock() {
        let exercise = WorkoutTestFixture.makeExercise()
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
        let exercise = WorkoutTestFixture.makeExercise()
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
        XCTAssertEqual(entry.prescribedSuggestedLoad ?? 0, 90)
        XCTAssertTrue(entry.sets.allSatisfy { $0.weight == 90 })
        XCTAssertEqual(plannedExercise.targetSets, 3)
        XCTAssertEqual(plannedExercise.suggestedLoad, 100)
    }

    func testPlanEquipmentRequirementsAreNormalizedAtCreationAndEditing() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
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
        try draft.apply(to: plan, using: context)

        XCTAssertEqual(plan.requiredEquipment, [.barbell, .cable])
    }

    func testPlanEditorDraftPersistsPhaseOrderIndex() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 2)
        let plan = PlanCoordinator.createPlan(
            name: "Phase order plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [.init(dayOffset: 0, template: template)]
        )
        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        try context.save()

        var draft = PlanEditorDraft(plan: plan)
        draft.blocks[0].orderIndex = 4
        try draft.apply(to: plan, using: context)

        XCTAssertEqual(plan.orderedBlocks.first?.orderIndex, 4)
    }

    func testPlanEditorDraftAppliesOrderedSetPrescriptions() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 3)
        let plan = PlanCoordinator.createPlan(
            name: "Per-set draft plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [.init(dayOffset: 0, template: template)]
        )
        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        try context.save()

        var warmup = PlanSetDraft(
            setType: .warmup,
            repetitions: 10,
            repRangeMinimum: nil,
            repRangeMaximum: nil,
            suggestedLoad: 20,
            suggestedLoadType: .kg,
            restSeconds: 45,
            targetRPE: nil,
            targetRIR: nil
        )
        warmup.notes = "Prime movement"
        var working = PlanSetDraft(
            setType: .normal,
            repetitions: nil,
            repRangeMinimum: 6,
            repRangeMaximum: 8,
            suggestedLoad: 60,
            suggestedLoadType: .kg,
            restSeconds: 120,
            targetRPE: 8,
            targetRIR: 2
        )
        working.isOptional = true

        var draft = PlanEditorDraft(plan: plan)
        draft.weeks[0].workouts[0].exercises[0].plannedSets = [warmup, working]
        try draft.apply(to: plan, using: context)

        let savedExercise = try XCTUnwrap(
            plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first
        )
        XCTAssertEqual(savedExercise.orderedPlannedSets.map(\.setType), [.warmup, .normal])
        XCTAssertEqual(savedExercise.orderedPlannedSets.map(\.orderIndex), [0, 1])
        XCTAssertEqual(savedExercise.orderedPlannedSets.first?.repetitions, 10)
        XCTAssertEqual(savedExercise.orderedPlannedSets.first?.notes, "Prime movement")
        XCTAssertEqual(savedExercise.orderedPlannedSets.last?.repRangeMinimum, 6)
        XCTAssertEqual(savedExercise.orderedPlannedSets.last?.isOptional, true)
    }

    func testPlannedVersusPerformedComparisonReportsMetAboveBelowAndNoTarget() {
        let exercise = WorkoutTestFixture.makeExercise()
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


}

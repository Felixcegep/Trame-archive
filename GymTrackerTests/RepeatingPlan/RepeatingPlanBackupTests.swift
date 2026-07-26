import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanBackupTests: XCTestCase {
    func testV18RoundTripPreservesDefinitionRunOccurrenceUndoAndWorkoutSource() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let push = WorkoutTemplate(name: "Push", exercises: [])
        let pull = WorkoutTemplate(name: "Pull", exercises: [])
        let plan = RepeatingPlan(
            name: "PPL Continuous",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell, .cable],
            notes: "Train in order.",
            isBuiltIn: true,
            slots: [
                RepeatingPlanSlot(orderIndex: 0, workoutTemplate: push),
                RepeatingPlanSlot(orderIndex: 1, workoutTemplate: pull)
            ]
        )
        let run = RepeatingPlanRun(plan: plan, startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        run.currentSlotIndex = 1
        run.completedCycleCount = 4
        run.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)

        let workout = Workout(name: "Pull", endTime: Date(timeIntervalSince1970: 1_700_000_300))
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: 4,
            expectedSlotIndex: 0,
            selectedSlotIndex: 1,
            kind: .alternate,
            continuationMode: .keepExpected,
            status: .undone,
            cursorBefore: 0,
            cursorAfter: 1,
            cycleBefore: 4,
            cycleAfter: 4,
            createdAt: Date(timeIntervalSince1970: 1_700_000_150),
            startedAt: Date(timeIntervalSince1970: 1_700_000_200),
            completedAt: Date(timeIntervalSince1970: 1_700_000_300),
            undoneAt: Date(timeIntervalSince1970: 1_700_000_400),
            completedWorkout: workout
        )
        run.occurrences = [occurrence]
        workout.sourceRepeatingPlanID = plan.id
        workout.sourceRepeatingPlanRunID = run.id
        workout.sourceRepeatingPlanOccurrenceID = occurrence.id
        workout.sourceRepeatingPlanName = plan.name

        source.insert(push)
        source.insert(pull)
        source.insert(plan)
        source.insert(run)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertEqual(backup.version, BackupDTO.mobilityLinkageVersion)
        XCTAssertEqual(backup.repeatingPlans.count, 1)
        XCTAssertEqual(backup.repeatingPlanRuns.count, 1)

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try JSONDecoder().decode(BackupDTO.self, from: JSONEncoder().encode(backup)).restore(to: restored)

        let restoredPlan = try XCTUnwrap(
            restored.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == plan.id }
        )
        let restoredRun = try XCTUnwrap(
            restored.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == run.id }
        )
        let restoredWorkout = try XCTUnwrap(restored.fetch(FetchDescriptor<Workout>()).first { $0.id == workout.id })
        let restoredOccurrence = try XCTUnwrap(restoredRun.orderedOccurrences.first)

        XCTAssertEqual(restoredPlan.id, plan.id)
        XCTAssertEqual(restoredPlan.name, "PPL Continuous")
        XCTAssertEqual(restoredPlan.orderedSlots.map(\.templateNameSnapshot), ["Push", "Pull"])
        XCTAssertEqual(restoredRun.id, run.id)
        XCTAssertEqual(restoredRun.plan?.id, restoredPlan.id)
        XCTAssertEqual(restoredRun.currentSlotIndex, 1)
        XCTAssertEqual(restoredRun.completedCycleCount, 4)
        XCTAssertEqual(restoredRun.orderedSlots.map(\.sourceSlotID), run.orderedSlots.map(\.sourceSlotID))
        XCTAssertEqual(restoredOccurrence.id, occurrence.id)
        XCTAssertEqual(restoredOccurrence.kind, .alternate)
        XCTAssertEqual(restoredOccurrence.continuationMode, .keepExpected)
        XCTAssertEqual(restoredOccurrence.status, .undone)
        XCTAssertEqual(restoredOccurrence.cursorBefore, 0)
        XCTAssertEqual(restoredOccurrence.cursorAfter, 1)
        XCTAssertEqual(restoredOccurrence.cycleBefore, 4)
        XCTAssertEqual(restoredOccurrence.cycleAfter, 4)
        XCTAssertEqual(restoredOccurrence.completedWorkout?.id, workout.id)
        XCTAssertEqual(restoredOccurrence.undoneAt, Date(timeIntervalSince1970: 1_700_000_400))
        XCTAssertEqual(restoredWorkout.sourceRepeatingPlanID, plan.id)
        XCTAssertEqual(restoredWorkout.sourceRepeatingPlanRunID, run.id)
        XCTAssertEqual(restoredWorkout.sourceRepeatingPlanOccurrenceID, occurrence.id)
        XCTAssertEqual(restoredWorkout.sourceRepeatingPlanName, "PPL Continuous")
    }

    func testV17CorruptRepeatingRunDoesNotReplaceExistingData() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sentinel = Exercise(name: "Keep Me", primaryMuscles: [.quadriceps])
        context.insert(sentinel)
        try context.save()

        let planID = UUID()
        let slotID = UUID()
        let backup = BackupDTO(
            version: BackupDTO.repeatingPlanVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            repeatingPlans: [
                RepeatingPlanDTO(
                    id: planID.uuidString,
                    name: "Valid Rotation",
                    goal: PlanGoal.generalStrength.rawValue,
                    experienceLevel: PlanExperienceLevel.beginner.rawValue,
                    requiredEquipment: [],
                    notes: nil,
                    createdAt: .now,
                    updatedAt: .now,
                    isArchived: false,
                    isBuiltIn: false,
                    slots: [
                        RepeatingPlanSlotDTO(
                            id: slotID.uuidString,
                            orderIndex: 0,
                            templateIDSnapshot: UUID().uuidString,
                            templateNameSnapshot: "Removed Template",
                            workoutTemplateName: nil
                        )
                    ]
                )
            ],
            repeatingPlanRuns: [
                RepeatingPlanRunDTO(
                    id: UUID().uuidString,
                    sourcePlanID: planID.uuidString,
                    sourcePlanName: "Valid Rotation",
                    status: RepeatingPlanRunStatus.active.rawValue,
                    currentSlotIndex: 2,
                    completedCycleCount: 0,
                    startedAt: .now,
                    endedAt: nil,
                    updatedAt: .now,
                    planID: planID.uuidString,
                    slots: [
                        RepeatingPlanRunSlotDTO(
                            id: UUID().uuidString,
                            sourceSlotID: slotID.uuidString,
                            orderIndex: 0,
                            templateIDSnapshot: UUID().uuidString,
                            templateNameSnapshot: "Removed Template",
                            workoutTemplateName: nil
                        )
                    ],
                    occurrences: []
                )
            ]
        )

        XCTAssertThrowsError(try backup.restore(to: context)) { error in
            guard case .invalidIdentifier("repeating plan cursor") = error as? BackupValidationError else {
                return XCTFail("Expected a repeating-plan cursor error, got \(error)")
            }
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).map(\.name), ["Keep Me"])
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlan>()).isEmpty)
    }

    func testV17RoundTripPreservesRunAndHistoryAfterDefinitionAndTemplateAreMissing() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let sourcePlanID = UUID()
        let sourceSlotID = UUID()
        let templateID = UUID()
        let run = RepeatingPlanRun(
            sourcePlanID: sourcePlanID,
            sourcePlanName: "Deleted Full Body Rotation",
            currentSlotIndex: 0,
            completedCycleCount: 2,
            slots: [
                RepeatingPlanRunSlot(
                    sourceSlotID: sourceSlotID,
                    orderIndex: 0,
                    templateIDSnapshot: templateID,
                    templateNameSnapshot: "Deleted Full Body A",
                    workoutTemplate: nil
                )
            ]
        )
        let workout = Workout(name: "Deleted Full Body A", endTime: .now)
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: 2,
            expectedSlotIndex: 0,
            selectedSlotIndex: 0,
            status: .completed,
            cursorBefore: 0,
            cursorAfter: 0,
            completedAt: .now,
            completedWorkout: workout
        )
        run.occurrences = [occurrence]
        workout.sourceRepeatingPlanID = sourcePlanID
        workout.sourceRepeatingPlanRunID = run.id
        workout.sourceRepeatingPlanOccurrenceID = occurrence.id
        workout.sourceRepeatingPlanName = "Deleted Full Body Rotation"

        source.insert(run)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertTrue(backup.repeatingPlans.isEmpty)

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let restoredRun = try XCTUnwrap(restored.fetch(FetchDescriptor<RepeatingPlanRun>()).first)
        let restoredOccurrence = try XCTUnwrap(restoredRun.orderedOccurrences.first)
        XCTAssertNil(restoredRun.plan)
        XCTAssertEqual(restoredRun.sourcePlanID, sourcePlanID)
        XCTAssertEqual(restoredRun.sourcePlanName, "Deleted Full Body Rotation")
        XCTAssertNil(restoredRun.orderedSlots.first?.workoutTemplate)
        XCTAssertEqual(restoredRun.orderedSlots.first?.templateIDSnapshot, templateID)
        XCTAssertEqual(restoredRun.orderedSlots.first?.templateNameSnapshot, "Deleted Full Body A")
        XCTAssertEqual(restoredOccurrence.completedWorkout?.id, workout.id)
    }

    func testPreV17PayloadDecodesWithoutFabricatingRotations() throws {
        let legacyData = Data(
            """
            {
              "version": 16,
              "preferences": { "darkMode": false, "restTimer": 90, "unitSystem": "metric" },
              "exercises": [],
              "templates": [],
              "collections": [],
              "workouts": []
            }
            """.utf8
        )

        let backup = try JSONDecoder().decode(BackupDTO.self, from: legacyData)
        XCTAssertEqual(backup.version, BackupDTO.recipePhotoVersion)
        XCTAssertTrue(backup.repeatingPlans.isEmpty)
        XCTAssertTrue(backup.repeatingPlanRuns.isEmpty)
        XCTAssertNoThrow(try backup.validate())
    }

    func testV18AcceptsActiveWorkoutLinkedToInProgressOccurrence() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = WorkoutTemplate(name: "Active Push", exercises: [])
        let plan = RepeatingPlan(
            name: "Active Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        let run = try RepeatingPlanCoordinator.activate(plan)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: run, using: context))

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )

        XCTAssertNoThrow(try backup.validate())
    }

    func testV18RoundTripPreservesTemplateDefinitionAndRunMobilityLinks() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let warmup = MobilityRoutine(name: "Shoulder Warmup")
        let cooldown = MobilityRoutine(name: "Shoulder Cooldown")
        let template = WorkoutTemplate(
            name: "Press",
            exercises: [],
            preWorkoutMobilityRoutine: warmup,
            postWorkoutMobilityRoutine: cooldown
        )
        let plan = RepeatingPlan(
            name: "Press Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        let run = RepeatingPlanRun(plan: plan)

        source.insert(warmup)
        source.insert(cooldown)
        source.insert(template)
        source.insert(plan)
        source.insert(run)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertEqual(backup.version, BackupDTO.mobilityLinkageVersion)
        XCTAssertEqual(backup.templates.first?.preWorkoutMobilityRoutineName, "Shoulder Warmup")
        XCTAssertEqual(backup.repeatingPlans.first?.slots.first?.postWorkoutMobilityRoutineNameSnapshot, "Shoulder Cooldown")

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try JSONDecoder().decode(BackupDTO.self, from: JSONEncoder().encode(backup)).restore(to: restored)

        let restoredTemplate = try XCTUnwrap(
            restored.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.name == "Press" }
        )
        let restoredPlan = try XCTUnwrap(
            restored.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == plan.id }
        )
        let restoredRun = try XCTUnwrap(
            restored.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == run.id }
        )
        let restoredDefinitionSlot = try XCTUnwrap(restoredPlan.orderedSlots.first)
        let restoredRunSlot = try XCTUnwrap(restoredRun.orderedSlots.first)

        XCTAssertEqual(restoredTemplate.preWorkoutMobilityRoutine?.id, warmup.id)
        XCTAssertEqual(restoredTemplate.postWorkoutMobilityRoutine?.id, cooldown.id)
        XCTAssertEqual(restoredDefinitionSlot.preWorkoutMobilityRoutine?.id, warmup.id)
        XCTAssertEqual(restoredDefinitionSlot.preWorkoutMobilityRoutineIDSnapshot, warmup.id)
        XCTAssertEqual(restoredDefinitionSlot.postWorkoutMobilityRoutine?.id, cooldown.id)
        XCTAssertEqual(restoredDefinitionSlot.postWorkoutMobilityRoutineIDSnapshot, cooldown.id)
        XCTAssertEqual(restoredRunSlot.preWorkoutMobilityRoutine?.id, warmup.id)
        XCTAssertEqual(restoredRunSlot.preWorkoutMobilityRoutineNameSnapshot, "Shoulder Warmup")
        XCTAssertEqual(restoredRunSlot.postWorkoutMobilityRoutine?.id, cooldown.id)
        XCTAssertEqual(restoredRunSlot.postWorkoutMobilityRoutineNameSnapshot, "Shoulder Cooldown")
    }

    func testV18MissingTemplateMobilityRoutineDoesNotReplaceExistingData() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sentinel = Exercise(name: "Keep Me", primaryMuscles: [.quadriceps])
        context.insert(sentinel)
        try context.save()

        let backup = BackupDTO(
            version: BackupDTO.mobilityLinkageVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [
                WorkoutTemplateDTO(
                    name: "Invalid Template",
                    templateExercises: [],
                    preWorkoutMobilityRoutineName: "Missing Routine"
                )
            ],
            collections: [],
            workouts: []
        )

        XCTAssertThrowsError(try backup.restore(to: context)) { error in
            guard case .invalidIdentifier("workout template mobility routine") = error as? BackupValidationError else {
                return XCTFail("Expected a template mobility-routine error, got \(error)")
            }
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).map(\.name), ["Keep Me"])
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutTemplate>()).isEmpty)
    }

    func testV18RoundTripKeepsMobilitySnapshotsAfterRoutineDeletion() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let deletedRoutine = MobilityRoutine(name: "Deleted Warmup")
        let template = WorkoutTemplate(
            name: "Lower",
            exercises: [],
            preWorkoutMobilityRoutine: deletedRoutine
        )
        let plan = RepeatingPlan(
            name: "Lower Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        let run = RepeatingPlanRun(plan: plan)
        let deletedRoutineID = deletedRoutine.id

        source.insert(deletedRoutine)
        source.insert(template)
        source.insert(plan)
        source.insert(run)
        try source.save()
        source.delete(deletedRoutine)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertTrue(backup.mobilityRoutines.allSatisfy { $0.id != deletedRoutineID.uuidString })
        XCTAssertNil(backup.repeatingPlanRuns.first?.slots.first?.preWorkoutMobilityRoutineName)
        XCTAssertEqual(
            backup.repeatingPlanRuns.first?.slots.first?.preWorkoutMobilityRoutineIDSnapshot,
            deletedRoutineID.uuidString
        )

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)
        let restoredPlan = try XCTUnwrap(
            restored.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == plan.id }
        )
        let restoredRun = try XCTUnwrap(
            restored.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == run.id }
        )

        XCTAssertNil(restoredPlan.orderedSlots.first?.preWorkoutMobilityRoutine)
        XCTAssertEqual(restoredPlan.orderedSlots.first?.preWorkoutMobilityRoutineIDSnapshot, deletedRoutineID)
        XCTAssertEqual(restoredPlan.orderedSlots.first?.preWorkoutMobilityRoutineNameSnapshot, "Deleted Warmup")
        XCTAssertNil(restoredRun.orderedSlots.first?.preWorkoutMobilityRoutine)
        XCTAssertEqual(restoredRun.orderedSlots.first?.preWorkoutMobilityRoutineIDSnapshot, deletedRoutineID)
        XCTAssertEqual(restoredRun.orderedSlots.first?.preWorkoutMobilityRoutineNameSnapshot, "Deleted Warmup")
    }
}

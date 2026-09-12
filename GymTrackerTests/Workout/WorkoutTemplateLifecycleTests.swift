import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutTemplateLifecycleTests: XCTestCase {
    func testRenameTemplateTrimsNameAndSaves() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = WorkoutTemplate(name: "Push Day", exercises: [])
        context.insert(template)
        try context.save()

        try WorkoutTemplateArchiveService.rename(template, to: "  Upper Body Push  ", using: context)
        XCTAssertEqual(template.name, "Upper Body Push")
    }

    func testRenameTemplateRejectsEmptyName() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = WorkoutTemplate(name: "Push Day", exercises: [])
        context.insert(template)
        try context.save()

        XCTAssertThrowsError(try WorkoutTemplateArchiveService.rename(template, to: "   ", using: context)) { error in
            guard let templateError = error as? TemplateArchiveError else {
                return XCTFail("Expected TemplateArchiveError")
            }
            XCTAssertEqual(templateError, .emptyName)
        }
    }

    func testDuplicateTemplateCreatesDeepCopy() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let template = WorkoutTemplate(
            name: "Hypertrophy Push",
            exercises: [exercise],
            templateExercises: [
                TemplateExercise(exercise: exercise, order: 0, targetSets: 4, repRangeMinimum: 8, repRangeMaximum: 12)
            ]
        )
        context.insert(exercise)
        context.insert(template)
        try context.save()

        let duplicate = try WorkoutTemplateArchiveService.duplicate(template, using: context)

        XCTAssertEqual(duplicate.name, "Hypertrophy Push Copy")
        XCTAssertEqual(duplicate.orderedTemplateExercises.count, 1)
        XCTAssertEqual(duplicate.orderedTemplateExercises.first?.exercise.name, "Bench Press")
        XCTAssertEqual(duplicate.orderedTemplateExercises.first?.targetSets, 4)
        XCTAssertNotEqual(duplicate.id, template.id)
    }

    func testDeleteUnreferencedTemplateDeletesFromStore() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = WorkoutTemplate(name: "Custom Unused Template", exercises: [])
        context.insert(template)
        try context.save()

        let outcome = try WorkoutTemplateArchiveService.hideOrDeleteResult(template, using: context)

        XCTAssertEqual(outcome, .deleted)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertFalse(templates.contains { $0.name == "Custom Unused Template" })
    }

    func testDeleteReferencedTemplateArchivesWithReason() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(name: "Leg Day", exercises: [exercise])
        let workout = Workout(name: "Leg Day History")
        workout.status = .completed
        workout.sourceTemplate = template

        context.insert(exercise)
        context.insert(template)
        context.insert(workout)
        try context.save()

        let outcome = try WorkoutTemplateArchiveService.hideOrDeleteResult(template, using: context)

        if case .archived(let reason) = outcome {
            XCTAssertTrue(reason.contains("completed workout history"), "Expected reason explaining workout reference, got: \(reason)")
        } else {
            XCTFail("Expected referenced template to return .archived(reason:)")
        }

        XCTAssertTrue(template.isArchived)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertTrue(templates.contains { $0.id == template.id })
    }

    func testCreateTemplatePersistsWarmupAndPostWorkoutStretches() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let warmup = MobilityRoutine(name: "Hip openers")
        let cooldown = MobilityRoutine(name: "Down dogs")
        let movement = MobilityDefinition(name: "World's greatest")
        warmup.items = [
            MobilityRoutineItem(definition: movement, orderIndex: 0, targetDurationSeconds: 30, side: .left)
        ]
        cooldown.items = [
            MobilityRoutineItem(definition: movement, orderIndex: 0, targetDurationSeconds: 45, side: .bilateral)
        ]
        context.insert(exercise)
        context.insert(movement)
        context.insert(warmup)
        context.insert(cooldown)
        try context.save()

        let created = LibraryService.createWorkoutTemplate(
            name: "Lower Body",
            templateExercises: [TemplateExercise(exercise: exercise, order: 0)],
            preWorkoutMobilityRoutine: warmup,
            postWorkoutMobilityRoutine: cooldown,
            using: context
        )

        XCTAssertTrue(created)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let template = try XCTUnwrap(templates.first { $0.name == "Lower Body" })
        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, warmup.id)
        XCTAssertEqual(template.postWorkoutMobilityRoutine?.id, cooldown.id)
        XCTAssertEqual(template.orderedTemplateExercises.first?.exercise.name, "Squat")
    }

    func testRestoreArchivedTemplateClearsArchivedFlag() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = WorkoutTemplate(name: "Archived Template", exercises: [], isArchived: true)
        context.insert(template)
        try context.save()

        try WorkoutTemplateArchiveService.restore(template, using: context)

        XCTAssertFalse(template.isArchived)
    }
}

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ExerciseArchiveIntegrityTests: XCTestCase {
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
        let source = Exercise(name: "Barbell Bench Press", primaryMuscles: [.middleChest], isCustom: false)
        let target = Exercise(name: "Dumbbell Bench Press", primaryMuscles: [.middleChest], isCustom: false)
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


    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}

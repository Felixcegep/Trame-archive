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

    /// Restore is not a narrow "replay only what's in the backup" operation:
    /// per GT-03 (atomic backup restore), `BackupDTO.restore(to:)` always
    /// stages the full bundled system catalog — including every default
    /// `ExerciseRelationship` in `ExerciseRelationshipSeedData.definitions`
    /// — into the destination context as part of the same atomic transaction
    /// that replays the backup's own custom content. A fresh restore
    /// destination is therefore never actually empty of relationships; it
    /// always ends up with one bundled relationship per seed definition plus
    /// whatever custom relationships the backup carried. This test asserted
    /// the pre-GT-03 behavior (restore produces exactly the backup's own
    /// relationships) and started failing once restore began rebuilding the
    /// bundled catalog — confirmed by running it against `main` and reading
    /// `GymBackupRestore.restoreExerciseCatalog`/`SystemSeedCatalogCoordinator
    /// .stageBundledCatalog`, not a real behavioral regression.
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

        // Structural invariant, not a hardcoded headcount: restoring always
        // adds one relationship per bundled seed definition on top of the
        // backup's own custom relationships, so the expected total tracks
        // `ExerciseRelationshipSeedData.definitions.count` rather than a
        // number that would silently go stale the moment a bundled
        // relationship is added or removed.
        let expectedCount = ExerciseRelationshipSeedData.definitions.count + 1
        XCTAssertEqual(restored.count, expectedCount, "Expected every bundled seed relationship plus the one custom relationship carried by the backup")

        let customRelationship = try XCTUnwrap(
            restored.first {
                $0.sourceExercise?.name == "Barbell Bench Press"
                    && $0.targetExercise?.name == "Dumbbell Bench Press"
            },
            "The backup's own custom relationship must round-trip alongside the bundled catalog"
        )
        XCTAssertEqual(customRelationship.type, .substitution)

        // The archived source exercise itself must also round-trip with its
        // archived flag intact, not just the relationship that references it.
        let restoredSource = try XCTUnwrap(
            try restoredContext.fetch(FetchDescriptor<Exercise>())
                .first { $0.name == "Barbell Bench Press" && !$0.isCustom }
        )
        XCTAssertTrue(restoredSource.isArchived, "An archived exercise must remain archived after restore")
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

        let unreferencedOutcome = try ExerciseArchiveService.hideOrDeleteResult(unreferenced, using: context)
        let referencedOutcome = try ExerciseArchiveService.hideOrDeleteResult(referenced, using: context)

        XCTAssertEqual(unreferencedOutcome, .deleted)
        if case .archived(let reason) = referencedOutcome {
            XCTAssertTrue(reason.contains("template"), "Expected reason to explain template reference, got: \(reason)")
        } else {
            XCTFail("Expected referenced exercise to return .archived(reason:)")
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertFalse(exercises.contains { $0.name == "Unused Custom" })
        XCTAssertTrue(exercises.first { $0.name == "Referenced Custom" }?.isArchived == true)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TemplateExercise>()).count, 1)
    }


    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}

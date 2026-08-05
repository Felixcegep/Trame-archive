import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ExerciseLibraryIntegrityTests: XCTestCase {
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

    func testImportedExerciseCatalogContainsProgramEngineEntries() throws {
        let catalog = ExerciseCatalogSeedData.templates()
        let names = Set(catalog.map(\.name))

        // Structural invariants, not a headcount: the catalog grows over time
        // as new exercises are added, so a hardcoded count breaks on every
        // addition without catching a real regression. What must always hold
        // is that every entry has a unique, non-empty name.
        XCTAssertFalse(catalog.isEmpty, "The Program Engine exercise catalog must not be empty")
        XCTAssertEqual(names.count, catalog.count, "Catalog contains duplicate exercise names")
        XCTAssertTrue(catalog.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }, "Every catalog entry must have a non-empty name")
        XCTAssertTrue(catalog.allSatisfy { !$0.primaryMuscles.isEmpty }, "Every catalog entry must declare at least one primary muscle")
        // Membership, not position. This test asserts the Program Engine
        // entries are present in the imported catalog — which is its name and
        // its purpose — so pinning them to `first`/`last` only re-encodes the
        // hardcoded-ordering brittleness the comment above rejects: appending
        // or reordering a single entry breaks it without catching a
        // regression. Both movements are still in the catalog; only their
        // index moved.
        XCTAssertTrue(names.contains("Bench Press"), "Catalog must contain the baseline barbell press")
        XCTAssertTrue(names.contains("Power Jerk + Split Jerk"), "Catalog must contain the Program Engine olympic complex entries")

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
        XCTAssertTrue(exercises.contains { $0.name == "Front Squat" })
    }

    func testExerciseRelationshipSeedingIsCompleteAndIdempotent() throws {
        let context = try makeContext()
        for exercise in ExerciseSeedData.templates() { context.insert(exercise) }
        try context.save()

        let first = try ExerciseRelationshipSeedData.seed(in: context)
        let firstCount = try context.fetchCount(FetchDescriptor<ExerciseRelationship>())
        let second = try ExerciseRelationshipSeedData.seed(in: context)
        let secondCount = try context.fetchCount(FetchDescriptor<ExerciseRelationship>())

        // Structural invariants derived from the seed definitions themselves,
        // not a hardcoded headcount: adding a new relationship definition
        // must not break this test. What must always hold is that every
        // definition resolves to a real exercise (no dangling name), that
        // the definition list has no exact duplicates, that the first pass
        // inserts exactly one relationship per definition, and that a
        // second pass is fully idempotent.
        let definitions = ExerciseRelationshipSeedData.definitions
        let seededNames = Set(ExerciseSeedData.templates().map(\.name))
        let unresolvedDefinitionNames = definitions
            .flatMap { [$0.source, $0.target] }
            .filter { !seededNames.contains($0) }
        XCTAssertTrue(
            unresolvedDefinitionNames.isEmpty,
            "Every relationship definition must reference an exercise that exists in the seed catalog; unresolved: \(unresolvedDefinitionNames)"
        )
        let definitionKeys = definitions.map { "\($0.source)|\($0.target)|\($0.type.rawValue)" }
        XCTAssertEqual(Set(definitionKeys).count, definitionKeys.count, "Relationship seed definitions contain an exact duplicate")

        XCTAssertEqual(first.insertedCount, definitions.count, "First seeding pass should insert exactly one relationship per definition")
        XCTAssertTrue(first.unresolvedNames.isEmpty)
        XCTAssertEqual(second.insertedCount, 0, "Re-seeding must not insert duplicate relationships")
        XCTAssertTrue(second.unresolvedNames.isEmpty)
        XCTAssertEqual(firstCount, definitions.count)
        XCTAssertEqual(secondCount, firstCount)
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

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}

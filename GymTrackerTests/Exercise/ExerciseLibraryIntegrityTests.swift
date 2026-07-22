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

        XCTAssertEqual(catalog.count, 139)
        XCTAssertEqual(names.count, catalog.count)
        XCTAssertEqual(catalog.first?.name, "Bench Press")
        XCTAssertEqual(catalog.last?.name, "Power Jerk + Split Jerk")

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

        XCTAssertEqual(first.insertedCount, 25)
        XCTAssertTrue(first.unresolvedNames.isEmpty)
        XCTAssertEqual(second.insertedCount, 0)
        XCTAssertTrue(second.unresolvedNames.isEmpty)
        XCTAssertEqual(firstCount, 25)
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

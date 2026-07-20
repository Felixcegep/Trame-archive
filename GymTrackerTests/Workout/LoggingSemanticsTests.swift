import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class LoggingSemanticsTests: XCTestCase {
    func testDefaultSemanticsHaveNoMultiplierEffect() {
        let semantics = LoggingSemantics.default
        XCTAssertEqual(semantics.sideMultiplier, 1)
        XCTAssertEqual(semantics.loadMultiplier, 1)
    }

    func testUnilateralPerSideDoublesSideMultiplier() {
        let semantics = LoggingSemantics(
            laterality: .unilateral,
            repCountingStyle: .perSide,
            weightEntryStyle: .totalLoad,
            loadUnitCount: 1
        )
        XCTAssertEqual(semantics.sideMultiplier, 2)
        XCTAssertEqual(semantics.loadMultiplier, 1)
    }

    func testUnilateralTotalRepCountingDoesNotDoubleSideMultiplier() {
        let semantics = LoggingSemantics(
            laterality: .unilateral,
            repCountingStyle: .total,
            weightEntryStyle: .totalLoad,
            loadUnitCount: 1
        )
        XCTAssertEqual(semantics.sideMultiplier, 1)
    }

    func testPerLoadUnitScalesByLoadUnitCount() {
        let semantics = LoggingSemantics(
            laterality: .bilateral,
            repCountingStyle: .total,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        XCTAssertEqual(semantics.loadMultiplier, 2)
        XCTAssertEqual(semantics.sideMultiplier, 1)
    }

    func testCombinedUnilateralPerSideAndPerLoadUnitCompoundMultipliers() {
        let semantics = LoggingSemantics(
            laterality: .unilateral,
            repCountingStyle: .perSide,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        XCTAssertEqual(semantics.sideMultiplier, 2)
        XCTAssertEqual(semantics.loadMultiplier, 2)
    }

    func testExerciseLoggingSemanticsReflectsStoredFields() {
        let exercise = Exercise(
            name: "Bulgarian Split Squat",
            primaryMuscles: [.quadriceps],
            equipmentType: .dumbbell,
            laterality: .unilateral,
            repCountingStyle: .perSide,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        let semantics = exercise.loggingSemantics
        XCTAssertEqual(semantics.laterality, .unilateral)
        XCTAssertEqual(semantics.repCountingStyle, .perSide)
        XCTAssertEqual(semantics.weightEntryStyle, .perLoadUnit)
        XCTAssertEqual(semantics.loadUnitCount, 2)
    }

    func testExerciseEntrySnapshotsLoggingSemanticsAtCreation() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Dumbbell Bench Press",
            primaryMuscles: [.middleChest],
            equipmentType: .dumbbell,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        context.insert(exercise)

        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        context.insert(entry)
        try context.save()

        XCTAssertEqual(entry.nameSnapshot, "Dumbbell Bench Press")
        XCTAssertEqual(entry.trackingTypeSnapshot, .weightAndReps)
        XCTAssertEqual(entry.weightEntryStyleSnapshot, .perLoadUnit)
        XCTAssertEqual(entry.loadUnitCountSnapshot, 2)
        XCTAssertEqual(entry.loggingSemanticsSnapshot.loadMultiplier, 2)
    }

    func testExerciseEntrySnapshotIsIndependentOfLaterExerciseEdits() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Lateral Raise",
            primaryMuscles: [.lateralDeltoid],
            equipmentType: .dumbbell,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        context.insert(exercise)

        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        context.insert(entry)
        try context.save()

        // Editing the library exercise afterward must not retroactively
        // change how already-logged entries are interpreted.
        exercise.weightEntryStyle = .totalLoad
        exercise.loadUnitCount = 1

        XCTAssertEqual(entry.weightEntryStyleSnapshot, .perLoadUnit)
        XCTAssertEqual(entry.loadUnitCountSnapshot, 2)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}

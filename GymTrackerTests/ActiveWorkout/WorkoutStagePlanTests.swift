import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutStagePlanTests: XCTestCase {
    func testPagesCollapseSupersetMembersIntoOnePage() throws {
        let fixture = try makeFixture()

        let pages = WorkoutStagePlan.pages(for: fixture.workout)

        XCTAssertEqual(
            pages,
            [
                .exercise(fixture.standalone.persistentModelID),
                .superset(fixture.supersetID),
                .block(fixture.blockID),
                .finish
            ]
        )
        XCTAssertEqual(
            pages.filter { if case .superset = $0 { return true }; return false }.count,
            1
        )
    }

    func testPagesCollapseBlockComponentsIntoOnePage() throws {
        let fixture = try makeFixture()

        let pages = WorkoutStagePlan.pages(for: fixture.workout)

        XCTAssertEqual(
            pages.filter { if case .block = $0 { return true }; return false }.count,
            1
        )
        XCTAssertEqual(
            WorkoutStagePlan.entries(for: .block(fixture.blockID), in: fixture.workout)
                .map(\.persistentModelID),
            fixture.blockEntries.map(\.persistentModelID)
        )
    }

    func testBlockMembershipOutranksSuperset() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Mixed membership", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(
            exercise: exercise,
            sets: [ExerciseSet(usedMetric: .metric)],
            usedMetric: .metric,
            supersetGroupID: UUID()
        )
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit)
        entry.executionBlockID = block.id
        entry.executionBlockComponentOrder = 0
        let workout = Workout(name: "Block precedence")
        workout.exercises = [entry]
        workout.executionBlocks = [block]
        context.insert(exercise)
        context.insert(entry.orderedSets[0])
        context.insert(block)
        context.insert(workout)
        try context.save()

        let pages = WorkoutStagePlan.pages(for: workout)

        XCTAssertEqual(pages, [.block(block.id), .finish])
        XCTAssertEqual(WorkoutStagePlan.page(containing: entry), .block(block.id))
        XCTAssertEqual(
            WorkoutStagePlan.entries(for: .block(block.id), in: workout).map(\.id),
            [entry.id]
        )
    }

    func testFinishPageIsAlwaysLast() throws {
        let emptyWorkout = Workout(name: "Empty")
        XCTAssertEqual(WorkoutStagePlan.pages(for: emptyWorkout).last, .finish)

        let fixture = try makeFixture()
        XCTAssertEqual(WorkoutStagePlan.pages(for: fixture.workout).last, .finish)
    }

    func testCurrentPageFollowsFlowResolver() throws {
        let fixture = try makeFixture()
        fixture.standalone.orderedSets[0].done = true

        XCTAssertEqual(
            WorkoutStagePlan.currentPage(in: fixture.workout),
            .superset(fixture.supersetID)
        )

        for entry in fixture.workout.orderedExercises {
            for set in entry.orderedSets {
                set.done = true
            }
        }
        XCTAssertEqual(WorkoutStagePlan.currentPage(in: fixture.workout), .finish)
    }

    func testProgressReportsUntouchedStartedComplete() throws {
        let fixture = try makeFixture(standaloneSetCount: 3)
        let page = WorkoutStagePage.exercise(fixture.standalone.persistentModelID)

        XCTAssertEqual(WorkoutStagePlan.progress(of: page, in: fixture.workout), .untouched)
        fixture.standalone.orderedSets[1].done = true
        XCTAssertEqual(WorkoutStagePlan.progress(of: page, in: fixture.workout), .started)
        fixture.standalone.orderedSets.forEach { $0.done = true }
        XCTAssertEqual(WorkoutStagePlan.progress(of: page, in: fixture.workout), .complete)
    }

    func testFocusFromADifferentPageIsRejected() throws {
        let fixture = try makeFixture()
        let visible = WorkoutStagePage.exercise(fixture.standalone.persistentModelID)
        let stray = WorkoutStagePage.superset(fixture.supersetID)

        XCTAssertTrue(WorkoutStagePlan.acceptsFocus(on: visible, whileShowing: visible))
        XCTAssertFalse(WorkoutStagePlan.acceptsFocus(on: stray, whileShowing: visible))
    }

    private struct Fixture {
        let context: ModelContext
        let workout: Workout
        let standalone: ExerciseEntry
        let supersetEntries: [ExerciseEntry]
        let blockEntries: [ExerciseEntry]
        let supersetID: UUID
        let blockID: UUID
    }

    private func makeFixture(standaloneSetCount: Int = 1) throws -> Fixture {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let standaloneExercise = Exercise(name: "Standalone", primaryMuscles: [.upperChest])
        let supersetExercises = [
            Exercise(name: "Superset A", primaryMuscles: [.upperChest]),
            Exercise(name: "Superset B", primaryMuscles: [.latissimusDorsi])
        ]
        let blockExercises = [
            Exercise(name: "Block A", primaryMuscles: [.quadriceps]),
            Exercise(name: "Block B", primaryMuscles: [.hamstrings])
        ]
        let supersetID = UUID()
        let blockID = UUID()

        func sets(_ count: Int) -> [ExerciseSet] {
            (0..<count).map {
                ExerciseSet(repetitions: 8, weight: 50, orderIndex: $0, usedMetric: .metric)
            }
        }

        let standalone = ExerciseEntry(
            exercise: standaloneExercise,
            sets: sets(standaloneSetCount),
            orderIndex: 0,
            usedMetric: .metric
        )
        let supersetEntries = supersetExercises.enumerated().map { index, exercise in
            ExerciseEntry(
                exercise: exercise,
                sets: sets(1),
                orderIndex: index + 1,
                usedMetric: .metric,
                supersetGroupID: supersetID
            )
        }
        let blockEntries = blockExercises.enumerated().map { index, exercise in
            let entry = ExerciseEntry(
                exercise: exercise,
                sets: sets(1),
                orderIndex: index + 3,
                usedMetric: .metric
            )
            entry.executionBlockID = blockID
            entry.executionBlockComponentOrder = index
            return entry
        }
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit)
        block.id = blockID
        let workout = Workout(name: "Stage fixture")
        workout.exercises = [standalone] + supersetEntries + blockEntries
        workout.executionBlocks = [block]

        context.insert(standaloneExercise)
        supersetExercises.forEach { context.insert($0) }
        blockExercises.forEach { context.insert($0) }
        workout.exercises.flatMap(\.orderedSets).forEach { context.insert($0) }
        workout.exercises.forEach { context.insert($0) }
        context.insert(block)
        context.insert(workout)
        try context.save()

        return Fixture(
            context: context,
            workout: workout,
            standalone: standalone,
            supersetEntries: supersetEntries,
            blockEntries: blockEntries,
            supersetID: supersetID,
            blockID: blockID
        )
    }
}

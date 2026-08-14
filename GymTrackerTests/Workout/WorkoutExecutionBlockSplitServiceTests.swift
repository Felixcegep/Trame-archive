import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutExecutionBlockSplitServiceTests: XCTestCase {
    func testCursorAdvancesComponentsThenCompletesRoundAndSurvivesRefetch() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Circuit")
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit, targetRounds: 2)
        block.workout = workout
        workout.executionBlocks = [block]
        context.insert(workout)
        _ = WorkoutExecutionBlockService.start(block, at: Date(timeIntervalSince1970: 100))

        let first = try WorkoutExecutionBlockSplitService.advance(
            block: block,
            componentCount: 3,
            commandID: UUID(),
            at: Date(timeIntervalSince1970: 110),
            using: context
        )
        XCTAssertEqual(first.kind, .componentAdvanced)
        XCTAssertEqual(first.componentOrder, 1)
        XCTAssertEqual(block.completedRounds, 0)

        _ = try WorkoutExecutionBlockSplitService.advance(
            block: block,
            componentCount: 3,
            commandID: UUID(),
            at: Date(timeIntervalSince1970: 120),
            using: context
        )
        let round = try WorkoutExecutionBlockSplitService.advance(
            block: block,
            componentCount: 3,
            commandID: UUID(),
            at: Date(timeIntervalSince1970: 130),
            using: context
        )
        try context.save()

        XCTAssertEqual(round.kind, .roundCompleted)
        XCTAssertEqual(block.completedRounds, 1)
        let restored = try WorkoutExecutionBlockSplitService.cursor(
            for: block.id,
            componentCount: 3,
            using: context
        )
        XCTAssertEqual(restored.componentOrder, 0)
        XCTAssertEqual(restored.splitCount, 3)
    }

    func testRepeatedCommandIDIsIdempotent() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Pair")
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .pairedSet)
        block.workout = workout
        workout.executionBlocks = [block]
        context.insert(workout)
        _ = WorkoutExecutionBlockService.start(block)
        let commandID = UUID()

        let first = try WorkoutExecutionBlockSplitService.advance(
            block: block,
            componentCount: 2,
            commandID: commandID,
            at: Date(timeIntervalSince1970: 200),
            using: context
        )
        let repeated = try WorkoutExecutionBlockSplitService.advance(
            block: block,
            componentCount: 2,
            commandID: commandID,
            at: Date(timeIntervalSince1970: 210),
            using: context
        )

        XCTAssertEqual(first.id, repeated.id)
        XCTAssertEqual(try WorkoutExecutionBlockSplitService.splits(for: block.id, using: context).count, 1)
        XCTAssertEqual(block.completedRounds, 0)
    }

    func testBackupV28RoundTripsOrderedCursorEvidence() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Complex")
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .olympicComplex, targetRounds: 3)
        block.workout = workout
        workout.executionBlocks = [block]
        workout.exercises = (0..<3).map { order in
            let exercise = Exercise(name: "Complex movement \(order + 1)", primaryMuscles: [.quadriceps])
            source.insert(exercise)
            let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
            entry.executionBlockID = block.id
            entry.executionBlockComponentOrder = order
            return entry
        }
        source.insert(workout)
        _ = WorkoutExecutionBlockService.start(block, at: Date(timeIntervalSince1970: 300))

        _ = try WorkoutExecutionBlockSplitService.advance(
            block: block,
            componentCount: 3,
            commandID: UUID(),
            at: Date(timeIntervalSince1970: 305),
            using: source
        )
        _ = try WorkoutExecutionBlockSplitService.checkpoint(
            block: block,
            componentCount: 3,
            commandID: UUID(),
            at: Date(timeIntervalSince1970: 310),
            using: source
        )
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertGreaterThanOrEqual(backup.version, BackupDTO.executionBlockSplitVersion)
        let encodedSplits = try XCTUnwrap(backup.workouts.first?.executionBlocks?.first?.splits)
        XCTAssertEqual(encodedSplits.map(\.sequenceIndex), [0, 1])
        XCTAssertEqual(encodedSplits.map(\.kind), [
            WorkoutExecutionBlockSplitKind.componentAdvanced.rawValue,
            WorkoutExecutionBlockSplitKind.clockCheckpoint.rawValue
        ])

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)
        let restoredSplits = try restored.fetch(
            FetchDescriptor<WorkoutExecutionBlockSplit>(
                sortBy: [SortDescriptor(\.sequenceIndex)]
            )
        )
        XCTAssertEqual(restoredSplits.count, 2)
        XCTAssertEqual(restoredSplits.map(\.blockID), [block.id, block.id])
        XCTAssertEqual(restoredSplits.map(\.componentOrder), [1, 1])

        let cursor = try WorkoutExecutionBlockSplitService.cursor(
            for: block.id,
            componentCount: 3,
            using: restored
        )
        XCTAssertEqual(cursor.componentOrder, 1)
        XCTAssertEqual(cursor.splitCount, 2)
    }
}

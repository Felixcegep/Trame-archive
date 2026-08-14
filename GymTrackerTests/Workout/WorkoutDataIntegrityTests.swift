import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutDataIntegrityTests: XCTestCase {
    func testDeletingWorkoutCascadesEntriesAndSets() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let workout = WorkoutTestFixture.makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        context.delete(workout)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }

    func testClearAllGymDataRemovesActiveWorkoutGraphInOneTransaction() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let workout = WorkoutTestFixture.makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
    }

    func testClearAllGymDataRemovesMobilityProgramRuntimeGraphAndRecommendations() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let program = makeMobilityProgramPayload()
        let run = try MobilityProgramRun(program: program, sourceProgramID: program.id)
        let progress = MobilityProgramSessionProgress(
            sessionKey: "session-0",
            weekIndex: 0,
            dayIndex: 0,
            sameDayOrder: 0,
            isOptional: false,
            sessionNameSnapshot: "Session"
        )
        run.sessionProgress = [progress]
        let proposal = MobilityProgressionProposal(
            id: UUID(),
            ruleID: UUID(),
            action: .addCycle,
            reason: "Test recommendation",
            reasonKey: "test.recommendation",
            applicationMode: .recommendation,
            proposedState: MobilityProgressionProposedState(),
            performance: MobilityProgressionPerformance()
        )
        let recommendation = try MobilityProgressionRecommendationRecord(
            runID: run.id,
            sessionProgressID: progress.id,
            progressionKey: "test",
            side: .none,
            proposal: proposal
        )
        context.insert(run)
        context.insert(progress)
        context.insert(recommendation)
        try context.save()

        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<MobilityProgramRun>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MobilityProgramSessionProgress>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MobilityProgressionState>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MobilityProgressionRecommendationRecord>()).isEmpty)
    }

    private func makeMobilityProgramPayload() -> MobilityProgramDefinitionPayload {
        let occurrence = MobilityMovementOccurrenceDefinition(
            occurrenceID: "occurrence-0",
            mobilityDefinitionID: UUID(),
            orderIndex: 0,
            targets: MobilityMetricTargets(durationSeconds: .exact(30))
        )
        let session = MobilityPlannedSessionDefinition(
            sessionKey: "session-0",
            weekIndex: 0,
            dayIndex: 0,
            name: "Session",
            recipe: MobilityRoutineRecipeDefinition(occurrences: [occurrence])
        )
        let week = MobilityProgramWeekDefinition(weekIndex: 0, sessions: [session])
        let block = MobilityProgramBlockDefinition(orderIndex: 0, name: "Block", weeks: [week])
        return MobilityProgramDefinitionPayload(
            name: "Test Mobility Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [block]
        )
    }
}

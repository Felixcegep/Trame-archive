import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class CompetitionDayCoordinatorTests: XCTestCase {
    func testLaterAttemptsRequireExplicitLoadAndComponentEvidence() throws {
        let proposal = makeProposal()
        var coordinator = CompetitionDayCoordinator(proposal: proposal)
        let opener = CompetitionDayAttemptKey(lift: .cleanAndJerk, attemptNumber: 1)
        let second = CompetitionDayAttemptKey(lift: .cleanAndJerk, attemptNumber: 2)

        XCTAssertEqual(coordinator.attempt(for: opener)?.selectedLoadKg, 100)
        XCTAssertNil(coordinator.attempt(for: second)?.selectedLoadKg)
        XCTAssertThrowsError(try coordinator.record([.completed, .completed], for: second)) {
            XCTAssertEqual($0 as? CompetitionDayCoordinatorError, .loadRequired)
        }

        try coordinator.chooseLoad(105, for: second)
        try coordinator.record([.completed, .partial], liftQuality: .technicallyPoor, for: second)

        let result = try XCTUnwrap(coordinator.attempt(for: second)?.recordedResult)
        XCTAssertEqual(result.loadKg, 105)
        XCTAssertEqual(result.outcome, .partial)
        XCTAssertEqual(result.liftQuality, .technicallyPoor)
    }

    func testRecordedAttemptLocksAgainstSilentRewrite() throws {
        var coordinator = CompetitionDayCoordinator(proposal: makeProposal())
        let opener = CompetitionDayAttemptKey(lift: .snatch, attemptNumber: 1)
        try coordinator.record([.completed], for: opener)

        XCTAssertThrowsError(try coordinator.chooseLoad(90, for: opener)) {
            XCTAssertEqual($0 as? CompetitionDayCoordinatorError, .attemptAlreadyRecorded)
        }
        XCTAssertThrowsError(try coordinator.record([.missed], for: opener)) {
            XCTAssertEqual($0 as? CompetitionDayCoordinatorError, .attemptAlreadyRecorded)
        }
        XCTAssertEqual(coordinator.attempt(for: opener)?.recordedResult?.outcome, .made)
    }

    func testWorkoutBuilderSnapshotsBothLiftsAndLeavesUnreviewedLoadsUnstarted() throws {
        let snatch = Exercise(name: "Snatch", primaryMuscles: [.quadriceps])
        let clean = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let jerk = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let cleanAndJerk = Exercise(name: "Clean and Jerk", primaryMuscles: [.quadriceps])
        var program = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: snatch.id,
                exposureKey: "snatch-test",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))]
            ),
            ProgramExerciseDefinition(
                exerciseID: cleanAndJerk.id,
                exposureKey: "clean-jerk-test",
                orderIndex: 1,
                plannedSets: [SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .sequence([
                        RepComponent(exerciseID: clean.id, repetitions: 1),
                        RepComponent(exerciseID: jerk.id, repetitions: 1)
                    ])
                )]
            )
        ])
        program.competitionDisciplineID = "olympicWeightlifting"

        let workout = try CompetitionDayWorkoutBuilder.build(
            program: program,
            proposal: makeProposal(),
            exercisesByID: [snatch.id: snatch, clean.id: clean, jerk.id: jerk, cleanAndJerk.id: cleanAndJerk],
            unitSystem: .metric
        )

        XCTAssertEqual(workout.status, .active)
        XCTAssertEqual(workout.sourceProgramDefinitionID, program.id)
        XCTAssertEqual(workout.orderedExercises.map(\.progressionKey), ["snatch-test", "clean-jerk-test"])
        XCTAssertEqual(workout.orderedExercises.map { $0.orderedSets.count }, [3, 3])
        XCTAssertEqual(workout.orderedExercises[0].orderedSets[0].prescribedSuggestedLoad, 80)
        XCTAssertNil(workout.orderedExercises[0].orderedSets[1].prescribedSuggestedLoad)
        XCTAssertFalse(workout.orderedExercises[0].orderedSets[1].done)
        XCTAssertEqual(workout.orderedExercises[1].orderedSets[0].complexComponents.map(\.exerciseID), [clean.id, jerk.id])
    }

    func testStartServiceRejectsASecondActiveWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let existing = Workout(name: "Existing")
        context.insert(existing)
        XCTAssertTrue(context.saveOrRollback())

        XCTAssertThrowsError(try CompetitionDayStartService.persist(Workout(name: "Competition day"), using: context)) {
            XCTAssertEqual($0 as? CompetitionDayStartService.Error, .activeWorkoutInProgress)
        }
    }

    func testStartedCompetitionWorkoutIsOrdinaryPersistedStateAfterContextReload() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let firstContext = ModelContext(container)
        let workout = Workout(name: "Competition day")
        try CompetitionDayStartService.persist(workout, using: firstContext)

        let secondContext = ModelContext(container)
        let restored = try secondContext.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.name, "Competition day")
        XCTAssertEqual(restored.first?.status, .active)
    }

    private func makeProposal() -> CompetitionPreparationProposal {
        let evidence = CompetitionLiftEvidence(
            lift: .cleanAndJerk,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            sourceWorkoutID: UUID(),
            sourceSetID: UUID(),
            loadKg: 100,
            outcome: .made
        )
        let attempts = CompetitionLift.allCases.flatMap { lift in
            (1...3).map { number in
                CompetitionAttemptProposal(
                    lift: lift,
                    attemptNumber: number,
                    loadKg: number == 1 ? (lift == .cleanAndJerk ? 100 : 80) : nil,
                    evidence: number == 1 ? evidence : nil,
                    reasons: number == 1 ? [] : [.laterAttemptsRequireReview(lift)]
                )
            }
        }
        return CompetitionPreparationProposal(
            eventDate: Date(timeIntervalSince1970: 1_700_086_400),
            testWeek: nil,
            taperWeek: nil,
            openers: [],
            attempts: attempts,
            reasons: []
        )
    }
}

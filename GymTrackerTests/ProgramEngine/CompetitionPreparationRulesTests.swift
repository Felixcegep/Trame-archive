import Foundation
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@MainActor
final class CompetitionPreparationRulesTests: XCTestCase {
    func testProposalUsesAuthoredTestWeekAndLatestSuccessfulLoadsWithoutMutatingProgram() {
        var program = makeOlympicProgram()
        var testWeek = program.blocks[0].weeks[0]
        testWeek.weekIndex = 1
        testWeek.name = "Competition test"
        testWeek.workouts[0].plannedExercises[0].plannedSets[0].role = .test
        program.blocks[0].weeks.append(testWeek)
        program.durationWeeks = 2
        program.competitionDisciplineID = "olympicWeightlifting"
        let before = program

        let planStart = Date(timeIntervalSince1970: 0)
        let eventDate = planStart.addingTimeInterval(9 * 86_400)
        let snatchEvidence = CompetitionLiftEvidence(
            lift: .snatch,
            date: eventDate.addingTimeInterval(-3 * 86_400),
            sourceWorkoutID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sourceSetID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            loadKg: 90,
            outcome: .made,
            liftQuality: .acceptable
        )
        let cleanAndJerkEvidence = CompetitionLiftEvidence(
            lift: .cleanAndJerk,
            date: eventDate.addingTimeInterval(-2 * 86_400),
            sourceWorkoutID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            sourceSetID: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            loadKg: 115,
            outcome: .made
        )
        let proposal = CompetitionPreparationRules.propose(
            CompetitionPreparationRequest(
                eventDate: eventDate,
                asOfDate: planStart,
                planStartDate: planStart,
                program: program,
                performedEvidence: [snatchEvidence, cleanAndJerkEvidence]
            )
        )

        XCTAssertEqual(program, before)
        XCTAssertEqual(proposal.testWeek?.weekIndex, 1)
        XCTAssertEqual(proposal.taperWeek?.weekIndex, 0)
        XCTAssertEqual(proposal.opener(for: .snatch)?.loadKg, 90)
        XCTAssertEqual(proposal.opener(for: .cleanAndJerk)?.loadKg, 115)
        XCTAssertEqual(proposal.attempts(for: .snatch).count, 3)
        XCTAssertEqual(proposal.attempts(for: .snatch)[0].loadKg, 90)
        XCTAssertNil(proposal.attempts(for: .snatch)[1].loadKg)
        XCTAssertTrue(proposal.reasons.contains(.laterAttemptsRequireReview(.snatch)))
    }

    func testMissingOrInvalidEvidenceNeverInventsAnOpener() {
        let program = makeOlympicProgram(discipline: "olympicWeightlifting")
        let eventDate = Date(timeIntervalSince1970: 10 * 86_400)
        let oldMade = CompetitionLiftEvidence(
            lift: .cleanAndJerk,
            date: eventDate.addingTimeInterval(-57 * 86_400),
            sourceWorkoutID: UUID(),
            sourceSetID: UUID(),
            loadKg: 120,
            outcome: .made
        )
        let missedSnatch = CompetitionLiftEvidence(
            lift: .snatch,
            date: eventDate.addingTimeInterval(-2 * 86_400),
            sourceWorkoutID: UUID(),
            sourceSetID: UUID(),
            loadKg: 95,
            outcome: .missed,
            liftQuality: .missed
        )

        let proposal = CompetitionPreparationRules.propose(
            CompetitionPreparationRequest(
                eventDate: eventDate,
                asOfDate: .init(timeIntervalSince1970: 0),
                planStartDate: .init(timeIntervalSince1970: 0),
                program: program,
                performedEvidence: [oldMade, missedSnatch]
            )
        )

        XCTAssertTrue(proposal.openers.isEmpty)
        XCTAssertEqual(proposal.attempts.count, 6)
        XCTAssertTrue(proposal.reasons.contains(.noRecentSuccessfulEvidence(.snatch)))
        XCTAssertTrue(proposal.reasons.contains(.noRecentSuccessfulEvidence(.cleanAndJerk)))
        XCTAssertTrue(proposal.attempts.allSatisfy { $0.loadKg == nil })
    }

    func testInsufficientPlanContextAndEventAlignmentAreExplicit() {
        var program = makeOlympicProgram(discipline: "powerlifting")
        let eventDate = Date(timeIntervalSince1970: 30 * 86_400)
        let proposal = CompetitionPreparationRules.propose(
            CompetitionPreparationRequest(
                eventDate: eventDate,
                asOfDate: eventDate.addingTimeInterval(86_400),
                planStartDate: nil,
                program: program,
                performedEvidence: []
            )
        )

        XCTAssertTrue(proposal.reasons.contains(.eventDateInPast))
        XCTAssertTrue(proposal.reasons.contains(.programIsNotOlympicWeightlifting))
        XCTAssertTrue(proposal.reasons.contains(.planStartDateMissing))
        XCTAssertNil(proposal.testWeek)
        XCTAssertNil(proposal.taperWeek)

        program.competitionDisciplineID = "olympicWeightlifting"
        let alignedElsewhere = CompetitionPreparationRules.propose(
            CompetitionPreparationRequest(
                eventDate: Date(timeIntervalSince1970: 20 * 86_400),
                asOfDate: .init(timeIntervalSince1970: 0),
                planStartDate: .init(timeIntervalSince1970: 0),
                program: program,
                performedEvidence: []
            )
        )
        XCTAssertTrue(alignedElsewhere.reasons.contains(.testWeekNotAuthored))
    }

    private func makeOlympicProgram(discipline: String? = nil) -> ProgramDefinitionPayload {
        var program = ProgramFixtureCatalog.olympicWeightlifting(exerciseIDs: [
            "snatch": UUID(), "pull": UUID(), "complex": UUID(), "clean": UUID()
        ])
        program.competitionDisciplineID = discipline
        return program
    }
}

#endif

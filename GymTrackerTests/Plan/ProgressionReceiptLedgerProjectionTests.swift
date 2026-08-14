import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION
@MainActor
final class ProgressionReceiptLedgerProjectionTests: XCTestCase {
    func testPendingReceiptProjectsProposalEvidenceAndSourceWithoutMutation() throws {
        let planRunID = UUID()
        let workoutID = UUID()
        let record = try makeRecord(planRunID: planRunID, workoutID: workoutID)

        let entry = ProgressionReceiptLedgerProjection.project(record: record)

        XCTAssertEqual(entry.decision, .pending)
        XCTAssertEqual(entry.planRunID, planRunID)
        XCTAssertEqual(entry.workoutID, workoutID)
        XCTAssertEqual(entry.ruleVersion, 3)
        XCTAssertEqual(entry.proposal.load, 105)
        XCTAssertEqual(entry.proposal.repetitionOffset, 1)
        XCTAssertEqual(entry.evidence.action, .addLoad(5))
        XCTAssertEqual(entry.evidence.performance?.completedSets, 4)
        XCTAssertEqual(entry.evidence.actionAvailability, .decoded)
        XCTAssertEqual(entry.evidence.performanceAvailability, .decoded)
    }

    func testAcceptedUsesProposedLoadAsAppliedValue() throws {
        let record = try makeRecord()
        record.isResolved = true
        record.decisionOutcome = .accepted
        record.resolvedAt = Date(timeIntervalSince1970: 200)

        let entry = ProgressionReceiptLedgerProjection.project(record: record)

        XCTAssertEqual(entry.decision, .accepted)
        XCTAssertEqual(entry.appliedLoad, 105)
        XCTAssertNil(entry.explicitlyRecordedAppliedLoad)
        XCTAssertEqual(entry.resolvedAt, Date(timeIntervalSince1970: 200))
    }

    func testModifiedAcceptanceUsesOnlyExplicitAppliedValue() throws {
        let record = try makeRecord()
        record.isResolved = true
        record.decisionOutcome = .acceptedWithModifiedValue
        record.appliedLoad = 102.5

        let entry = ProgressionReceiptLedgerProjection.project(record: record)

        XCTAssertEqual(entry.decision, .acceptedWithModifiedValue)
        XCTAssertEqual(entry.appliedLoad, 102.5)
        XCTAssertEqual(entry.explicitlyRecordedAppliedLoad, 102.5)
    }

    func testDeclinedAndLegacyResolvedRowsDoNotInventAppliedValuesOrDecisions() throws {
        let declined = try makeRecord()
        declined.isResolved = true
        declined.decisionOutcome = .declined
        declined.appliedLoad = 111

        let legacy = try makeRecord()
        legacy.isResolved = true
        legacy.decisionOutcome = nil
        legacy.appliedLoad = nil

        let declinedEntry = ProgressionReceiptLedgerProjection.project(record: declined)
        let legacyEntry = ProgressionReceiptLedgerProjection.project(record: legacy)

        XCTAssertEqual(declinedEntry.decision, .declined)
        XCTAssertNil(declinedEntry.appliedLoad)
        XCTAssertEqual(legacyEntry.decision, .outcomeNotRecorded)
        XCTAssertNil(legacyEntry.appliedLoad)
    }

    func testUnreadableAndAbsentEvidenceStayExplicit() throws {
        let unreadable = try makeRecord()
        unreadable.actionData = Data([0xFF])
        unreadable.performanceData = Data([0xFF])

        let absent = try makeRecord()
        absent.performanceData = nil

        let unreadableEntry = ProgressionReceiptLedgerProjection.project(record: unreadable)
        let absentEntry = ProgressionReceiptLedgerProjection.project(record: absent)

        XCTAssertEqual(unreadableEntry.evidence.actionAvailability, .unreadable)
        XCTAssertEqual(unreadableEntry.evidence.performanceAvailability, .unreadable)
        XCTAssertEqual(absentEntry.evidence.performanceAvailability, .absent)
    }

    func testLedgerOrderingIsNewestFirstWithStableIDTieBreak() throws {
        let older = try makeRecord()
        older.createdAt = Date(timeIntervalSince1970: 100)
        let newer = try makeRecord()
        newer.createdAt = Date(timeIntervalSince1970: 200)

        let entries = ProgressionReceiptLedgerProjection.project(records: [older, newer])

        XCTAssertEqual(entries.map(\.createdAt), [Date(timeIntervalSince1970: 200), Date(timeIntervalSince1970: 100)])
    }

    func testDecisionSummaryKeepsEveryRecordedOutcomeDistinctAndOmitsZeroBuckets() throws {
        let pending = try makeRecord()
        let accepted = try makeRecord()
        accepted.isResolved = true
        accepted.decisionOutcome = .accepted
        let modified = try makeRecord()
        modified.isResolved = true
        modified.decisionOutcome = .acceptedWithModifiedValue
        let declined = try makeRecord()
        declined.isResolved = true
        declined.decisionOutcome = .declined
        let legacy = try makeRecord()
        legacy.isResolved = true
        legacy.decisionOutcome = nil

        let entries = ProgressionReceiptLedgerProjection.project(
            records: [pending, accepted, modified, declined, legacy, accepted]
        )
        let summary = ProgressionReceiptLedgerProjection.decisionSummary(entries: entries)

        XCTAssertEqual(
            summary,
            [
                .init(decision: .pending, count: 1),
                .init(decision: .accepted, count: 2),
                .init(decision: .acceptedWithModifiedValue, count: 1),
                .init(decision: .declined, count: 1),
                .init(decision: .outcomeNotRecorded, count: 1)
            ]
        )
    }

    func testDecisionSummaryForEmptyLedgerIsEmpty() {
        XCTAssertTrue(ProgressionReceiptLedgerProjection.decisionSummary(entries: []).isEmpty)
    }

    private func makeRecord(
        planRunID: UUID = UUID(),
        workoutID: UUID = UUID()
    ) throws -> PlanProgressionRecommendationRecord {
        var performance = ProgressionPerformance()
        performance.requiredSets = 5
        performance.completedSets = 4
        performance.requiredRepetitions = 25
        performance.completedRepetitions = 20

        var proposedState = ProgressionEvaluationState()
        proposedState.currentLoad = 105
        proposedState.repetitionOffset = 1
        proposedState.setCountOffset = 0
        proposedState.isDeloading = false

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addLoad(5),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reason: "legacy reason",
            reasonKey: "progression.receipt.reason.triggerSatisfied",
            applicationMode: .recommendation,
            proposedState: proposedState,
            performance: performance,
            ruleVersion: 3
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: planRunID,
            workoutID: workoutID,
            proposedLoadUnit: .kg
        )
        record.createdAt = Date(timeIntervalSince1970: 150)
        record.progressionKey = "squat"
        return record
    }
}
#endif

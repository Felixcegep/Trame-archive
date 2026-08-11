import Foundation
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@MainActor
final class ProgressionRecommendationPreviewTests: XCTestCase {
    func testPreviewExposesExactEvidenceStateDiffAndFutureOccurrences() throws {
        let sourceWorkout = Workout(name: "Source", endTime: Date(timeIntervalSince1970: 100))
        let run = PlanRun(
            sourcePlanID: UUID(),
            sourcePlanName: "Strength",
            startDate: Date(timeIntervalSince1970: 0)
        )
        let source = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Week 1",
            weekIndex: 0,
            workoutIndex: 0
        )
        source.status = .completed
        source.completedWorkout = sourceWorkout
        let futureOne = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Week 2",
            weekIndex: 1,
            workoutIndex: 0
        )
        let futureTwo = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Week 3",
            weekIndex: 2,
            workoutIndex: 0
        )
        run.workoutProgress = [source, futureOne, futureTwo]

        var performance = ProgressionPerformance(requiredSets: 5, completedSets: 5)
        performance.requiredRepetitions = 25
        performance.completedRepetitions = 25
        performance.workoutCompleted = true
        let current = ProgressionEvaluationState(currentLoad: 100)
        let proposed = ProgressionEvaluationState(currentLoad: 105)
        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addLoad(5),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reason: "All required sets completed",
            reasonKey: "progression.receipt.reason.triggerSatisfied",
            applicationMode: .recommendation,
            proposedState: proposed,
            performance: performance,
            ruleVersion: 4
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: sourceWorkout.id,
            proposedLoadUnit: .kg
        )
        record.progressionKey = "squat"

        let preview = ProgressionRecommendationPreviewPolicy.make(
            for: record,
            currentPrescription: current,
            in: run
        )

        XCTAssertEqual(preview.currentPrescription, current)
        XCTAssertEqual(preview.proposedPrescription.currentLoad, 105)
        XCTAssertEqual(preview.exactEvidence, performance)
        XCTAssertEqual(preview.ruleVersion, 4)
        XCTAssertEqual(preview.changedFields, [.load])
        XCTAssertEqual(preview.futureOccurrences.count, 2)
        XCTAssertEqual(preview.futureOccurrences.map(\.plannedWorkoutName), ["Week 2", "Week 3"])
        XCTAssertTrue(preview.unchangedAreas.contains(.performedWorkoutHistory))
        XCTAssertTrue(preview.unchangedAreas.contains(.recommendationEvidence))
        XCTAssertTrue(preview.isActionable)
    }

    func testMissingEvidenceAndCurrentPrescriptionRemainExplicit() throws {
        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addLoad(2.5),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reason: "Legacy recommendation",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 82.5),
            performance: ProgressionPerformance(),
            ruleVersion: nil
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: UUID(),
            workoutID: UUID()
        )
        record.actionData = Data([0x01])
        record.performanceData = nil

        let preview = ProgressionRecommendationPreviewPolicy.make(
            for: record,
            currentPrescription: nil
        )

        XCTAssertNil(preview.action)
        XCTAssertNil(preview.exactEvidence)
        XCTAssertTrue(preview.insufficiencies.contains(.actionUnavailable))
        XCTAssertTrue(preview.insufficiencies.contains(.evidenceUnavailable))
        XCTAssertTrue(preview.insufficiencies.contains(.currentPrescriptionUnavailable))
        XCTAssertTrue(preview.insufficiencies.contains(.ruleVersionUnavailable))
        XCTAssertFalse(preview.isActionable)
    }

    func testDeclineIsSuppressedUntilCallerProvidesNewEvidence() throws {
        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addRepetitions(1),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reason: "Add a repetition",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(repetitionOffset: 1),
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            ruleVersion: 2
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: UUID(),
            workoutID: UUID()
        )
        record.decisionOutcome = .declined
        record.isResolved = true

        let suppressed = ProgressionRecommendationPreviewPolicy.make(
            for: record,
            currentPrescription: ProgressionEvaluationState(),
            newEvidenceSinceDecline: false
        )
        let reoffered = ProgressionRecommendationPreviewPolicy.make(
            for: record,
            currentPrescription: ProgressionEvaluationState(),
            newEvidenceSinceDecline: true
        )

        XCTAssertEqual(suppressed.decisionState, .declined)
        XCTAssertEqual(suppressed.reofferState, .suppressedUntilNewEvidence)
        XCTAssertTrue(suppressed.unchangedAreas.contains(.declinedPrescription))
        XCTAssertEqual(reoffered.reofferState, .eligibleAfterNewEvidence)
    }
}

#endif

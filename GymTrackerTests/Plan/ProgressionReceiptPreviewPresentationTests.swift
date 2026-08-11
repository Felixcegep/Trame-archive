import Foundation
import SwiftData
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@MainActor
final class ProgressionReceiptPreviewPresentationTests: XCTestCase {
    func testPresentationNamesExactChangedValuesAndHistoryGuarantees() {
        let recommendationID = UUID()
        let preview = ProgressionRecommendationPreview(
            recommendationID: recommendationID,
            ruleID: UUID(),
            ruleVersion: 3,
            action: .addLoad(2.5),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reasonKey: nil,
            exactEvidence: ProgressionPerformance(completedSets: 3),
            currentPrescription: ProgressionEvaluationState(currentLoad: 100),
            proposedPrescription: ProgressionEvaluationState(currentLoad: 102.5),
            changedFields: [.load],
            unchangedFields: [],
            futureOccurrences: [],
            unchangedAreas: [.performedWorkoutHistory, .recommendationEvidence],
            decisionState: .pending,
            reofferState: .eligible,
            insufficiencies: []
        )

        let presentation = ProgressionReceiptPreviewPresentation.make(preview: preview, unit: .kg)

        XCTAssertEqual(presentation.changedFields, ["Load: 100 kg → 102.5 kg"])
        XCTAssertTrue(presentation.futureScope.contains("next workout"))
        XCTAssertTrue(presentation.futureScope.contains("No future occurrences"))
        XCTAssertTrue(presentation.unchangedGuarantees.contains("Completed workout history remains unchanged."))
        XCTAssertTrue(presentation.unchangedGuarantees.contains("The recommendation evidence remains unchanged."))
        XCTAssertNil(presentation.availabilityNote)
    }

    func testPreviewProposedStateMatchesAppliedStateAndPerformedHistoryIsUntouched() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Completed", endTime: .now)
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Preview", startDate: .now)
        let progress = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Day one",
            weekIndex: 0,
            workoutIndex: 0
        )
        progress.status = .completed
        progress.completedWorkout = workout
        let state = PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)
        run.workoutProgress = [progress]
        run.progressionStates = [state]
        context.insert(workout)
        context.insert(run)

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addLoad(2.5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            reason: "Completed the prescription.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 102.5),
            performance: ProgressionPerformance(completedSets: 3),
            ruleVersion: 1
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: workout.id,
            proposedLoadUnit: .kg
        )
        record.progressionKey = "squat"
        context.insert(record)
        try context.save()

        let preview = PlanProgressionRecommendationService.preview(record, in: run)
        let beforeHistory = workout.endTime
        XCTAssertEqual(preview.proposedPrescription.currentLoad, 102.5)
        XCTAssertTrue(preview.changedFields.contains(.load))
        XCTAssertTrue(preview.unchangedAreas.contains(.performedWorkoutHistory))

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)

        let applied = PlanProgressionCadenceService.state(from: state)
        XCTAssertEqual(applied.currentLoad, preview.proposedPrescription.currentLoad)
        XCTAssertEqual(record.decisionOutcome, .accepted)
        XCTAssertEqual(workout.endTime, beforeHistory)
    }

    func testAcceptanceWithMissingScopedStateLeavesReceiptUnresolved() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Preview", startDate: .now)
        context.insert(run)
        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addLoad(2.5),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reason: "No matching state.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 102.5),
            performance: ProgressionPerformance(),
            ruleVersion: 1
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: UUID()
        )
        record.progressionKey = "missing"
        context.insert(record)
        try context.save()

        let preview = PlanProgressionRecommendationService.preview(record, in: run)
        XCTAssertTrue(preview.insufficiencies.contains(.currentPrescriptionUnavailable))
        try PlanProgressionRecommendationService.accept(record, in: run, context: context)
        XCTAssertFalse(record.isResolved)
        XCTAssertNil(record.decisionOutcome)
    }

    func testModifiedValueFailureLeavesStructuralRecommendationAndStateUnchanged() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Preview", startDate: .now)
        let state = PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)
        run.progressionStates = [state]
        context.insert(run)
        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .endActiveDailyMaximumAndGenerateBackOffs(setCount: 2, repetitions: 5, percentage: 0.8),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            reason: "Structural active-workout action.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 105),
            performance: ProgressionPerformance(),
            ruleVersion: 1
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: UUID()
        )
        record.progressionKey = "squat"
        context.insert(record)
        try context.save()

        XCTAssertThrowsError(
            try PlanProgressionRecommendationService.accept(record, withLoad: 97.5, in: run, context: context)
        )
        XCTAssertEqual(state.currentLoad, 100)
        XCTAssertFalse(record.isResolved)
        XCTAssertNil(record.appliedLoad)
        XCTAssertNil(record.decisionOutcome)
    }
}

#endif

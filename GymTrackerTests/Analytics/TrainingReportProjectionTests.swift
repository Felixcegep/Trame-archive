import XCTest
@testable import GymTracker

@MainActor
final class TrainingReportProjectionTests: XCTestCase {
    func testEmptySelectionIsExplicitAndDistinguishesZeroFromUnavailable() throws {
        let range = TrainingReportDateRange(
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let selection = TrainingReportSelection(
            dateRange: range,
            selectedWorkoutIDs: [],
            includeSportSpecificPerformance: true,
            includeMobility: true,
            includeProgressionReceipts: true,
            includeNotesAndEvidence: true
        )

        let artifact = TrainingReportProjection.build(selection: selection, workouts: [])

        let summary = try XCTUnwrap(artifact.sections.first { $0.kind == .summary })
        XCTAssertEqual(summary.rows.first { $0.id == "summary.completed-workouts" }?.availability, .zero)
        XCTAssertEqual(artifact.sections.first { $0.kind == .workouts }?.rows.first?.availability, .unavailable)
        XCTAssertFalse(artifact.preview.mayShare)
        XCTAssertTrue(artifact.humanReadableText.contains("Completed workouts: 0"))
        XCTAssertTrue(artifact.humanReadableText.contains("Sport-specific performance: Unavailable"))
    }

    func testOnlyCompletedWorkoutsInsideDateAndPlanSelectionBecomeReportEvidence() {
        let planID = UUID()
        let included = makeWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: Date(timeIntervalSince1970: 1_100),
            completed: true,
            planID: planID
        )
        let active = makeWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            date: Date(timeIntervalSince1970: 1_200),
            completed: false,
            planID: planID
        )
        let outsidePlan = makeWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            date: Date(timeIntervalSince1970: 1_300),
            completed: true,
            planID: UUID()
        )
        let selection = TrainingReportSelection(
            dateRange: TrainingReportDateRange(
                start: Date(timeIntervalSince1970: 1_000),
                end: Date(timeIntervalSince1970: 1_500)
            ),
            selectedPlanIDs: [planID],
            selectedWorkoutIDs: [included.id, active.id, outsidePlan.id]
        )

        let artifact = TrainingReportProjection.build(
            selection: selection,
            workouts: [outsidePlan, active, included]
        )

        XCTAssertEqual(artifact.preview.selectedWorkoutCount, 1)
        XCTAssertEqual(
            artifact.sections.first { $0.kind == .workouts }?.rows.compactMap { $0.source?.workoutID },
            [included.id]
        )
    }

    func testSharePreviewRequiresExplicitConfirmationAndListsRequestedSensitiveData() {
        let planID = UUID()
        let workout = makeWorkout(
            date: Date(timeIntervalSince1970: 1_100),
            completed: true,
            planID: planID
        )
        workout.notes = "Felt strong"
        let selection = TrainingReportSelection(
            dateRange: TrainingReportDateRange(
                start: Date(timeIntervalSince1970: 1_000),
                end: Date(timeIntervalSince1970: 2_000)
            ),
            selectedPlanIDs: [planID],
            selectedWorkoutIDs: [workout.id],
            includeSportSpecificPerformance: true,
            includeMobility: true,
            includeProgressionReceipts: true,
            includeNotesAndEvidence: true
        )

        let artifact = TrainingReportProjection.build(selection: selection, workouts: [workout])

        XCTAssertEqual(artifact.preview.shareConfirmation, .notConfirmed)
        XCTAssertFalse(artifact.preview.mayShare)
        XCTAssertTrue(artifact.preview.includedSensitiveCategories.contains(.workoutPerformance))
        XCTAssertTrue(artifact.preview.includedSensitiveCategories.contains(.planIdentity))
        XCTAssertTrue(artifact.preview.includedSensitiveCategories.contains(.sportSpecificPerformance))
        XCTAssertTrue(artifact.preview.includedSensitiveCategories.contains(.mobility) == false)
        XCTAssertTrue(artifact.preview.includedSensitiveCategories.contains(.progressionReceipts) == false)
        XCTAssertTrue(artifact.preview.includedSensitiveCategories.contains(.notesAndEvidence))

        let confirmed = artifact.preview.confirmingShare()
        XCTAssertEqual(confirmed.shareConfirmation, .explicitlyConfirmed)
        XCTAssertTrue(confirmed.mayShare)
        XCTAssertFalse(artifact.preview.mayShare)
    }

    func testHumanReadableOutputIsStableForStableInputs() {
        let workout = makeWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            date: Date(timeIntervalSince1970: 1_100),
            completed: true
        )
        workout.notes = "Stable note"
        let selection = TrainingReportSelection(
            dateRange: TrainingReportDateRange(
                start: Date(timeIntervalSince1970: 1_000),
                end: Date(timeIntervalSince1970: 2_000)
            ),
            selectedWorkoutIDs: [workout.id],
            includeNotesAndEvidence: true
        )

        let first = TrainingReportProjection.build(selection: selection, workouts: [workout])
        let second = TrainingReportProjection.build(selection: selection, workouts: [workout])

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.humanReadableText.contains("## Report summary"))
        XCTAssertTrue(first.humanReadableText.contains("Workout note: Stable"))
    }

    private func makeWorkout(
        id: UUID = UUID(),
        date: Date,
        completed: Bool,
        planID: UUID? = nil
    ) -> Workout {
        let workout = Workout(name: "Stable", endTime: completed ? date.addingTimeInterval(60) : nil)
        workout.id = id
        workout.startTime = date
        workout.sourcePlanID = planID
        return workout
    }
}

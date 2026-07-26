import Foundation
import SwiftData
import XCTest
@testable import GymTracker

/// Characterizes the existing template-workout lifecycle that Repeating Plan
/// sessions will reuse. These tests intentionally use no repeating-plan types,
/// so they protect the current snapshot, discard, and relaunch boundary while
/// the new domain is introduced.
@MainActor
final class WorkoutLifecycleCharacterizationTests: XCTestCase {
    func testTemplateStartSnapshotsPrescriptionAndProgressionAcrossSourceEditsAndRestore() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = WorkoutTestFixture.makeExercise()
        let templateExercise = TemplateExercise(
            exercise: exercise,
            order: 0,
            targetSets: 2,
            repRangeMinimum: 6,
            repRangeMaximum: 8,
            restSeconds: 75,
            targetRPE: 8,
            notes: "Original prescription",
            progressionRule: .doubleProgression
        )
        let template = WorkoutTemplate(
            name: "Snapshot Template",
            exercises: [exercise],
            templateExercises: [templateExercise]
        )
        let completedWorkout = completedWorkout(exercise: exercise)

        context.insert(exercise)
        context.insert(template)
        context.insert(completedWorkout)
        try context.save()

        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(with: template, using: context))

        let activeWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let activeEntry = try XCTUnwrap(activeWorkout.orderedExercises.first)
        XCTAssertEqual(activeWorkout.name, "Snapshot Template")
        XCTAssertEqual(activeWorkout.sourceTemplate?.id, template.id)
        XCTAssertEqual(activeEntry.prescribedSets, 2)
        XCTAssertEqual(activeEntry.prescribedRepRangeMinimum, 6)
        XCTAssertEqual(activeEntry.prescribedRepRangeMaximum, 8)
        XCTAssertEqual(activeEntry.prescribedRestSeconds, 75)
        XCTAssertEqual(activeEntry.prescribedRPE, 8)
        XCTAssertEqual(activeEntry.prescriptionNotes, "Original prescription")
        XCTAssertEqual(activeEntry.orderedSets.count, 2)
        XCTAssertEqual(activeEntry.recommendedDecision, .increase)

        // These edits represent later authoring changes. They apply to future
        // starts only and must not reinterpret the recoverable active session.
        template.name = "Edited Template"
        templateExercise.targetSets = 4
        templateExercise.repRangeMaximum = 12
        templateExercise.restSeconds = 30
        templateExercise.targetRPE = 6
        templateExercise.notes = "Edited prescription"
        try context.save()

        let restoreContext = ModelContext(container)
        let restoredViewModel = WorkoutViewModel()
        XCTAssertTrue(restoredViewModel.restoreActiveWorkout(using: restoreContext))

        let restoredWorkout = try XCTUnwrap(restoredViewModel.activeWorkout)
        let restoredEntry = try XCTUnwrap(restoredWorkout.orderedExercises.first)
        XCTAssertEqual(restoredWorkout.id, activeWorkout.id)
        XCTAssertEqual(restoredWorkout.name, "Snapshot Template")
        XCTAssertEqual(restoredWorkout.sourceTemplate?.id, template.id)
        XCTAssertEqual(restoredEntry.prescribedSets, 2)
        XCTAssertEqual(restoredEntry.prescribedRepRangeMinimum, 6)
        XCTAssertEqual(restoredEntry.prescribedRepRangeMaximum, 8)
        XCTAssertEqual(restoredEntry.prescribedRestSeconds, 75)
        XCTAssertEqual(restoredEntry.prescribedRPE, 8)
        XCTAssertEqual(restoredEntry.prescriptionNotes, "Original prescription")
        XCTAssertEqual(restoredEntry.orderedSets.count, 2)
        XCTAssertEqual(restoredEntry.recommendedDecision, .increase)
    }

    func testDiscardedTemplateWorkoutCannotBeRestoredAndLeavesTemplateReusable() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        context.insert(exercise)
        context.insert(template)
        try context.save()

        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(with: template, using: context))
        let activeWorkoutID = try XCTUnwrap(viewModel.activeWorkout?.id)

        viewModel.discardActiveWorkout(using: context)

        XCTAssertNil(viewModel.activeWorkout)
        let restoreContext = ModelContext(container)
        XCTAssertFalse(WorkoutViewModel().restoreActiveWorkout(using: restoreContext))
        XCTAssertFalse(
            try restoreContext.fetch(FetchDescriptor<Workout>()).contains { $0.id == activeWorkoutID }
        )
        XCTAssertEqual(
            try restoreContext.fetch(FetchDescriptor<WorkoutTemplate>()).first?.id,
            template.id
        )
    }

    private func completedWorkout(exercise: Exercise) -> Workout {
        let workout = Workout(name: "Completed evidence", endTime: .now.addingTimeInterval(-86_400))
        let entry = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 8, weight: 50, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 8, weight: 50, done: true, orderIndex: 1, usedMetric: .metric)
        ]
        workout.exercises = [entry]
        workout.startTime = workout.endTime?.addingTimeInterval(-3_600) ?? .now
        return workout
    }
}

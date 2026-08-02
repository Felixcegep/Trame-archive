import XCTest
@testable import GymTracker

@MainActor
final class WorkoutGenerationTests: XCTestCase {
    func testValidatorRejectsStaleAndDuplicateExercisesAndClampsMalformedPrescription() throws {
        let live = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let archived = Exercise(name: "Archived Press", primaryMuscles: [.upperChest])
        archived.isArchived = true
        let draft = GeneratedWorkoutDraft(
            name: "  ",
            estimatedDurationMinutes: 500,
            rationale: "  Bench focus  ",
            exercises: [
                GeneratedWorkoutExercise(exerciseID: UUID(), sets: 3, minimumRepetitions: 8, maximumRepetitions: 10, restSeconds: 90, targetRIR: nil, targetRPE: nil, notes: nil, groupID: nil),
                GeneratedWorkoutExercise(exerciseID: archived.id, sets: 3, minimumRepetitions: 8, maximumRepetitions: 10, restSeconds: 90, targetRIR: nil, targetRPE: nil, notes: nil, groupID: nil),
                GeneratedWorkoutExercise(exerciseID: live.id, sets: 99, minimumRepetitions: 20, maximumRepetitions: -2, restSeconds: 900, targetRIR: 20, targetRPE: 8, notes: "  Stable  ", groupID: nil),
                GeneratedWorkoutExercise(exerciseID: live.id, sets: 3, minimumRepetitions: 8, maximumRepetitions: 10, restSeconds: 90, targetRIR: nil, targetRPE: nil, notes: nil, groupID: nil),
            ],
            assumptions: ["  Home gym  ", "  "],
            warnings: [],
        )

        let validated = try WorkoutDraftValidator.validate(draft, against: [live, archived])

        XCTAssertEqual(validated.name, "Personalized Workout")
        XCTAssertEqual(validated.estimatedDurationMinutes, WorkoutDraftValidator.estimatedDurationRange.upperBound)
        XCTAssertEqual(validated.rationale, "Bench focus")
        XCTAssertEqual(validated.exercises.count, 1)
        XCTAssertEqual(validated.exercises[0].targetSets, WorkoutDraftValidator.setsRange.upperBound)
        XCTAssertEqual(validated.exercises[0].repRangeMinimum, 20)
        XCTAssertEqual(validated.exercises[0].repRangeMaximum, 20)
        XCTAssertEqual(validated.exercises[0].restSeconds, WorkoutDraftValidator.restSecondsRange.upperBound)
        XCTAssertEqual(validated.exercises[0].targetRIR, 10)
        XCTAssertNil(validated.exercises[0].targetRPE, "RIR deterministically wins over conflicting RPE.")
        XCTAssertEqual(validated.exercises[0].notes, "Stable")
        XCTAssertEqual(validated.assumptions, ["Home gym"])
        XCTAssertTrue(validated.validationWarnings.contains(.ignoredUnknownOrArchivedExercise(archived.id)))
        XCTAssertTrue(validated.validationWarnings.contains(.ignoredDuplicateExercise(live.id)))
        XCTAssertTrue(validated.validationWarnings.contains(.adjustedPrescription(live.id)))
    }

    func testValidatorRetainsOnlyContiguousSupersets() throws {
        let first = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let second = Exercise(name: "Row", primaryMuscles: [.latissimusDorsi])
        let third = Exercise(name: "Curl", primaryMuscles: [.bicep])
        let fourth = Exercise(name: "Pressdown", primaryMuscles: [.tricepLateralHead])
        let draft = GeneratedWorkoutDraft(
            name: "Upper",
            estimatedDurationMinutes: 45,
            rationale: "",
            exercises: [
                generatedExercise(first, groupID: "pair"),
                generatedExercise(second, groupID: "pair"),
                generatedExercise(third, groupID: "orphan"),
                generatedExercise(fourth, groupID: nil),
            ],
            assumptions: [],
            warnings: []
        )

        let validated = try WorkoutDraftValidator.validate(draft, against: [first, second, third, fourth])

        XCTAssertNotNil(validated.exercises[0].supersetGroupID)
        XCTAssertEqual(validated.exercises[0].supersetGroupID, validated.exercises[1].supersetGroupID)
        XCTAssertNil(validated.exercises[2].supersetGroupID)
        XCTAssertNil(validated.exercises[3].supersetGroupID)
        XCTAssertTrue(validated.validationWarnings.contains(.removedInvalidSuperset("orphan")))
    }

    func testContextUsesBoundedEligibleCatalogueCompletedHistoryAndRealTemplateExamples() {
        let eligible = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        eligible.isFavorite = true
        let excluded = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let archived = Exercise(name: "Old Row", primaryMuscles: [.latissimusDorsi])
        archived.isArchived = true
        let completed = Workout(name: "Completed", endTime: .now)
        completed.exercises = [ExerciseEntry(exercise: eligible, usedMetric: .metric)]
        let template = WorkoutTemplate(
            name: "My upper day",
            exercises: [eligible],
            templateExercises: [TemplateExercise(exercise: eligible, order: 0, targetSets: 4, repRangeMinimum: 5, repRangeMaximum: 6)]
        )

        let input = WorkoutGenerationContextBuilder.build(
            request: WorkoutGenerationRequest(excludedExerciseIDs: [excluded.id]),
            profile: nil,
            preferences: WorkoutGenerationPreferences(),
            exercises: [archived, excluded, eligible],
            completedWorkouts: [completed],
            templates: [template],
            now: .now
        )

        XCTAssertEqual(input.availableExercises.map(\.exerciseID), [eligible.id])
        XCTAssertEqual(input.recentTraining.exposures.map(\.exerciseID), [eligible.id])
        XCTAssertEqual(input.recentTraining.exposures.first?.completedWorkoutCount, 1)
        XCTAssertEqual(input.examples.map(\.name), ["My upper day"])
        XCTAssertEqual(input.examples.first?.exercises.first?.exerciseID, eligible.id)
    }

    func testAvailabilityOverrideIsDeterministicAndManualPathsDoNotNeedTheModel() {
        XCTAssertEqual(
            WorkoutGenerationAvailability.status(
                arguments: ["Trame", "-ui-test-workout-generation-availability", "modelDownloading"],
                environment: [:]
            ),
            .modelDownloading
        )
        XCTAssertEqual(
            WorkoutGenerationAvailability.status(
                arguments: ["Trame"],
                environment: ["GYMTRACKER_WORKOUT_GENERATION_AVAILABILITY": "unsupportedLocale"]
            ),
            .unsupportedLocale
        )
    }

    func testIntentLaunchPayloadNormalizesWithoutCreatingAWorkout() {
        let payload = WorkoutGenerationLaunchRequest(
            request: "  Upper body  ",
            durationMinutes: 400,
            focus: "  strength  "
        )
        let store = AppIntentRouteStore.shared
        _ = store.consume()
        store.submit(.personalizedWorkout(payload))

        XCTAssertEqual(payload.request, "Upper body")
        XCTAssertNil(payload.durationMinutes)
        XCTAssertEqual(payload.focus, "strength")
        XCTAssertEqual(store.consume(), .personalizedWorkout(payload))
        XCTAssertNil(store.consume(), "The handoff is consumed once and cannot start anything itself.")
    }

    private func generatedExercise(_ exercise: Exercise, groupID: String?) -> GeneratedWorkoutExercise {
        GeneratedWorkoutExercise(
            exerciseID: exercise.id,
            sets: 3,
            minimumRepetitions: 8,
            maximumRepetitions: 10,
            restSeconds: 90,
            targetRIR: 2,
            targetRPE: nil,
            notes: nil,
            groupID: groupID
        )
    }
}

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

/// `WorkoutExecutionBlock` / `TemplateExerciseBlock`: authoring a block on a
/// template, snapshotting it fresh onto a started workout and a generated
/// plan, validating membership/format rules, running its clock, and
/// persisting it (including through backup) without losing its evidence.
@MainActor
final class ExecutionBlockTests: XCTestCase {
    func testExecutionBlockTracksElapsedTimeAndIsOwnedByWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Complex session")
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .olympicComplex,
            name: "Clean complex",
            targetRounds: 4,
            isSharedLoad: true,
            restSeconds: 180
        )
        workout.executionBlocks = [block]
        context.insert(workout)
        try context.save()

        let startedAt = Date(timeIntervalSince1970: 1_000)
        block.start(at: startedAt)
        block.pause(at: startedAt.addingTimeInterval(45))

        XCTAssertEqual(block.status, .inProgress)
        XCTAssertEqual(block.elapsedDuration(at: startedAt.addingTimeInterval(50)), 45)
        XCTAssertEqual(workout.orderedExecutionBlocks.first?.id, block.id)
    }

    func testTemplateBlockSnapshotsFreshIdentityAndComponentMembership() throws {
        let clean = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let jerk = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let cleanTemplate = TemplateExercise(exercise: clean, order: 0)
        let jerkTemplate = TemplateExercise(exercise: jerk, order: 1)
        let template = WorkoutTemplate(
            name: "Complex",
            exercises: [clean, jerk],
            templateExercises: [cleanTemplate, jerkTemplate]
        )
        let block = TemplateExerciseBlock(
            orderIndex: 0,
            kind: .olympicComplex,
            targetRounds: 4,
            isSharedLoad: true,
            restSeconds: 180
        )
        template.executionBlocks = [block]
        cleanTemplate.executionBlockID = block.id
        cleanTemplate.executionBlockComponentOrder = 0
        jerkTemplate.executionBlockID = block.id
        jerkTemplate.executionBlockComponentOrder = 1

        let workout = Workout(template: template, unitSystem: .metric)
        let snapshottedBlock = try XCTUnwrap(workout.orderedExecutionBlocks.first)

        XCTAssertNotEqual(snapshottedBlock.id, block.id)
        XCTAssertEqual(snapshottedBlock.sourceTemplateBlockID, block.id)
        XCTAssertEqual(workout.orderedExercises.map(\.executionBlockID), [snapshottedBlock.id, snapshottedBlock.id])
        XCTAssertEqual(workout.orderedExercises.map(\.executionBlockComponentOrder), [0, 1])
    }

    func testExecutionBlockServiceValidatesMembershipAndRecordsCappedAMRAP() throws {
        let first = Exercise(name: "Pull-Up", primaryMuscles: [.latissimusDorsi])
        let second = Exercise(name: "Push-Up", primaryMuscles: [.upperChest])
        let other = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let workout = Workout(name: "Conditioning")
        let firstEntry = ExerciseEntry(exercise: first, usedMetric: .metric)
        let secondEntry = ExerciseEntry(exercise: second, usedMetric: .metric)
        let unassignedEntry = ExerciseEntry(exercise: other, usedMetric: .metric)
        workout.exercises = [firstEntry, secondEntry, unassignedEntry]

        XCTAssertThrowsError(
            try WorkoutExecutionBlockService.create(kind: .pairedSet, entries: [firstEntry], in: workout)
        )
        XCTAssertThrowsError(
            try WorkoutExecutionBlockService.create(
                kind: .circuit,
                entries: [firstEntry, ExerciseEntry(exercise: other, usedMetric: .metric)],
                in: workout
            )
        )

        let block = try WorkoutExecutionBlockService.create(
            kind: .amrap,
            entries: [firstEntry, secondEntry],
            in: workout,
            targetRounds: nil,
            clockMode: .countUp,
            timeCapSeconds: 600,
            scoreKind: .roundsAndRepetitions
        )
        let start = Date(timeIntervalSince1970: 1_000)
        WorkoutExecutionBlockService.start(block, at: start)
        WorkoutExecutionBlockService.completeRound(in: block)
        WorkoutExecutionBlockService.recordAdditionalRepetitions(7, in: block)
        WorkoutExecutionBlockService.cap(block, at: start.addingTimeInterval(600))

        XCTAssertEqual(block.status, .capped)
        XCTAssertEqual(block.completedRounds, 1)
        XCTAssertEqual(block.additionalRepetitions, 7)
        XCTAssertEqual(
            WorkoutExecutionBlockService.entries(in: block, workout: workout).map(ObjectIdentifier.init),
            [ObjectIdentifier(firstEntry), ObjectIdentifier(secondEntry)]
        )

        XCTAssertThrowsError(
            try WorkoutExecutionBlockService.create(
                kind: .ladder,
                entries: [unassignedEntry],
                in: workout,
                repetitionScheme: .fixed
            )
        )

        try WorkoutExecutionBlockService.update(
            block,
            configuration: WorkoutExecutionBlockConfiguration(
                kind: .triset,
                name: "Bodyweight triset",
                targetRounds: 3,
                isSharedLoad: false,
                restSeconds: 45,
                clockMode: .none,
                prescribedDurationSeconds: nil,
                timeCapSeconds: nil,
                intervalSeconds: nil,
                scoreKind: .completedWork,
                repetitionScheme: .fixed,
                repetitionStart: nil,
                repetitionEnd: nil,
                repetitionStep: nil
            ),
            entries: [firstEntry, secondEntry, unassignedEntry],
            in: workout
        )

        XCTAssertEqual(block.kind, .triset)
        XCTAssertEqual(block.name, "Bodyweight triset")
        XCTAssertEqual(block.targetRounds, 3)
        XCTAssertEqual(
            WorkoutExecutionBlockService.entries(in: block, workout: workout).map(\.nameSnapshot),
            ["Pull-Up", "Push-Up", "Squat"]
        )
    }

    func testPlanCopiesTemplateExecutionBlockWithFreshMembershipIdentity() throws {
        let clean = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let jerk = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let first = TemplateExercise(exercise: clean, order: 0)
        let second = TemplateExercise(exercise: jerk, order: 1)
        let template = WorkoutTemplate(name: "Complex", exercises: [clean, jerk], templateExercises: [first, second])
        let block = TemplateExerciseBlock(orderIndex: 0, kind: .olympicComplex, targetRounds: 3, isSharedLoad: true)
        template.executionBlocks = [block]
        first.executionBlockID = block.id
        first.executionBlockComponentOrder = 0
        second.executionBlockID = block.id
        second.executionBlockComponentOrder = 1

        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Olympic",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedBlock = try XCTUnwrap(plannedWorkout.orderedExecutionBlocks.first)

        XCTAssertNotEqual(plannedBlock.id, block.id)
        XCTAssertEqual(plannedBlock.sourceTemplateBlockID, block.id)
        XCTAssertEqual(plannedWorkout.orderedPlannedExercises.map(\.executionBlockID), [plannedBlock.id, plannedBlock.id])
        XCTAssertEqual(plannedWorkout.orderedPlannedExercises.map(\.executionBlockComponentOrder), [0, 1])
    }

    func testTemplateBlockAuthoringPreservesSharedLoadRestAndLadderPrescription() throws {
        let clean = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let jerk = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let cleanTemplate = TemplateExercise(exercise: clean, order: 0)
        let jerkTemplate = TemplateExercise(exercise: jerk, order: 1)
        let template = WorkoutTemplate(
            name: "Complex",
            exercises: [clean, jerk],
            templateExercises: [cleanTemplate, jerkTemplate]
        )

        try TemplateExecutionBlockService.create(
            kind: .olympicComplex,
            exercises: [cleanTemplate, jerkTemplate],
            in: template,
            name: "Clean + jerk",
            targetRounds: 4,
            isSharedLoad: true,
            restSeconds: 120,
            clockMode: .none,
            prescribedDurationSeconds: nil,
            timeCapSeconds: nil,
            intervalSeconds: nil,
            scoreKind: .completedWork,
            repetitionScheme: .fixed,
            repetitionStart: nil,
            repetitionEnd: nil,
            repetitionStep: nil
        )

        let block = try XCTUnwrap(template.orderedExecutionBlocks.first)
        XCTAssertEqual(block.name, "Clean + jerk")
        XCTAssertTrue(block.isSharedLoad)
        XCTAssertEqual(block.restSeconds, 120)
        XCTAssertEqual(cleanTemplate.executionBlockID, block.id)
        XCTAssertEqual(jerkTemplate.executionBlockComponentOrder, 1)

        try TemplateExecutionBlockService.update(
            block,
            configuration: TemplateExecutionBlockConfiguration(
                kind: .straight,
                name: "Clean technique",
                targetRounds: nil,
                isSharedLoad: false,
                restSeconds: 60,
                clockMode: .none,
                prescribedDurationSeconds: nil,
                timeCapSeconds: nil,
                intervalSeconds: nil,
                scoreKind: .none,
                repetitionScheme: .fixed,
                repetitionStart: nil,
                repetitionEnd: nil,
                repetitionStep: nil
            ),
            exercises: [cleanTemplate],
            in: template
        )

        XCTAssertEqual(template.orderedExecutionBlocks.first?.id, block.id)
        XCTAssertEqual(block.kind, .straight)
        XCTAssertEqual(block.name, "Clean technique")
        XCTAssertEqual(cleanTemplate.executionBlockID, block.id)
        XCTAssertNil(jerkTemplate.executionBlockID)
    }

    func testClockAutomaticallyCapsAndCountdownCompletes() throws {
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let amrap = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .amrap,
            clockMode: .countUp,
            timeCapSeconds: 60,
            scoreKind: .roundsAndRepetitions
        )
        amrap.start(at: startedAt)
        XCTAssertTrue(WorkoutExecutionBlockService.enforceClock(amrap, at: startedAt.addingTimeInterval(60)))
        XCTAssertEqual(amrap.status, .capped)

        let interval = WorkoutExecutionBlock(
            orderIndex: 1,
            kind: .interval,
            clockMode: .countdown,
            prescribedDurationSeconds: 30,
            scoreKind: .completedWork
        )
        interval.start(at: startedAt)
        XCTAssertTrue(WorkoutExecutionBlockService.enforceClock(interval, at: startedAt.addingTimeInterval(30)))
        XCTAssertEqual(interval.status, .completed)

        let emom = WorkoutExecutionBlock(
            orderIndex: 2,
            kind: .emom,
            clockMode: .repeatingInterval,
            timeCapSeconds: 600,
            intervalSeconds: 60,
            scoreKind: .completedWork
        )
        emom.start(at: startedAt)
        XCTAssertEqual(emom.currentInterval(at: startedAt.addingTimeInterval(121)), 3)

        let untimedCircuit = WorkoutExecutionBlock(orderIndex: 3, kind: .circuit)
        WorkoutExecutionBlockService.start(untimedCircuit, at: startedAt)
        WorkoutExecutionBlockService.stop(untimedCircuit, at: startedAt.addingTimeInterval(20))
        XCTAssertEqual(untimedCircuit.status, .stopped)
        XCTAssertEqual(untimedCircuit.accumulatedElapsedDuration, 20)
    }

    func testFormatValidatorRejectsIncompatibleClocksAndLadderDirections() {
        XCTAssertNotNil(ExecutionBlockConfigurationValidator.message(
            kind: .emom,
            clockMode: .countUp,
            prescribedDurationSeconds: nil,
            timeCapSeconds: 600,
            intervalSeconds: nil,
            repetitionScheme: .fixed,
            repetitionStart: nil,
            repetitionEnd: nil,
            repetitionStep: nil
        ))
        XCTAssertNotNil(ExecutionBlockConfigurationValidator.message(
            kind: .ladder,
            clockMode: .none,
            prescribedDurationSeconds: nil,
            timeCapSeconds: nil,
            intervalSeconds: nil,
            repetitionScheme: .ascendingLadder,
            repetitionStart: 10,
            repetitionEnd: 2,
            repetitionStep: 2
        ))
        XCTAssertNil(ExecutionBlockConfigurationValidator.message(
            kind: .ladder,
            clockMode: .none,
            prescribedDurationSeconds: nil,
            timeCapSeconds: nil,
            intervalSeconds: nil,
            repetitionScheme: .descendingLadder,
            repetitionStart: 10,
            repetitionEnd: 2,
            repetitionStep: 2
        ))
    }

    func testEveryRequestedBlockFormatHasAValidConfiguration() throws {
        func configurationMessage(
            kind: ExerciseBlockKind,
            clock: BlockClockMode = .none,
            duration: Int? = nil,
            cap: Int? = nil,
            interval: Int? = nil,
            scheme: BlockRepetitionScheme = .fixed,
            start: Int? = nil,
            end: Int? = nil,
            step: Int? = nil
        ) -> String? {
            ExecutionBlockConfigurationValidator.message(
                kind: kind,
                clockMode: clock,
                prescribedDurationSeconds: duration,
                timeCapSeconds: cap,
                intervalSeconds: interval,
                repetitionScheme: scheme,
                repetitionStart: start,
                repetitionEnd: end,
                repetitionStep: step
            )
        }

        // The timing and repetition formats each have a valid, typed
        // configuration rather than falling through to a generic WOD mode.
        XCTAssertNil(configurationMessage(kind: .amrap, clock: .countUp, cap: 600))
        XCTAssertNil(configurationMessage(kind: .emom, clock: .repeatingInterval, cap: 600, interval: 60))
        XCTAssertNil(configurationMessage(kind: .forTime, clock: .countUp))
        XCTAssertNil(configurationMessage(kind: .ladder, clock: .countUp, scheme: .ascendingLadder, start: 2, end: 10, step: 2))
        XCTAssertNil(configurationMessage(kind: .chipper, clock: .countUp, scheme: .chipper))
        XCTAssertNil(configurationMessage(kind: .interval, clock: .repeatingInterval, cap: 480, interval: 30))

        // Component formats retain their explicit cardinality rules.
        let exercise = Exercise(name: "Format exercise", primaryMuscles: [.quadriceps])
        let expectedCounts: [(ExerciseBlockKind, Int)] = [
            (.pairedSet, 2),
            (.triset, 3),
            (.giantSet, 4),
            (.circuit, 4),
            (.olympicComplex, 2)
        ]
        for (kind, count) in expectedCounts {
            let workout = Workout(name: kind.title)
            let entries = (0..<count).map { index in
                ExerciseEntry(exercise: exercise, orderIndex: index, usedMetric: .metric)
            }
            workout.exercises = entries
            XCTAssertNoThrow(try WorkoutExecutionBlockService.create(kind: kind, entries: entries, in: workout))
        }
    }

    func testSavingPartialWorkoutPreservesBlockMembershipAndFinalizesBlockStatus() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let first = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let second = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let firstEntry = ExerciseEntry(exercise: first, usedMetric: .metric)
        firstEntry.sets = [ExerciseSet(repetitions: 3, weight: 60, done: true, usedMetric: .metric)]
        let secondEntry = ExerciseEntry(exercise: second, usedMetric: .metric)
        secondEntry.sets = [ExerciseSet(repetitions: 3, weight: 60, done: false, usedMetric: .metric)]
        let workout = Workout(name: "Partial complex")
        workout.exercises = [firstEntry, secondEntry]
        let block = try WorkoutExecutionBlockService.create(
            kind: .olympicComplex,
            entries: [firstEntry, secondEntry],
            in: workout,
            targetRounds: 3
        )
        WorkoutExecutionBlockService.start(block, at: Date(timeIntervalSince1970: 1_000))
        context.insert(first)
        context.insert(second)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        XCTAssertTrue(viewModel.saveWorkout(using: context))

        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(block.status, .partial)
        XCTAssertEqual(workout.orderedExercises.count, 2)
        XCTAssertTrue(secondEntry.sets.isEmpty)
        XCTAssertEqual(secondEntry.executionBlockID, block.id)
    }

    // `ExerciseSet`'s segments/complexComponents/velocity/specializedMetric
    // fields are individually round-tripped in
    // `BackupFieldCoverageTests`; `WorkoutExecutionBlock` (kind, clockMode,
    // scoreKind, repetitionScheme/start/end/step, status, completedRounds,
    // additionalRepetitions, and its `executionBlockID` link to an entry)
    // is not covered there, so this stays as the one place proving an
    // execution block — combined with the segmented/specialized evidence a
    // set inside it can carry — survives a full backup round trip.
    func testBackupRoundTripsExecutionBlockAndSegmentedVelocityEvidence() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Dumbbell Curl", primaryMuscles: [.upperChest])
        let set = ExerciseSet(
            repetitions: 18,
            weight: 30,
            done: true,
            meanVelocity: 0.5,
            peakVelocity: 0.72,
            velocityMeasurementSource: .manual,
            specializedMetricKind: .kettlebellCadence,
            kettlebellCadenceRPM: 24,
            specializedMetricMeasurementSource: .device,
            setMethod: .dropSet,
            usedMetric: .metric
        )
        set.segments = [
            ExerciseSetSegment(orderIndex: 0, repetitions: 10, weight: 30, done: true),
            ExerciseSetSegment(orderIndex: 1, repetitions: 8, weight: 20, restAfterSeconds: 0, done: true)
        ]
        set.complexComponents = [
            ComplexComponentResult(orderIndex: 0, exerciseID: UUID(), exerciseNameSnapshot: "Power Jerk", prescribedRepetitions: 1, performedRepetitions: 1, outcome: .completed, liftQuality: .acceptable),
            ComplexComponentResult(orderIndex: 1, exerciseID: UUID(), exerciseNameSnapshot: "Jerk", prescribedRepetitions: 1, performedRepetitions: 0, outcome: .missed, liftQuality: .missed)
        ]
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Dropset")
        workout.exercises = [entry]
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .ladder,
            clockMode: .countUp,
            scoreKind: .roundsAndRepetitions,
            repetitionScheme: .ascendingLadder,
            repetitionStart: 2,
            repetitionEnd: 10,
            repetitionStep: 2
        )
        block.status = .completed
        block.completedRounds = 3
        block.additionalRepetitions = 8
        workout.executionBlocks = [block]
        entry.executionBlockID = block.id
        entry.executionBlockComponentOrder = 0
        source.insert(exercise)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(from: source, restTimer: 90, darkMode: false, unitSystem: .metric)
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        let backupWorkout = try XCTUnwrap(backup.workouts.first)
        let backupBlock = try XCTUnwrap(backupWorkout.executionBlocks?.first)
        XCTAssertEqual(backupBlock.kind, ExerciseBlockKind.ladder.rawValue)
        XCTAssertEqual(backupBlock.repetitionScheme, BlockRepetitionScheme.ascendingLadder.rawValue)
        XCTAssertEqual(backupBlock.repetitionStart, 2)
        XCTAssertEqual(backupBlock.repetitionEnd, 10)
        XCTAssertEqual(backupBlock.repetitionStep, 2)
        XCTAssertEqual(backupWorkout.exercises.first?.executionBlockID, backupBlock.id)
        XCTAssertNil(ExecutionBlockConfigurationValidator.message(
            kind: .ladder,
            clockMode: .countUp,
            prescribedDurationSeconds: backupBlock.prescribedDurationSeconds,
            timeCapSeconds: backupBlock.timeCapSeconds,
            intervalSeconds: backupBlock.intervalSeconds,
            repetitionScheme: .ascendingLadder,
            repetitionStart: backupBlock.repetitionStart,
            repetitionEnd: backupBlock.repetitionEnd,
            repetitionStep: backupBlock.repetitionStep
        ))
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let restoredWorkout = try XCTUnwrap(restored.fetch(FetchDescriptor<Workout>()).first)
        let restoredSet = try XCTUnwrap(restoredWorkout.orderedExercises.first?.orderedSets.first)
        XCTAssertEqual(restoredSet.resolvedSetMethod, .dropSet)
        XCTAssertEqual(restoredSet.peakVelocity, 0.72)
        XCTAssertEqual(restoredSet.velocityMeasurementSource, .manual)
        XCTAssertEqual(restoredSet.resolvedSpecializedMetricKind, .kettlebellCadence)
        XCTAssertEqual(restoredSet.kettlebellCadenceRPM, 24)
        XCTAssertEqual(restoredSet.specializedMetricMeasurementSource, .device)
        XCTAssertEqual(restoredSet.orderedSegments.map(\.weight), [30, 20])
        XCTAssertEqual(restoredSet.orderedComplexComponents.map(\.exerciseNameSnapshot), ["Power Jerk", "Jerk"])
        XCTAssertEqual(restoredSet.orderedComplexComponents.map(\.outcome), [.completed, .missed])
        XCTAssertEqual(restoredWorkout.orderedExecutionBlocks.first?.kind, .ladder)
        XCTAssertEqual(restoredWorkout.orderedExecutionBlocks.first?.repetitionScheme, .ascendingLadder)
        XCTAssertEqual(restoredWorkout.orderedExecutionBlocks.first?.repetitionStart, 2)
        XCTAssertEqual(restoredWorkout.orderedExecutionBlocks.first?.repetitionEnd, 10)
        XCTAssertEqual(restoredWorkout.orderedExecutionBlocks.first?.completedRounds, 3)
        XCTAssertEqual(restoredWorkout.orderedExecutionBlocks.first?.additionalRepetitions, 8)
    }
}

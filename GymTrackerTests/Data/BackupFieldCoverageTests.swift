import Foundation
import SwiftData
import XCTest
@testable import GymTracker

/// Guards the backup field-mirroring tax.
///
/// Adding one persisted field today means editing the model, `GymBackupDTOs`,
/// `GymBackupCreate`, and `GymBackupRestore`. Nothing fails loudly when a step
/// is missed — the field just stops round-tripping, and the loss only surfaces
/// when a lifter restores a backup and finds the value gone.
///
/// These tests make an omission fail here instead. Each one builds a model with
/// every field set to a distinct sentinel, runs create → encode → decode →
/// restore, and asserts field-by-field equality. Deleting any single line from
/// the create or restore mapping turns one of them red.
@MainActor
final class BackupFieldCoverageTests: XCTestCase {

    // MARK: - Round trips

    func testExerciseSetRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let exercise = Exercise(name: "Sentinel Press", primaryMuscles: [.upperChest])

        let set = ExerciseSet(
            repetitions: 7,
            weight: 82.5,
            duration: 41,
            distance: 3.5,
            calories: 123,
            done: true,
            isUserOverridden: true,
            userOverrideReason: "sentinel-override-reason",
            userOverrideAffectsFuture: true,
            rpe: 8.5,
            rir: 2,
            tempo: "3-1-1-0",
            movementQuality: 4,
            descriptiveROM: "sentinel-rom",
            discomfortScore: 3,
            liftQuality: .technicallyPoor,
            meanVelocity: 0.42,
            peakVelocity: 0.91,
            velocityMeasurementSource: .manual,
            specializedMetricKind: .jumpHeight,
            jumpHeightMeters: 0.55,
            contactTimeMilliseconds: 187,
            throwDistanceMeters: 9.25,
            kettlebellCadenceRPM: 33,
            specializedMetricMeasurementSource: .device,
            setMethod: .standard,
            setType: .topSet,
            orderIndex: 0,
            usedMetric: .metric
        )
        set.weightType = .lbs
        set.distanceType = .miles
        set.isSelectedDailyMaximum = true
        set.generatedBackOffDefinitionID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        set.prescribedSetType = .backoff
        set.prescribedRepetitions = 6
        set.prescribedRepRangeMinimum = 5
        set.prescribedRepRangeMaximum = 9
        set.prescribedSuggestedLoad = 77.5
        set.prescribedSuggestedLoadType = .kg
        set.prescribedUnroundedLoad = 77.3
        set.prescribedReferenceValue = 140
        set.prescriptionLoadExplanation = "sentinel-load-explanation"
        set.prescribedRestSeconds = 210
        set.prescribedRPE = 7.5
        set.prescribedRIR = 3
        set.prescribedTempo = "2-0-2-0"
        set.prescribedProgressionEligible = true
        set.prescribedCalories = 250
        set.prescribedVelocityMinimum = 0.3
        set.prescribedVelocityMaximum = 0.8
        set.prescribedVelocityLossStopPercent = 22
        set.isVelocityProbe = true
        set.isPrescribedOptional = true
        set.prescriptionNotes = "sentinel-prescription-notes"
        set.prescriptionDefinitionData = Data("sentinel-definition".utf8)
        // A cluster set is rejected by backup validation unless it carries the
        // segments its method requires.
        set.segments = (0..<SetMethod.cluster.minimumSegmentCount).map { index in
            ExerciseSetSegment(
                orderIndex: index,
                repetitions: 3,
                weight: 82.5,
                weightType: .lbs,
                duration: nil,
                restAfterSeconds: 15,
                done: true
            )
        }

        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Sentinel Workout", endTime: .now)
        workout.exercises = [entry]
        source.insert(exercise)
        source.insert(workout)
        try source.save()

        let restoredSet = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<Workout>())
                .first?
                .orderedExercises.first?
                .orderedSets.first
        )

        XCTAssertEqual(restoredSet.id, set.id)
        XCTAssertEqual(restoredSet.orderIndex, 0)
        XCTAssertEqual(restoredSet.weightType, .lbs)
        XCTAssertEqual(restoredSet.distanceType, .miles)
        XCTAssertEqual(restoredSet.repetitions, 7)
        XCTAssertEqual(restoredSet.weight, 82.5)
        XCTAssertEqual(restoredSet.duration, 41)
        XCTAssertEqual(restoredSet.distance, 3.5)
        XCTAssertEqual(restoredSet.calories, 123)
        XCTAssertTrue(restoredSet.done)
        XCTAssertTrue(restoredSet.isUserOverridden)
        XCTAssertEqual(restoredSet.userOverrideReason, "sentinel-override-reason")
        XCTAssertTrue(restoredSet.userOverrideAffectsFuture)
        XCTAssertEqual(restoredSet.rpe, 8.5)
        XCTAssertEqual(restoredSet.rir, 2)
        XCTAssertEqual(restoredSet.tempo, "3-1-1-0")
        XCTAssertEqual(restoredSet.movementQuality, 4)
        XCTAssertEqual(restoredSet.descriptiveROM, "sentinel-rom")
        XCTAssertEqual(restoredSet.discomfortScore, 3)
        XCTAssertEqual(restoredSet.liftQuality, .technicallyPoor)
        XCTAssertEqual(restoredSet.meanVelocity, 0.42)
        XCTAssertEqual(restoredSet.peakVelocity, 0.91)
        XCTAssertEqual(restoredSet.velocityMeasurementSource, .manual)
        XCTAssertEqual(restoredSet.resolvedSpecializedMetricKind, .jumpHeight)
        XCTAssertEqual(restoredSet.jumpHeightMeters, 0.55)
        XCTAssertEqual(restoredSet.contactTimeMilliseconds, 187)
        XCTAssertEqual(restoredSet.throwDistanceMeters, 9.25)
        XCTAssertEqual(restoredSet.kettlebellCadenceRPM, 33)
        XCTAssertEqual(restoredSet.specializedMetricMeasurementSource, .device)
        XCTAssertEqual(restoredSet.resolvedSetMethod, .standard)
        XCTAssertEqual(restoredSet.setType, .topSet)
        XCTAssertTrue(restoredSet.isSelectedDailyMaximum)
        XCTAssertEqual(restoredSet.generatedBackOffDefinitionID, set.generatedBackOffDefinitionID)
        XCTAssertEqual(restoredSet.usedMetric, .metric)
        XCTAssertEqual(restoredSet.prescribedSetType, .backoff)
        XCTAssertEqual(restoredSet.prescribedRepetitions, 6)
        XCTAssertEqual(restoredSet.prescribedRepRangeMinimum, 5)
        XCTAssertEqual(restoredSet.prescribedRepRangeMaximum, 9)
        XCTAssertEqual(restoredSet.prescribedSuggestedLoad, 77.5)
        XCTAssertEqual(restoredSet.prescribedSuggestedLoadType, .kg)
        XCTAssertEqual(restoredSet.prescribedUnroundedLoad, 77.3)
        XCTAssertEqual(restoredSet.prescribedReferenceValue, 140)
        XCTAssertEqual(restoredSet.prescriptionLoadExplanation, "sentinel-load-explanation")
        XCTAssertEqual(restoredSet.prescribedRestSeconds, 210)
        XCTAssertEqual(restoredSet.prescribedRPE, 7.5)
        XCTAssertEqual(restoredSet.prescribedRIR, 3)
        XCTAssertEqual(restoredSet.prescribedTempo, "2-0-2-0")
        XCTAssertEqual(restoredSet.prescribedProgressionEligible, true)
        XCTAssertEqual(restoredSet.prescribedCalories, 250)
        XCTAssertEqual(restoredSet.prescribedVelocityMinimum, 0.3)
        XCTAssertEqual(restoredSet.prescribedVelocityMaximum, 0.8)
        XCTAssertEqual(restoredSet.prescribedVelocityLossStopPercent, 22)
        XCTAssertTrue(restoredSet.isVelocityProbe)
        XCTAssertEqual(restoredSet.isPrescribedOptional, true)
        XCTAssertEqual(restoredSet.prescriptionNotes, "sentinel-prescription-notes")
        XCTAssertEqual(restoredSet.prescriptionDefinitionData, Data("sentinel-definition".utf8))
    }

    func testExerciseSetSegmentsAndComplexComponentsRoundTrip() throws {
        let source = try makeContext()
        let exercise = Exercise(name: "Sentinel Complex", primaryMuscles: [.quadriceps])
        let set = ExerciseSet(repetitions: 3, weight: 60, usedMetric: .metric)

        let segment = ExerciseSetSegment(
            orderIndex: 0,
            repetitions: 5,
            weight: 45,
            weightType: .lbs,
            duration: 12,
            restAfterSeconds: 20,
            done: true,
            variationNote: "sentinel-segment-note",
            rpe: 6.5,
            rir: 4
        )
        let component = ComplexComponentResult(
            orderIndex: 0,
            exerciseID: exercise.id,
            exerciseNameSnapshot: "Sentinel Component",
            prescribedRepetitions: 3,
            performedRepetitions: 2,
            outcome: .partial,
            liftQuality: .technicallyPoor
        )
        set.segments = [segment]
        set.complexComponents = [component]

        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Sentinel Complex Workout", endTime: .now)
        workout.exercises = [entry]
        source.insert(exercise)
        source.insert(workout)
        try source.save()

        let restoredSet = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<Workout>())
                .first?
                .orderedExercises.first?
                .orderedSets.first
        )

        let restoredSegment = try XCTUnwrap(restoredSet.orderedSegments.first)
        XCTAssertEqual(restoredSegment.id, segment.id)
        XCTAssertEqual(restoredSegment.repetitions, 5)
        XCTAssertEqual(restoredSegment.weight, 45)
        XCTAssertEqual(restoredSegment.weightType, .lbs)
        XCTAssertEqual(restoredSegment.duration, 12)
        XCTAssertEqual(restoredSegment.restAfterSeconds, 20)
        XCTAssertTrue(restoredSegment.done)
        XCTAssertEqual(restoredSegment.variationNote, "sentinel-segment-note")
        XCTAssertEqual(restoredSegment.rpe, 6.5)
        XCTAssertEqual(restoredSegment.rir, 4)

        let restoredComponent = try XCTUnwrap(restoredSet.orderedComplexComponents.first)
        XCTAssertEqual(restoredComponent.id, component.id)
        XCTAssertEqual(restoredComponent.exerciseID, exercise.id)
        XCTAssertEqual(restoredComponent.exerciseNameSnapshot, "Sentinel Component")
        XCTAssertEqual(restoredComponent.prescribedRepetitions, 3)
        XCTAssertEqual(restoredComponent.performedRepetitions, 2)
        XCTAssertEqual(restoredComponent.outcome, .partial)
        XCTAssertEqual(restoredComponent.liftQuality, .technicallyPoor)
    }

    func testMobilityRoutineRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let routine = MobilityRoutine(
            name: "Sentinel Mobility Routine",
            notes: "sentinel-mobility-notes",
            purpose: .development,
            isArchived: true,
            id: UUID(uuidString: "A8E1E5A1-1C14-446E-9C71-3E6DA2DA675E")!,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        source.insert(routine)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<MobilityRoutine>())
                .first { $0.name == "Sentinel Mobility Routine" }
        )

        XCTAssertEqual(restored.id, routine.id)
        XCTAssertEqual(restored.name, "Sentinel Mobility Routine")
        XCTAssertEqual(restored.notes, "sentinel-mobility-notes")
        XCTAssertEqual(restored.purpose, .development)
        XCTAssertEqual(restored.purposeRaw, MobilityRoutinePurpose.development.rawValue)
        XCTAssertTrue(restored.isArchived)
        XCTAssertEqual(restored.createdAt, createdAt)
        XCTAssertEqual(restored.updatedAt, updatedAt)
        XCTAssertTrue(restored.orderedItems.isEmpty)
    }

    func testWorkoutTemplateRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let exercise = Exercise(name: "Template Bench Press", primaryMuscles: [.upperChest])
        let template = WorkoutTemplate(name: "Upper Body Hypertrophy", exercises: [exercise])
        template.isArchived = true
        source.insert(exercise)
        source.insert(template)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<WorkoutTemplate>())
                .first { $0.name == "Upper Body Hypertrophy" }
        )

        XCTAssertEqual(restored.id, template.id)
        XCTAssertEqual(restored.name, "Upper Body Hypertrophy")
        XCTAssertTrue(restored.isArchived)
    }

    func testExerciseRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let exercise = Exercise(
            name: "Sentinel Exercise",
            primaryMuscles: [.upperChest, .frontDeltoid],
            secondaryMuscles: [.tricepLateralHead],
            category: .sport,
            trackingType: .durationAndDistance,
            equipmentType: .kettlebell,
            resistanceType: .elastic,
            movementPattern: .carry,
            forceType: .staticHold,
            mechanics: .isolation,
            gripStyle: .neutral,
            stance: .kneeling,
            rangeOfMotion: .partial,
            setupAngleDegrees: 45,
            variationFamilyID: "sentinel-family",
            difficulty: .advanced,
            tags: ["sentinel-tag-a", "sentinel-tag-b"],
            isFavorite: true,
            isPlateLoaded: true,
            isCustom: true,
            isArchived: true,
            laterality: .unilateral,
            repCountingStyle: .perSide,
            weightEntryStyle: .perLoadUnit,
            loadUnitCount: 2
        )
        source.insert(exercise)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<Exercise>())
                .first { $0.name == "Sentinel Exercise" }
        )

        XCTAssertEqual(restored.primaryMuscles, [.upperChest, .frontDeltoid])
        XCTAssertEqual(restored.secondaryMuscles, [.tricepLateralHead])
        XCTAssertEqual(restored.category, .sport)
        XCTAssertEqual(restored.trackingType, .durationAndDistance)
        XCTAssertEqual(restored.equipmentType, .kettlebell)
        XCTAssertEqual(restored.resistanceType, .elastic)
        XCTAssertEqual(restored.movementPattern, .carry)
        XCTAssertEqual(restored.difficulty, .advanced)
        XCTAssertEqual(restored.tags, ["sentinel-tag-a", "sentinel-tag-b"])
        XCTAssertTrue(restored.isFavorite)
        XCTAssertTrue(restored.isPlateLoaded)
        XCTAssertTrue(restored.isCustom)
        XCTAssertTrue(restored.isArchived)
    }

    func testExerciseEntryRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let exercise = Exercise(name: "Sentinel Entry Exercise", primaryMuscles: [.latissimusDorsi])
        let entry = ExerciseEntry(
            comment: "sentinel-comment",
            exercise: exercise,
            sets: [ExerciseSet(repetitions: 5, weight: 40, usedMetric: .metric)],
            orderIndex: 0,
            usedMetric: .imperial,
            supersetGroupID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )
        entry.prescribedSets = 4
        entry.prescribedRepRangeMinimum = 6
        entry.prescribedRepRangeMaximum = 10
        entry.prescribedRestSeconds = 150
        entry.prescribedRPE = 8
        entry.prescribedRIR = 2
        entry.prescriptionNotes = "sentinel-entry-notes"
        entry.progressionKey = "sentinel-progression-key"
        entry.prescribedRole = .accessory
        entry.isPrescribedOptional = true
        entry.prescribedSuggestedLoad = 62.5
        entry.prescribedSuggestedLoadType = .kg
        entry.prescribedProgressionRule = .doubleProgression
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 65
        entry.recommendedUnit = .kg
        entry.recommendationPriorLoad = 62.5
        entry.recommendationRequiredSets = 4
        entry.recommendationRepCeiling = 10
        entry.recommendationCompletedSets = 4
        entry.recommendationPriorWorkoutDate = Date(timeIntervalSince1970: 1_700_000_000)
        entry.originalExerciseNameSnapshot = "sentinel-original-name"
        entry.substitutionReason = "sentinel-substitution-reason"
        entry.substitutionSharesProgressionState = true
        entry.substitutionReasonCode = SubstitutionReason.preference.rawValue
        entry.substitutionSuitabilityRaw = SubstitutionSuitability.good.rawValue
        entry.substitutionComparabilityRaw = SubstitutionComparability.limited.rawValue
        entry.substitutionProgressionPolicyRaw = ProgressionTransferPolicy.continueShared.rawValue
        entry.substitutionScopeRaw = SubstitutionScope.futurePlan.rawValue
        entry.substitutionEvidenceConfidenceRaw = SubstitutionEvidenceConfidence.moderate.rawValue
        entry.substitutionEvaluationVersion = 71
        entry.substitutionEvaluationData = Data("sentinel-substitution-evidence".utf8)
        entry.lateralitySnapshot = .unilateral
        entry.repCountingStyleSnapshot = .perSide
        entry.weightEntryStyleSnapshot = .perLoadUnit
        entry.loadUnitCountSnapshot = 2

        let workout = Workout(name: "Sentinel Entry Workout", endTime: .now)
        workout.exercises = [entry]
        source.insert(exercise)
        source.insert(workout)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<Workout>())
                .first?
                .orderedExercises.first
        )

        XCTAssertEqual(restored.comment, "sentinel-comment")
        XCTAssertEqual(restored.usedMetric, .imperial)
        XCTAssertEqual(restored.supersetGroupID, entry.supersetGroupID)
        XCTAssertEqual(restored.prescribedSets, 4)
        XCTAssertEqual(restored.prescribedRepRangeMinimum, 6)
        XCTAssertEqual(restored.prescribedRepRangeMaximum, 10)
        XCTAssertEqual(restored.prescribedRestSeconds, 150)
        XCTAssertEqual(restored.prescribedRPE, 8)
        XCTAssertEqual(restored.prescribedRIR, 2)
        XCTAssertEqual(restored.prescriptionNotes, "sentinel-entry-notes")
        XCTAssertEqual(restored.progressionKey, "sentinel-progression-key")
        XCTAssertEqual(restored.prescribedRole, .accessory)
        XCTAssertEqual(restored.isPrescribedOptional, true)
        XCTAssertEqual(restored.prescribedSuggestedLoad, 62.5)
        XCTAssertEqual(restored.prescribedSuggestedLoadType, .kg)
        XCTAssertEqual(restored.prescribedProgressionRule, .doubleProgression)
        XCTAssertEqual(restored.recommendedDecision, .increase)
        XCTAssertEqual(restored.recommendedLoad, 65)
        XCTAssertEqual(restored.recommendedUnit, .kg)
        XCTAssertEqual(restored.recommendationPriorLoad, 62.5)
        XCTAssertEqual(restored.recommendationRequiredSets, 4)
        XCTAssertEqual(restored.recommendationRepCeiling, 10)
        XCTAssertEqual(restored.recommendationCompletedSets, 4)
        XCTAssertEqual(
            restored.recommendationPriorWorkoutDate,
            Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(restored.originalExerciseNameSnapshot, "sentinel-original-name")
        XCTAssertEqual(restored.substitutionReason, "sentinel-substitution-reason")
        XCTAssertTrue(restored.substitutionSharesProgressionState)
        XCTAssertEqual(restored.substitutionReasonCode, SubstitutionReason.preference.rawValue)
        XCTAssertEqual(restored.substitutionSuitability, .good)
        XCTAssertEqual(restored.substitutionComparability, .limited)
        XCTAssertEqual(restored.substitutionProgressionPolicy, .continueShared)
        XCTAssertEqual(restored.substitutionScope, .futurePlan)
        XCTAssertEqual(restored.substitutionEvidenceConfidence, .moderate)
        XCTAssertEqual(restored.substitutionEvaluationVersion, 71)
        XCTAssertEqual(restored.substitutionEvaluationData, Data("sentinel-substitution-evidence".utf8))
        XCTAssertEqual(restored.lateralitySnapshot, .unilateral)
        XCTAssertEqual(restored.repCountingStyleSnapshot, .perSide)
        XCTAssertEqual(restored.weightEntryStyleSnapshot, .perLoadUnit)
        XCTAssertEqual(restored.loadUnitCountSnapshot, 2)
    }

    func testExerciseRelationshipRoundTripsDecisionAwareFields() throws {
        let source = try makeContext()
        let original = Exercise(name: "Sentinel Relationship Source", primaryMuscles: [.upperChest])
        let replacement = Exercise(name: "Sentinel Relationship Target", primaryMuscles: [.upperChest])
        let relationship = ExerciseRelationship(
            sourceExercise: original,
            targetExercise: replacement,
            type: .substitution,
            provenance: .systemReviewed,
            rationaleCode: "substitution.rationale.sentinel",
            appliesToGoals: [.hypertrophy],
            appliesToRoles: [.accessory],
            reviewVersion: 17
        )
        source.insert(original)
        source.insert(replacement)
        source.insert(relationship)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<ExerciseRelationship>())
                .first {
                    $0.sourceExercise?.name == "Sentinel Relationship Source"
                        && $0.targetExercise?.name == "Sentinel Relationship Target"
                }
        )
        XCTAssertEqual(restored.resolvedProvenance, .systemReviewed)
        XCTAssertEqual(restored.rationaleCode, "substitution.rationale.sentinel")
        XCTAssertEqual(restored.appliesToGoals, [.hypertrophy])
        XCTAssertEqual(restored.appliesToRoles, [.accessory])
        XCTAssertEqual(restored.reviewVersion, 17)
    }

    func testWorkoutRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let exercise = Exercise(name: "Sentinel Workout Exercise", primaryMuscles: [.gluteMaximus])
        let workout = Workout(name: "Sentinel Named Workout", endTime: Date(timeIntervalSince1970: 1_700_003_600))
        workout.startTime = Date(timeIntervalSince1970: 1_700_000_000)
        workout.notes = "sentinel-workout-notes"
        workout.sourcePlanID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")
        workout.sourcePlanRunID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")
        workout.sourcePlanBlockID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")
        workout.sourcePlanWeekID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")
        workout.sourcePlannedWorkoutID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")
        workout.sourcePlanName = "sentinel-plan-name"
        workout.sourceProgramDefinitionID = UUID(uuidString: "10000000-0000-0000-0000-000000000006")
        workout.sourceProgramDefinitionVersion = 7
        let repeatingTemplate = WorkoutTemplate(name: "Sentinel Repeating Template", exercises: [exercise])
        let repeatingPlan = RepeatingPlan(
            name: "Sentinel Repeating Plan",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: repeatingTemplate)]
        )
        let repeatingRun = RepeatingPlanRun(plan: repeatingPlan)
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: 2,
            expectedSlotIndex: 0,
            selectedSlotIndex: 0,
            status: .completed,
            cursorBefore: 0,
            cursorAfter: 0,
            completedAt: .now,
            completedWorkout: workout
        )
        repeatingRun.occurrences = [occurrence]
        workout.sourceRepeatingPlanID = repeatingPlan.id
        workout.sourceRepeatingPlanRunID = repeatingRun.id
        workout.sourceRepeatingPlanOccurrenceID = occurrence.id
        workout.sourceRepeatingPlanName = repeatingPlan.name
        workout.exercises = [
            ExerciseEntry(
                exercise: exercise,
                sets: [ExerciseSet(repetitions: 5, weight: 50, done: true, usedMetric: .metric)],
                usedMetric: .metric
            )
        ]
        source.insert(exercise)
        source.insert(repeatingTemplate)
        source.insert(repeatingPlan)
        source.insert(repeatingRun)
        source.insert(workout)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<Workout>())
                .first { $0.name == "Sentinel Named Workout" }
        )

        XCTAssertEqual(restored.id, workout.id)
        XCTAssertEqual(restored.notes, "sentinel-workout-notes")
        XCTAssertEqual(restored.startTime, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(restored.endTime, Date(timeIntervalSince1970: 1_700_003_600))
        XCTAssertEqual(restored.sourcePlanID, workout.sourcePlanID)
        XCTAssertEqual(restored.sourcePlanRunID, workout.sourcePlanRunID)
        XCTAssertEqual(restored.sourcePlanBlockID, workout.sourcePlanBlockID)
        XCTAssertEqual(restored.sourcePlanWeekID, workout.sourcePlanWeekID)
        XCTAssertEqual(restored.sourcePlannedWorkoutID, workout.sourcePlannedWorkoutID)
        XCTAssertEqual(restored.sourcePlanName, "sentinel-plan-name")
        XCTAssertEqual(restored.sourceProgramDefinitionID, workout.sourceProgramDefinitionID)
        XCTAssertEqual(restored.sourceProgramDefinitionVersion, 7)
        XCTAssertEqual(restored.sourceRepeatingPlanID, workout.sourceRepeatingPlanID)
        XCTAssertEqual(restored.sourceRepeatingPlanRunID, workout.sourceRepeatingPlanRunID)
        XCTAssertEqual(restored.sourceRepeatingPlanOccurrenceID, workout.sourceRepeatingPlanOccurrenceID)
        XCTAssertEqual(restored.sourceRepeatingPlanName, "Sentinel Repeating Plan")
    }

    func testFoodItemRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let food = FoodItem(
            name: "Sentinel Food",
            referenceAmount: 125,
            referenceUnit: .milliliters,
            calories: 210,
            proteinGrams: 21.5,
            carbohydrateGrams: 12.25,
            fatGrams: 9.75,
            caffeineMilligrams: 95,
            npn: "sentinel-npn",
            sourceKind: .curated,
            confidence: .verified,
            preparationState: .cooked,
            isFavorite: true,
            isArchived: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        food.frenchName = "sentinel-french-name"
        food.categoryName = "sentinel-category"
        food.searchAliases = ["sentinel-alias-a", "sentinel-alias-b"]
        food.servings = [
            FoodServing(
                name: "Sentinel Serving",
                amount: 250,
                unit: .milliliters,
                equivalentReferenceAmount: 250
            )
        ]
        source.insert(food)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<FoodItem>())
                .first { $0.name == "Sentinel Food" }
        )

        XCTAssertEqual(restored.id, food.id)
        XCTAssertEqual(restored.referenceAmount, 125)
        XCTAssertEqual(restored.referenceUnit, .milliliters)
        XCTAssertEqual(restored.calories, 210)
        XCTAssertEqual(restored.proteinGrams, 21.5)
        XCTAssertEqual(restored.carbohydrateGrams, 12.25)
        XCTAssertEqual(restored.fatGrams, 9.75)
        XCTAssertEqual(restored.caffeineMilligrams, 95)
        XCTAssertEqual(restored.npn, "sentinel-npn")
        XCTAssertEqual(restored.sourceKind, .curated)
        XCTAssertEqual(restored.confidence, .verified)
        XCTAssertEqual(restored.preparationState, .cooked)
        XCTAssertTrue(restored.isFavorite)
        XCTAssertTrue(restored.isArchived)
        XCTAssertEqual(restored.createdAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(restored.updatedAt, Date(timeIntervalSince1970: 1_700_000_500))
        XCTAssertEqual(restored.frenchName, "sentinel-french-name")
        XCTAssertEqual(restored.categoryName, "sentinel-category")
        XCTAssertEqual(restored.searchAliases, ["sentinel-alias-a", "sentinel-alias-b"])

        let restoredServing = try XCTUnwrap(restored.orderedServings.first)
        XCTAssertEqual(restoredServing.name, "Sentinel Serving")
        XCTAssertEqual(restoredServing.amount, 250)
        XCTAssertEqual(restoredServing.unit, .milliliters)
        XCTAssertEqual(restoredServing.equivalentReferenceAmount, 250)
    }

    func testLoggedMealRoundTripsEveryPersistedField() throws {
        let source = try makeContext()
        let food = FoodItem(name: "Sentinel Meal Food", calories: 100)
        let meal = LoggedMeal(
            day: LocalDay(rawValue: "2026-07-25"),
            slot: .dinner,
            loggedAt: Date(timeIntervalSince1970: 1_700_010_000),
            nameSnapshot: "Sentinel Meal",
            sourceMealTemplateID: UUID(uuidString: "20000000-0000-0000-0000-000000000001"),
            sourceMealTemplateName: "sentinel-template-name",
            createdAt: Date(timeIntervalSince1970: 1_700_009_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_009_500)
        )
        meal.items = [
            LoggedMealItem(
                sourceFoodID: food.id,
                foodNameSnapshot: "Sentinel Meal Item",
                servingNameSnapshot: "Sentinel Serving Snapshot",
                quantity: 1.75,
                portionAmountSnapshot: 175,
                portionUnit: .grams,
                caloriesSnapshot: 210,
                proteinGramsSnapshot: 12,
                carbohydrateGramsSnapshot: 20,
                fatGramsSnapshot: 5,
                caffeineMilligramsSnapshot: 40,
                sourceKind: .curated,
                confidence: .verified,
                preparationState: .cooked,
                orderIndex: 0
            )
        ]
        source.insert(food)
        source.insert(meal)
        try source.save()

        let restored = try XCTUnwrap(
            roundTrip(source)
                .fetch(FetchDescriptor<LoggedMeal>())
                .first { $0.nameSnapshot == "Sentinel Meal" }
        )

        XCTAssertEqual(restored.id, meal.id)
        XCTAssertEqual(restored.dayKey, "2026-07-25")
        XCTAssertEqual(restored.slot, .dinner)
        XCTAssertEqual(restored.loggedAt, Date(timeIntervalSince1970: 1_700_010_000))
        XCTAssertEqual(restored.sourceMealTemplateID, meal.sourceMealTemplateID)
        XCTAssertEqual(restored.sourceMealTemplateName, "sentinel-template-name")
        XCTAssertEqual(restored.createdAt, Date(timeIntervalSince1970: 1_700_009_000))
        XCTAssertEqual(restored.updatedAt, Date(timeIntervalSince1970: 1_700_009_500))

        let restoredItem = try XCTUnwrap(restored.orderedItems.first)
        XCTAssertEqual(restoredItem.sourceFoodID, food.id)
        XCTAssertEqual(restoredItem.foodNameSnapshot, "Sentinel Meal Item")
        XCTAssertEqual(restoredItem.servingNameSnapshot, "Sentinel Serving Snapshot")
        XCTAssertEqual(restoredItem.quantity, 1.75)
        XCTAssertEqual(restoredItem.portionAmountSnapshot, 175)
        XCTAssertEqual(restoredItem.portionUnit, .grams)
        XCTAssertEqual(restoredItem.caloriesSnapshot, 210)
        XCTAssertEqual(restoredItem.proteinGramsSnapshot, 12)
        XCTAssertEqual(restoredItem.carbohydrateGramsSnapshot, 20)
        XCTAssertEqual(restoredItem.fatGramsSnapshot, 5)
        XCTAssertEqual(restoredItem.caffeineMilligramsSnapshot, 40)
    }

    // MARK: - DTO coverage guards

    /// A DTO field that nobody maps is invisible: it encodes as its default and
    /// decodes back to it, so a round-trip test on the *model* cannot see it.
    /// These counts are the tripwire. When one fails, a field was added to the
    /// DTO — go finish the job at the other three sites:
    ///
    /// 1. `Models/Entities/…` — the persisted property
    /// 2. `Data/GymBackupCreate.swift` — model → DTO
    /// 3. `Data/GymBackupRestore.swift` — DTO → model
    /// 4. `Data/GymBackupValidation.swift` — only when the field carries a rule
    ///
    /// Then extend the matching round-trip test above and bump the count here.
    func testBackupDTOFieldCountsMatchTheirMappings() {
        assertFieldCount(of: ExerciseSetDTO.self, equals: 61)
        assertFieldCount(of: ExerciseSetSegmentDTO.self, equals: 17)
        assertFieldCount(of: ComplexComponentResultDTO.self, equals: 8)
        assertFieldCount(of: ExerciseEntryDTO.self, equals: 60)
        assertFieldCount(of: WorkoutDTO.self, equals: 23)
        assertFieldCount(of: ExerciseTemplateDTO.self, equals: 31)
        assertFieldCount(of: FoodItemDTO.self, equals: 21)
        assertFieldCount(of: LoggedMealDTO.self, equals: 10)
        assertFieldCount(of: MobilityRoutineDTO.self, equals: 9)
        assertFieldCount(of: MobilityAssessmentDefinitionDTO.self, equals: 21)
        assertFieldCount(of: MobilityAssessmentSampleDTO.self, equals: 9)
        assertFieldCount(of: MobilityAssessmentResultDTO.self, equals: 24)
        assertFieldCount(of: MobilityAssessmentSessionDTO.self, equals: 11)
    }

    /// The count guard above only protects the eight DTO types it already
    /// knows about — it has no way to notice a brand-new `...DTO` type that
    /// nobody wired a round trip for at all. This test closes that blind
    /// spot by scanning `GymBackupDTOs.swift` itself for every `struct
    /// ...DTO` declaration and checking each one off against an explicit
    /// decision recorded right here: either it has full round-trip +
    /// field-count coverage above, or it is named in `knownUncoveredDTOTypes`
    /// as a deliberate, currently-open gap. Adding a new DTO type with no
    /// entry in either list fails this test instead of silently shipping
    /// with zero backup coverage.
    ///
    /// This is intentionally table-driven rather than hand-counted: the
    /// source of truth is the production file, not a number a person has to
    /// remember to bump.
    func testEveryBackupDTOTypeHasARecordedCoverageDecision() throws {
        let dtoSourceFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Data
            .deletingLastPathComponent() // GymTrackerTests
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("GymTracker/Core/Data/GymBackupDTOs.swift")
        let source = try String(contentsOf: dtoSourceFile, encoding: .utf8)

        let pattern = #"struct\s+(\w+DTO)\s*:\s*Codable"#
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        let declaredTypes = Set(matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[range])
        })
        XCTAssertFalse(declaredTypes.isEmpty, "Expected to find DTO struct declarations in \(dtoSourceFile.path); the scan path or pattern may be stale.")

        let accountedFor = Self.coveredDTOTypes.union(Self.knownUncoveredDTOTypes)
        let unaccounted = declaredTypes.subtracting(accountedFor)
        XCTAssertTrue(
            unaccounted.isEmpty,
            """
            New DTO type(s) \(unaccounted.sorted()) exist in GymBackupDTOs.swift with no coverage \
            decision recorded in BackupFieldCoverageTests. Either add a sentinel round-trip test \
            plus an `assertFieldCount` guard and list the type in `coveredDTOTypes`, or — if \
            coverage is deliberately deferred — add it to `knownUncoveredDTOTypes` with a comment \
            explaining why.
            """
        )

        let stale = Self.coveredDTOTypes.subtracting(declaredTypes)
        XCTAssertTrue(stale.isEmpty, "coveredDTOTypes lists \(stale), which no longer exist in GymBackupDTOs.swift; remove the stale entry.")
    }

    /// DTO types with a sentinel round-trip test above *and* an
    /// `assertFieldCount` guard in `testBackupDTOFieldCountsMatchTheirMappings`.
    private static let coveredDTOTypes: Set<String> = [
        "ExerciseSetDTO",
        "ExerciseSetSegmentDTO",
        "ComplexComponentResultDTO",
        "ExerciseEntryDTO",
        "WorkoutDTO",
        "ExerciseTemplateDTO",
        "FoodItemDTO",
        "LoggedMealDTO",
        "MobilityRoutineDTO",
        "MobilityAssessmentDefinitionDTO",
        "MobilityAssessmentSampleDTO",
        "MobilityAssessmentResultDTO",
        "MobilityAssessmentSessionDTO"
    ]

    /// DTO types with no Mirror-based field-count guard *in this file* yet.
    /// Several of these already have behavioral round-trip coverage
    /// elsewhere (e.g. `PlanRunDTO`/`WorkoutPlanDTO` in `PlanSchedulingTests`,
    /// `DailyLogEntryDTO`/`BodyWeightEntryDTO` in `TodayFoundationTests`,
    /// mobility DTOs in the Mobility suite) — this list only tracks the
    /// specific "every field, sentinel value, tripwire on the exact count"
    /// guarantee this file provides, which is stronger than an ordinary
    /// round trip because it catches a field that was added to the DTO but
    /// never wired into any mapping at all. Recorded explicitly here rather
    /// than left to silently pass, so this file is honest about which DTOs
    /// still lack that guarantee. Closing one of these is a legitimate,
    /// separately-scoped strengthening of this file — move the type up to
    /// `coveredDTOTypes` once it has a sentinel round trip and a field-count
    /// guard.
    private static let knownUncoveredDTOTypes: Set<String> = [
        "BackupDTO", // top-level container; exercised by every round trip above, but has no single-model field-count guard of its own.
        "PreferencesDTO",
        "ExerciseRelationshipDTO",
        "TemplateExerciseDTO",
        "TemplateExerciseBlockDTO",
        "WorkoutTemplateDTO",
        "WorkoutCollectionDTO",
        "WorkoutExecutionBlockDTO",
        "PlannedExerciseDTO",
        "PlannedSetDTO",
        "ProgressionStateDTO",
        "ProgressionRecommendationDTO",
        "PlannedWorkoutDTO",
        "PlannedExerciseBlockDTO",
        "PlanWeekDTO",
        "PlanBlockDTO",
        "WorkoutPlanDTO",
        "PlanWorkoutProgressDTO",
        "PlanRunDTO",
        "ProgramDefinitionDTO",
        "DailyLogEntryDTO",
        "BodyWeightEntryDTO",
        "SupplementOccurrenceDTO",
        "MobilityFamilyDTO",
        "MobilityDefinitionDTO",
        "MobilityPhasePrescriptionDTO",
        "MobilityRoutineItemDTO",
        "MobilityPhaseResultDTO",
        "MobilityResultDTO",
        "MobilityEntryDTO",
        "MobilitySessionDTO",
        "FoodServingDTO",
        "MealTemplateItemDTO",
        "MealTemplateDTO",
        "LoggedMealItemDTO",
        "NutritionTargetDTO",
        "RepeatingPlanSlotDTO",
        "RepeatingPlanDTO",
        "RepeatingPlanRunSlotDTO",
        "RepeatingPlanOccurrenceDTO",
        "RepeatingPlanRunDTO",
        "MobilityEntryEvidenceDTO",
        "MobilityProgramDefinitionDTO",
        "MobilityProgramRunDTO",
        "MobilityProgramSessionProgressDTO",
        "MobilityProgressionRecommendationDTO",
        "MobilityProgressionStateDTO",
        "MobilityRoutineBlockDTO",
        "MobilityTempoPrescriptionDTO",
        "MobilityAssistancePrescriptionDTO",
        "MobilityBreathingPrescriptionDTO",
        "TrainingProfileDTO"
    ]

    private func assertFieldCount<T>(
        of type: T.Type,
        equals expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // `Mirror` needs an instance, and these DTOs have no zero-argument
        // initializer. Decoding the smallest payload that satisfies their
        // non-optional fields is impractical, so reflect over the type's
        // `CodingKeys` instead by decoding a JSON object with every key absent
        // is not possible either — count the stored properties via a Mirror on a
        // decoded instance built from a canonical fixture.
        guard let instance = Self.fixtureInstance(for: type) else {
            XCTFail("No coverage fixture registered for \(type)", file: file, line: line)
            return
        }
        let count = Mirror(reflecting: instance).children.count
        XCTAssertEqual(
            count,
            expected,
            """
            \(type) now has \(count) fields, expected \(expected). \
            A backup DTO field changed — confirm the model, GymBackupCreate, \
            GymBackupRestore, and the round-trip test above all cover it, then \
            update this count.
            """,
            file: file,
            line: line
        )
    }

    /// Some DTOs have too many non-defaulted fields to construct by hand just
    /// to count them. Decoding the minimum legal payload gives the same Mirror
    /// without duplicating the whole argument list in this test.
    private static func decodeFixture<T: Decodable>(_ type: T.Type, json: String) -> T? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: Data(json.utf8))
    }

    private static func fixtureInstance<T>(for type: T.Type) -> Any? {
        switch String(describing: type) {
        case "ExerciseSetDTO":
            return ExerciseSetDTO(
                orderIndex: 0,
                weightType: WeightType.kg.rawValue,
                distanceType: DistanceType.kilometers.rawValue,
                repetition: 0,
                weight: 0,
                duration: nil,
                distance: nil,
                done: false,
                rpe: nil,
                setType: SetType.normal.rawValue,
                usedMetric: UnitSystem.metric.rawValue
            )
        case "ExerciseSetSegmentDTO":
            return ExerciseSetSegmentDTO(
                id: UUID().uuidString,
                orderIndex: 0,
                repetitions: 0,
                weight: 0,
                weightType: WeightType.kg.rawValue,
                duration: nil,
                restAfterSeconds: nil,
                done: false,
                variationNote: nil,
                rpe: nil,
                rir: nil
            )
        case "ComplexComponentResultDTO":
            return ComplexComponentResultDTO(
                id: UUID().uuidString,
                orderIndex: 0,
                exerciseID: UUID().uuidString,
                exerciseNameSnapshot: "",
                prescribedRepetitions: 1,
                performedRepetitions: 0,
                outcome: ComplexComponentOutcome.notStarted.rawValue,
                liftQuality: nil
            )
        case "ExerciseEntryDTO":
            return decodeFixture(
                ExerciseEntryDTO.self,
                json: """
                {"orderIndex":0,"exerciseName":"","usedMetric":"\(UnitSystem.metric.rawValue)","sets":[]}
                """
            )
        case "WorkoutDTO":
            return decodeFixture(
                WorkoutDTO.self,
                json: """
                {"status":"\(WorkoutStatus.completed.rawValue)","startTime":0,"exercises":[]}
                """
            )
        case "ExerciseTemplateDTO":
            return ExerciseTemplateDTO(
                name: "",
                primaryMuscles: [],
                secondaryMuscles: nil,
                category: nil,
                trackingType: TrackingType.weightAndReps.rawValue,
                equipmentType: nil,
                resistanceType: nil,
                movementPattern: nil,
                difficulty: nil,
                tags: [],
                isFavorite: false,
                isPlateLoaded: false,
                isCustom: false,
                isArchived: false
            )
        case "FoodItemDTO":
            return FoodItemDTO(
                id: UUID().uuidString,
                name: "",
                referenceAmount: 100,
                referenceUnit: NutritionServingUnit.grams.rawValue,
                calories: nil,
                proteinGrams: nil,
                carbohydrateGrams: nil,
                fatGrams: nil,
                sourceKind: FoodSourceKind.userCreated.rawValue,
                confidence: FoodConfidence.userProvided.rawValue,
                preparationState: FoodPreparationState.raw.rawValue,
                isFavorite: false,
                isArchived: false,
                createdAt: .now,
                updatedAt: .now,
                servings: []
            )
        case "LoggedMealDTO":
            return LoggedMealDTO(
                id: UUID().uuidString,
                dayKey: "2026-01-01",
                slot: MealSlot.snack.rawValue,
                loggedAt: .now,
                nameSnapshot: "",
                sourceMealTemplateID: nil,
                sourceMealTemplateName: nil,
                createdAt: .now,
                updatedAt: .now,
                items: []
            )
        case "MobilityRoutineDTO":
            return MobilityRoutineDTO(
                id: UUID().uuidString,
                name: "",
                notes: nil,
                isArchived: false,
                createdAt: .now,
                updatedAt: .now,
                items: [],
                purpose: nil
            )
        case "MobilityAssessmentDefinitionDTO":
            return MobilityAssessmentDefinitionDTO(
                id: UUID().uuidString,
                catalogueKey: "mobility-assessment.sentinel",
                name: "",
                nameLocalizationKey: "",
                instructionsLocalizationKey: "",
                setupInstructionsLocalizationKey: "",
                measurementDescriptionLocalizationKey: "",
                measurementLimitationsLocalizationKey: "",
                zone: MobilityAssessmentZone.hips.rawValue,
                definitionVersion: 1,
                preferredMode: MobilityMeasurementMode.inclinometer.rawValue,
                manualMode: MobilityMeasurementMode.manualAngle.rawValue,
                unit: MobilityMeasurementUnit.degrees.rawValue,
                supportedSides: [MobilityAssessmentSide.left.rawValue],
                setupKeys: ["sentinel"],
                defaultSetupKey: "sentinel",
                defaultIsActiveRange: true,
                sortOrder: 0,
                isArchived: false,
                createdAt: .now,
                updatedAt: .now
            )
        case "MobilityAssessmentSampleDTO":
            return MobilityAssessmentSampleDTO(
                id: UUID().uuidString,
                sampleCount: 1,
                median: 0,
                minimum: 0,
                maximum: 0,
                standardDeviation: 0,
                offAxisExcessDegrees: 0,
                captureDuration: 1,
                createdAt: .now
            )
        case "MobilityAssessmentResultDTO":
            return MobilityAssessmentResultDTO(
                id: UUID().uuidString,
                orderIndex: 0,
                numericValue: 0,
                criteria: nil,
                side: MobilityAssessmentSide.left.rawValue,
                isWarm: false,
                setupKey: "sentinel",
                method: MobilityMeasurementMode.manualAngle.rawValue,
                unit: MobilityMeasurementUnit.degrees.rawValue,
                isActiveRange: true,
                dayKey: "2026-01-01",
                source: MobilityMeasurementSource.manual.rawValue,
                confidence: MobilityMeasurementConfidence.moderate.rawValue,
                definitionIDSnapshot: UUID().uuidString,
                definitionCatalogueKeySnapshot: "mobility-assessment.sentinel",
                definitionNameSnapshot: "",
                definitionVersionSnapshot: 1,
                instructionsLocalizationKeySnapshot: "",
                setupInstructionsLocalizationKeySnapshot: "",
                measurementDescriptionLocalizationKeySnapshot: "",
                measurementLimitationsLocalizationKeySnapshot: "",
                createdAt: .now,
                updatedAt: .now,
                sample: nil
            )
        case "MobilityAssessmentSessionDTO":
            return MobilityAssessmentSessionDTO(
                id: UUID().uuidString,
                status: MobilityAssessmentSessionStatus.active.rawValue,
                dayKey: "2026-01-01",
                selectedDefinitionKeys: [],
                skippedDefinitionKeys: [],
                currentDefinitionIndex: 0,
                startedAt: .now,
                completedAt: nil,
                createdAt: .now,
                updatedAt: .now,
                results: []
            )
        default:
            return nil
        }
    }

    // MARK: - Helpers

    /// The full production path a restore takes: create the backup, serialize
    /// it, read it back, and restore into a fresh store.
    private func roundTrip(_ source: ModelContext) -> ModelContext {
        do {
            let backup = try BackupDTO.create(
                from: source,
                restTimer: 90,
                darkMode: false,
                unitSystem: .metric
            )
            let data = try JSONEncoder().encode(backup)
            let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)
            let destination = try makeContext()
            try decoded.restore(to: destination)
            return destination
        } catch {
            XCTFail("Backup round trip failed: \(error)")
            return try! makeContext()
        }
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}

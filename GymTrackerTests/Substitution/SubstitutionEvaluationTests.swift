import XCTest
@testable import GymTracker

final class SubstitutionEvaluationTests: XCTestCase {
    func testMissingEvidenceIsNeverOptimistic() {
        let source = Exercise(name: "Source", primaryMuscles: [])
        let candidate = Exercise(name: "Candidate", primaryMuscles: [])
        let result = evaluate(source, candidate, context: context())

        XCTAssertEqual(result.suitability, .insufficientInformation)
        XCTAssertEqual(result.comparability, .unknown)
        XCTAssertEqual(result.confidence, .insufficient)
        XCTAssertFalse(result.snapshot.missingEvidenceCodes.isEmpty)
    }

    func testHypertrophySubstituteCanBeGoodButNotHistoricallyComparable() {
        let source = completeExercise(name: "Barbell Bench")
        let candidate = completeExercise(
            name: "Machine Chest Press",
            mechanics: .isolation,
            rangeOfMotion: .partial,
            laterality: .unilateral
        )
        let result = evaluate(source, candidate, context: context(goal: .hypertrophy))

        XCTAssertEqual(result.suitability, .good)
        XCTAssertEqual(result.comparability, .notDirect)
    }

    func testDirectComparabilityRequiresEveryLoadIdentityField() {
        let source = completeExercise(name: "Source")
        XCTAssertEqual(evaluate(source, completeExercise(name: "Same"), context: context()).comparability, .direct)

        let variants: [Exercise] = [
            completeExercise(name: "Family", family: "other-family"),
            completeExercise(name: "Tracking", tracking: .repsOnly),
            completeExercise(name: "Laterality", laterality: .unilateral),
            completeExercise(name: "Entry", weightEntry: .perLoadUnit),
            completeExercise(name: "Units", loadUnits: 2),
            completeExercise(name: "Resistance", resistance: .machine)
        ]
        for candidate in variants {
            XCTAssertNotEqual(
                evaluate(source, candidate, context: context()).comparability,
                .direct,
                "\(candidate.name) was incorrectly treated as directly comparable"
            )
        }
    }

    func testHardFiltersReturnDisabledCandidateWithReason() {
        let source = completeExercise(name: "Source")
        let unavailable = completeExercise(name: "Machine", equipment: .machine)
        let equipmentResult = evaluate(
            source, unavailable,
            context: context(availableEquipment: [.barbell])
        )
        XCTAssertEqual(equipmentResult.suitability, .notRecommended)
        XCTAssertTrue(equipmentResult.snapshot.hardFilterFailureCodes.contains(SubstitutionFactorCode.equipmentUnavailable))

        let duration = completeExercise(name: "Duration", tracking: .duration)
        let trackingResult = evaluate(source, duration, context: context())
        XCTAssertEqual(trackingResult.suitability, .notRecommended)
        XCTAssertTrue(trackingResult.snapshot.hardFilterFailureCodes.contains(SubstitutionFactorCode.incompatibleTracking))
    }

    func testDiscomfortAndSkillHardFiltersKeepCandidatesVisibleButDisabled() {
        let source = completeExercise(name: "Source", difficulty: .beginner)
        let painfulPattern = completeExercise(name: "Painful", difficulty: .beginner)
        let discomfort = evaluate(
            source,
            painfulPattern,
            context: context(reason: .discomfort, uncomfortablePositions: [.horizontalPush])
        )
        XCTAssertEqual(discomfort.suitability, .notRecommended)
        XCTAssertTrue(discomfort.snapshot.hardFilterFailureCodes.contains(SubstitutionFactorCode.uncomfortablePosition))
        XCTAssertFalse(discomfort.isSelectable)

        let tooAdvanced = completeExercise(name: "Advanced", difficulty: .advanced)
        let skill = evaluate(source, tooAdvanced, context: context(reason: .skillOrConfidence))
        XCTAssertEqual(skill.suitability, .notRecommended)
        XCTAssertTrue(skill.snapshot.hardFilterFailureCodes.contains(SubstitutionFactorCode.skillInappropriate))
        XCTAssertFalse(skill.isSelectable)
    }

    func testUnknownComparabilityCannotCreateSharedPolicy() {
        let source = completeExercise(name: "Source")
        let unknown = Exercise(name: "Unknown", primaryMuscles: [.upperChest])
        let result = evaluate(source, unknown, context: context())
        let decision = SubstitutionDecision(
            reason: .preference,
            scope: .todayOnly,
            progressionPolicy: .continueShared,
            evaluation: result.snapshot
        )
        XCTAssertEqual(result.comparability, .unknown)
        XCTAssertEqual(decision.progressionPolicy, .separate)
    }

    func testCandidateSourceNeverInventsMetadataOnlyRelationship() {
        let source = completeExercise(name: "Bench Press")
        let similar = completeExercise(name: "Bench Press Similar")
        XCTAssertTrue(SubstitutionCandidateSource.candidates(for: source, relationships: []).isEmpty)

        let relationship = ExerciseRelationship(sourceExercise: source, targetExercise: similar, type: .substitution)
        XCTAssertEqual(
            SubstitutionCandidateSource.candidates(for: source, relationships: [relationship]).map(\.exercise.id),
            [similar.id]
        )
    }

    func testRankingIsDeterministicAndBreaksTiesByName() {
        let source = completeExercise(name: "Source")
        let alpha = completeExercise(name: "Alpha")
        let bravo = completeExercise(name: "Bravo")
        let candidates = [
            SubstitutionCandidate(exercise: bravo, provenance: .systemReviewed, rationaleCode: "r"),
            SubstitutionCandidate(exercise: alpha, provenance: .systemReviewed, rationaleCode: "r")
        ]
        let first = SubstitutionEvaluationService.rankedEvaluations(for: source, candidates: candidates, context: context())
        let second = SubstitutionEvaluationService.rankedEvaluations(for: source, candidates: candidates, context: context())
        XCTAssertEqual(first.map(\.exercise.id), second.map(\.exercise.id))
        XCTAssertEqual(first.map(\.exercise.name), ["Alpha", "Bravo"])
    }

    private func evaluate(_ source: Exercise, _ candidate: Exercise, context: SubstitutionContext) -> SubstitutionEvaluation {
        SubstitutionEvaluationService.evaluate(
            source: source,
            candidate: SubstitutionCandidate(exercise: candidate, provenance: .systemReviewed, rationaleCode: "substitution.rationale.test"),
            context: context
        )
    }

    private func context(
        goal: PlanGoal = .hypertrophy,
        availableEquipment: Set<EquipmentType>? = nil,
        reason: SubstitutionReason = .preference,
        uncomfortablePositions: Set<MovementPattern> = []
    ) -> SubstitutionContext {
        SubstitutionContext(
            goal: goal,
            stimulus: .hypertrophy,
            role: .accessory,
            prescribedTracking: .weightAndReps,
            availableEquipment: availableEquipment,
            uncomfortablePositions: uncomfortablePositions,
            reason: reason
        )
    }

    private func completeExercise(
        name: String,
        family: String = "bench-family",
        tracking: TrackingType = .weightAndReps,
        equipment: EquipmentType = .barbell,
        resistance: ResistanceType = .externalWeight,
        mechanics: ExerciseMechanics = .compound,
        rangeOfMotion: RangeOfMotion = .full,
        laterality: Laterality = .bilateral,
        weightEntry: WeightEntryStyle = .totalLoad,
        loadUnits: Int = 1,
        difficulty: Difficulty = .intermediate
    ) -> Exercise {
        Exercise(
            name: name,
            primaryMuscles: [.upperChest],
            trackingType: tracking,
            equipmentType: equipment,
            resistanceType: resistance,
            movementPattern: .horizontalPush,
            mechanics: mechanics,
            gripStyle: .pronated,
            stance: .supine,
            rangeOfMotion: rangeOfMotion,
            variationFamilyID: family,
            difficulty: difficulty,
            laterality: laterality,
            weightEntryStyle: weightEntry,
            loadUnitCount: loadUnits
        )
    }
}

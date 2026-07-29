import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SubstitutionSchemaTests: XCTestCase {
    func testNewEntryFieldsStartWithDocumentedLegacyDefaults() {
        let exercise = Exercise(name: "Legacy Press", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)

        XCTAssertNil(entry.substitutionReasonCode)
        XCTAssertNil(entry.substitutionSuitability)
        XCTAssertNil(entry.substitutionComparability)
        XCTAssertEqual(entry.substitutionProgressionPolicy, nil)
        XCTAssertNil(entry.substitutionScope)
        XCTAssertNil(entry.substitutionEvidenceConfidence)
        XCTAssertNil(entry.substitutionEvaluationVersion)
        XCTAssertNil(entry.substitutionEvaluation)
        XCTAssertFalse(entry.substitutionSharesProgressionState)
    }

    func testNewRelationshipFieldsUseConservativeLegacyDefaults() {
        let source = Exercise(name: "Source", primaryMuscles: [.upperChest])
        let target = Exercise(name: "Target", primaryMuscles: [.upperChest])
        let relationship = ExerciseRelationship(
            sourceExercise: source,
            targetExercise: target,
            type: .substitution
        )

        XCTAssertEqual(relationship.resolvedProvenance, .systemUnreviewed)
        XCTAssertNil(relationship.rationaleCode)
        XCTAssertTrue(relationship.appliesToGoals.isEmpty)
        XCTAssertTrue(relationship.appliesToRoles.isEmpty)
        XCTAssertNil(relationship.reviewVersion)
    }

    func testDecisionPoliciesKeepLegacyProgressionBooleanInLockstep() {
        let entry = ExerciseEntry(
            exercise: Exercise(name: "Press", primaryMuscles: [.upperChest]),
            usedMetric: .metric
        )

        entry.applySubstitutionDecision(makeDecision(policy: .continueShared, comparability: .direct))
        XCTAssertEqual(entry.substitutionProgressionPolicy, .continueShared)
        XCTAssertTrue(entry.substitutionSharesProgressionState)

        entry.applySubstitutionDecision(makeDecision(policy: .separate, comparability: .direct))
        XCTAssertEqual(entry.substitutionProgressionPolicy, .separate)
        XCTAssertFalse(entry.substitutionSharesProgressionState)

        entry.applySubstitutionDecision(makeDecision(policy: .undetermined, comparability: .unknown))
        XCTAssertEqual(entry.substitutionProgressionPolicy, .undetermined)
        XCTAssertFalse(entry.substitutionSharesProgressionState)
    }

    func testUnsupportedSharedPolicyIsDowngradedBeforeItReachesEntry() {
        let entry = ExerciseEntry(
            exercise: Exercise(name: "Press", primaryMuscles: [.upperChest]),
            usedMetric: .metric
        )

        entry.applySubstitutionDecision(makeDecision(policy: .continueShared, comparability: .unknown))

        XCTAssertEqual(entry.substitutionProgressionPolicy, .separate)
        XCTAssertFalse(entry.substitutionSharesProgressionState)
    }

    func testV19BackupWithoutDecisionEvidenceRestoresWithDocumentedDefaults() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let original = Exercise(name: "Source", primaryMuscles: [.upperChest])
        let replacement = Exercise(name: "Replacement", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(exercise: original, usedMetric: .metric)
        entry.originalExerciseIDSnapshot = original.id
        entry.originalExerciseNameSnapshot = original.name
        entry.selectedSubstituteExerciseIDSnapshot = replacement.id
        entry.substitutionReason = "User-selected substitution"
        entry.substitutionSharesProgressionState = false
        let workout = Workout(name: "Legacy substitution", endTime: .now)
        workout.exercises = [entry]
        let relationship = ExerciseRelationship(
            sourceExercise: original,
            targetExercise: replacement,
            type: .substitution,
            provenance: .systemReviewed,
            rationaleCode: "substitution.rationale.test",
            appliesToGoals: [.hypertrophy],
            appliesToRoles: [.accessory],
            reviewVersion: 1
        )
        source.insert(original)
        source.insert(replacement)
        source.insert(relationship)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(from: source, restTimer: 90, darkMode: false, unitSystem: .metric)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(backup)) as? [String: Any])
        payload["version"] = 19
        let entryKeys = [
            "substitutionReasonCode", "substitutionSuitability", "substitutionComparability",
            "substitutionProgressionPolicy", "substitutionScope", "substitutionEvidenceConfidence",
            "substitutionEvaluationVersion", "substitutionEvaluationData"
        ]
        var workouts = try XCTUnwrap(payload["workouts"] as? [[String: Any]])
        for index in workouts.indices {
            var entries = try XCTUnwrap(workouts[index]["exercises"] as? [[String: Any]])
            for entryIndex in entries.indices {
                entryKeys.forEach { entries[entryIndex].removeValue(forKey: $0) }
            }
            workouts[index]["exercises"] = entries
        }
        payload["workouts"] = workouts
        let relationshipKeys = ["provenance", "rationaleCode", "appliesToGoals", "appliesToRoles", "reviewVersion"]
        var relationships = try XCTUnwrap(payload["exerciseRelationships"] as? [[String: Any]])
        for index in relationships.indices {
            relationshipKeys.forEach { relationships[index].removeValue(forKey: $0) }
        }
        payload["exerciseRelationships"] = relationships

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let v19 = try decoder.decode(BackupDTO.self, from: JSONSerialization.data(withJSONObject: payload))
        let destination = try GymTrackerTestStore.makeInMemoryContext()
        try v19.restore(to: destination)

        let restoredEntry = try XCTUnwrap(try destination.fetch(FetchDescriptor<Workout>()).first?.orderedExercises.first)
        XCTAssertNil(restoredEntry.substitutionReasonCode)
        XCTAssertNil(restoredEntry.substitutionSuitability)
        XCTAssertNil(restoredEntry.substitutionComparability)
        XCTAssertEqual(restoredEntry.substitutionProgressionPolicy, .separate)
        XCTAssertNil(restoredEntry.substitutionScope)
        XCTAssertNil(restoredEntry.substitutionEvidenceConfidence)
        XCTAssertNil(restoredEntry.substitutionEvaluation)
        XCTAssertFalse(restoredEntry.substitutionSharesProgressionState)
        let restoredRelationship = try XCTUnwrap(try destination.fetch(FetchDescriptor<ExerciseRelationship>()).first)
        XCTAssertEqual(restoredRelationship.resolvedProvenance, .systemUnreviewed)
        XCTAssertNil(restoredRelationship.rationaleCode)
        XCTAssertTrue(restoredRelationship.appliesToGoals.isEmpty)
        XCTAssertTrue(restoredRelationship.appliesToRoles.isEmpty)
        XCTAssertNil(restoredRelationship.reviewVersion)
    }

    /// The only non-initialization writes are the decision helper and the
    /// restore reconciler. The latter deliberately re-establishes the invariant
    /// for a malformed hand-edited backup payload.
    func testLegacyProgressionBooleanHasOnlyAuditedWriteSites() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let paths = [
            root.appendingPathComponent("GymTracker/Core/Models/Entities/Exercise/ExerciseEntry.swift"),
            root.appendingPathComponent("GymTracker/Core/Data/GymBackupRestore.swift")
        ]
        let writes = try paths.flatMap { path -> [String] in
            try String(contentsOf: path, encoding: .utf8)
                .split(separator: "\n")
                .map(String.init)
                .filter { $0.contains("substitutionSharesProgressionState =") }
        }

        // One initialization default and two restore reconciliation writes are
        // intentional; the production mutation path itself remains singular.
        XCTAssertEqual(writes.count, 5, "Unexpected direct write to the legacy progression flag: \(writes)")
        XCTAssertTrue(writes.contains { $0.contains("self.substitutionSharesProgressionState = false") })
        XCTAssertTrue(writes.contains { $0.contains("decision.progressionPolicy.sharesProgressionState") })
        XCTAssertTrue(writes.contains { $0.contains("entryDTO.substitutionSharesProgressionState ?? false") })
        XCTAssertTrue(writes.contains { $0.contains("policy.sharesProgressionState") })
    }

    private func makeDecision(
        policy: ProgressionTransferPolicy,
        comparability: SubstitutionComparability
    ) -> SubstitutionDecision {
        let sourceID = UUID()
        return SubstitutionDecision(
            reason: .equipmentUnavailable,
            scope: .todayOnly,
            progressionPolicy: policy,
            evaluation: SubstitutionEvaluationSnapshot(
                version: SubstitutionEvaluationService.ruleVersion,
                ruleID: SubstitutionEvaluationService.ruleID,
                sourceExerciseID: sourceID,
                candidateExerciseID: UUID(),
                reason: .equipmentUnavailable,
                suitability: .good,
                comparability: comparability,
                confidence: .moderate,
                matchedFactorCodes: [],
                differingFactorCodes: [],
                missingEvidenceCodes: [],
                hardFilterFailureCodes: [],
                candidateProvenance: .systemReviewed
            )
        )
    }
}

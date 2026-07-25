import Foundation
import XCTest
@testable import GymTracker

/// How a single `ExerciseSet`'s fields get classified as evidence: default
/// semantics when persisted fields are missing, RPE/RIR mutual exclusivity,
/// typed specialized-metric/velocity values, and which record policy
/// (traditional vs. specialized) a set qualifies for.
@MainActor
final class StrengthEvidenceSemanticsTests: XCTestCase {
    func testMissingPersistedSetMethodUsesStandardSemantics() {
        let set = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        set.setMethod = nil

        XCTAssertEqual(set.resolvedSetMethod, .standard)
    }

    func testMissingPersistedSpecializedMetricUsesNoMetricSemantics() {
        let set = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        set.specializedMetricKind = nil

        XCTAssertEqual(set.resolvedSpecializedMetricKind, .none)
        XCTAssertTrue(StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set))
    }

    func testPerformedEffortWritesAreExclusive() {
        let set = ExerciseSet(repetitions: 8, weight: 80, rpe: 8.5, rir: 2, usedMetric: .metric)

        set.recordRIR(2)
        XCTAssertEqual(set.rir, 2)
        XCTAssertNil(set.rpe)

        set.recordRPE(8.5)
        XCTAssertEqual(set.rpe, 8.5)
        XCTAssertNil(set.rir)
    }

    func testHalfStepPerformedRPEAndScaleMeanings() {
        let set = ExerciseSet(repetitions: 5, weight: 140, rpe: 9.5, usedMetric: .metric)
        XCTAssertEqual(set.rpe, 9.5)

        XCTAssertEqual(RPEScale.meaning(for: 9.5), "No reps left — could maybe load slightly more")
        XCTAssertEqual(RPEScale.meaning(for: 8.5), "Definitely 1, maybe 2 more reps")
        XCTAssertEqual(RPEScale.meaning(for: 7.5), "Definitely 2, maybe 3 more reps")
        XCTAssertEqual(RPEScale.meaning(for: 6.5), "Definitely 3, maybe 4 more reps")
    }

    func testContextAwareRecordPolicySeparatesSegmentedAndSpecializedEvidence() throws {
        let standard = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        let cluster = ExerciseSet(repetitions: 5, weight: 100, done: true, setMethod: .cluster, usedMetric: .metric)
        let jump = ExerciseSet(
            done: true,
            specializedMetricKind: .jumpHeight,
            jumpHeightMeters: 0.58,
            specializedMetricMeasurementSource: .device,
            usedMetric: .metric
        )
        let estimatedJump = ExerciseSet(
            done: true,
            specializedMetricKind: .jumpHeight,
            jumpHeightMeters: 0.62,
            specializedMetricMeasurementSource: .estimated,
            usedMetric: .metric
        )
        let unsourcedJump = ExerciseSet(
            done: true,
            specializedMetricKind: .jumpHeight,
            jumpHeightMeters: 0.62,
            usedMetric: .metric
        )
        let zeroContactTime = ExerciseSet(
            done: true,
            specializedMetricKind: .contactTime,
            contactTimeMilliseconds: 0,
            specializedMetricMeasurementSource: .device,
            usedMetric: .metric
        )

        XCTAssertTrue(StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(standard))
        XCTAssertFalse(StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(cluster))
        XCTAssertTrue(StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(jump))
        XCTAssertFalse(StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(estimatedJump))
        XCTAssertFalse(StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(unsourcedJump))
        XCTAssertFalse(StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(zeroContactTime))
        XCTAssertEqual(StrengthAnalyticsPolicy.specializedMetricValue(for: jump)?.unit, "m")
    }

    func testEverySpecializedMetricAndVelocityUsesTypedComparableEvidence() {
        let velocity = ExerciseSet(
            done: true,
            meanVelocity: 0.58,
            peakVelocity: 0.71,
            velocityMeasurementSource: .device,
            usedMetric: .metric
        )
        XCTAssertTrue(StrengthAnalyticsPolicy.isEligibleForVelocityRecord(velocity))

        let jump = ExerciseSet(
            done: true,
            specializedMetricKind: .jumpHeight,
            jumpHeightMeters: 0.55,
            specializedMetricMeasurementSource: .device,
            usedMetric: .metric
        )
        let contact = ExerciseSet(
            done: true,
            specializedMetricKind: .contactTime,
            contactTimeMilliseconds: 180,
            specializedMetricMeasurementSource: .device,
            usedMetric: .metric
        )
        let throwDistance = ExerciseSet(
            done: true,
            specializedMetricKind: .throwDistance,
            throwDistanceMeters: 6.2,
            specializedMetricMeasurementSource: .manual,
            usedMetric: .metric
        )
        let kettlebellCadence = ExerciseSet(
            done: true,
            specializedMetricKind: .kettlebellCadence,
            kettlebellCadenceRPM: 28,
            specializedMetricMeasurementSource: .device,
            usedMetric: .metric
        )
        let expectedUnits: [(ExerciseSet, String)] = [
            (jump, "m"),
            (contact, "ms"),
            (throwDistance, "m"),
            (kettlebellCadence, "rpm")
        ]
        for (set, unit) in expectedUnits {
            XCTAssertTrue(StrengthAnalyticsPolicy.isEligibleForSpecializedMetricRecord(set))
            XCTAssertEqual(StrengthAnalyticsPolicy.specializedMetricValue(for: set)?.unit, unit)
        }
        XCTAssertTrue(StrengthAnalyticsPolicy.prefersLowerSpecializedMetric(.contactTime))
        XCTAssertFalse(StrengthAnalyticsPolicy.prefersLowerSpecializedMetric(.throwDistance))
        XCTAssertFalse(StrengthAnalyticsPolicy.prefersLowerSpecializedMetric(.kettlebellCadence))
    }

    /// `ExerciseSet.tempo`, `movementQuality`, `descriptiveROM`, and
    /// `discomfortScore` are unsupported performed fields: they exist for
    /// storage/backup compatibility only and must never gain a production
    /// input control. This is a source-level regression guard rather than a
    /// UI snapshot test because the app has no view-inspection dependency;
    /// it fails the moment any active-workout view binds one of these
    /// properties, before it can ship silently.
    func testActiveWorkoutSetDetailExposesNoReservedPerformedFields() throws {
        let reservedFields = ["movementQuality", "descriptiveROM", "discomfortScore"]
        let activeWorkoutSourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Workout
            .deletingLastPathComponent() // GymTrackerTests
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("GymTracker/Core/Features/ActiveWorkout")

        let sourceFiles = try FileManager.default
            .contentsOfDirectory(
                at: activeWorkoutSourceRoot.appendingPathComponent("Component"),
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(sourceFiles.isEmpty, "Expected to find active workout component sources to scan.")

        for file in sourceFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for field in reservedFields {
                XCTAssertFalse(
                    source.contains(field),
                    "\(file.lastPathComponent) must not reference reserved performed field '\(field)'."
                )
            }
            // Performed tempo is unsupported; prescribed tempo is separate,
            // supported evidence and must remain untouched by this check.
            XCTAssertFalse(
                source.contains("exerciseSet.tempo") || source.contains("$exerciseSet.tempo"),
                "\(file.lastPathComponent) must not bind ExerciseSet.tempo (unsupported performed tempo)."
            )
        }
    }
}

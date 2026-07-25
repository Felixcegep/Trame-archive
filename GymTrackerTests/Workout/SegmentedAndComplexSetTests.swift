import Foundation
import XCTest
@testable import GymTracker

/// Sets that decompose into internal parts — drop sets/clusters recorded as
/// segments, and structured complexes (e.g. clean + jerk) recorded as
/// components — and how copying a set for the next round resets that
/// internal structure without losing its method or shape.
@MainActor
final class SegmentedAndComplexSetTests: XCTestCase {
    func testSegmentedSetCopiesMethodAndCreatesFreshIncompleteSegments() throws {
        let set = ExerciseSet(
            repetitions: 18,
            weight: 30,
            done: true,
            meanVelocity: 0.62,
            peakVelocity: 0.81,
            velocityMeasurementSource: .manual,
            setMethod: .dropSet,
            usedMetric: .metric
        )
        set.segments = [
            ExerciseSetSegment(orderIndex: 2, repetitions: 8, weight: 16, done: true),
            ExerciseSetSegment(orderIndex: 0, repetitions: 10, weight: 30, done: true),
            ExerciseSetSegment(orderIndex: 1, repetitions: 8, weight: 22, done: true)
        ]

        let copy = set.copy()

        XCTAssertEqual(copy.resolvedSetMethod, .dropSet)
        XCTAssertEqual(copy.peakVelocity, 0.81)
        XCTAssertEqual(copy.velocityMeasurementSource, .manual)
        XCTAssertEqual(copy.orderedSegments.map(\.weight), [30, 22, 16])
        XCTAssertTrue(copy.orderedSegments.allSatisfy { !$0.done })
        XCTAssertNotEqual(copy.orderedSegments.map(\.id), set.orderedSegments.map(\.id))
    }

    func testStructuredComplexPreservesOrderedComponentOutcomesAndCopiesFreshAttempts() {
        let cleanID = UUID()
        let jerkID = UUID()
        let set = ExerciseSet(repetitions: 2, weight: 80, usedMetric: .metric)
        set.ensureComplexComponents(for: [
            ComplexComponentSnapshot(exerciseID: cleanID, exerciseNameSnapshot: "Clean", prescribedRepetitions: 1),
            ComplexComponentSnapshot(exerciseID: jerkID, exerciseNameSnapshot: "Jerk", prescribedRepetitions: 1)
        ])

        XCTAssertEqual(set.repetitions, 2)

        set.complexComponents[0].outcome = .completed
        set.complexComponents[0].performedRepetitions = 1
        set.complexComponents[1].outcome = .missed
        set.complexComponents[1].liftQuality = .missed
        set.done = true
        set.synchronizeComplexCompletion()

        XCTAssertEqual(set.orderedComplexComponents.map(\.exerciseNameSnapshot), ["Clean", "Jerk"])
        XCTAssertEqual(set.orderedComplexComponents.map(\.outcome), [.completed, .missed])
        XCTAssertEqual(set.repetitions, 1)
        XCTAssertEqual(set.liftQuality, .missed)
        XCTAssertFalse(StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set))

        let copy = set.copy()
        XCTAssertTrue(copy.orderedComplexComponents.allSatisfy { $0.outcome == .notStarted })
        XCTAssertTrue(copy.orderedComplexComponents.allSatisfy { $0.performedRepetitions == 0 })
        XCTAssertNotEqual(copy.orderedComplexComponents.map(\.id), set.orderedComplexComponents.map(\.id))
    }

    func testSegmentedMethodRestoresItsMinimumStructureAndCannotBecomeTraditionalEvidence() {
        let set = ExerciseSet(
            repetitions: 8,
            weight: 80,
            done: true,
            setMethod: .cluster,
            usedMetric: .metric
        )
        set.segments = [ExerciseSetSegment(orderIndex: 4, repetitions: 2, weight: 80, done: true)]

        set.ensureSegmentsForMethod()
        XCTAssertEqual(set.orderedSegments.count, SetMethod.cluster.minimumSegmentCount)
        XCTAssertEqual(set.orderedSegments.map(\.orderIndex), Array(0..<SetMethod.cluster.minimumSegmentCount))

        // Preserving historical segments matters even if someone later changes
        // the visible method. This evidence must not become a normal load PR.
        set.setMethod = .standard
        XCTAssertFalse(StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set))

        set.done = false
        set.synchronizeSegmentCompletion()
        XCTAssertTrue(set.orderedSegments.allSatisfy { !$0.done })
    }
}

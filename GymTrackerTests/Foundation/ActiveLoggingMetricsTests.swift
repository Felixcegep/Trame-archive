import Foundation
import XCTest
@testable import GymTracker

@MainActor
final class ActiveLoggingMetricsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "ActiveLoggingMetricsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testSetEntryDurationUsesMonotonicWholeSecondMedian() {
        let defaults = makeDefaults()
        var now: TimeInterval = 0
        let recorder = ActiveLoggingMetricsRecorder(
            defaults: defaults,
            buildNumber: "42",
            isEnabled: true,
            monotonicTime: { now }
        )

        let first = UUID()
        recorder.focusChanged(to: first, field: .weight, replacesExistingValue: false)
        now = 4.9
        recorder.setCompleted(id: first)

        let second = UUID()
        recorder.focusChanged(to: second, field: .repetitions, replacesExistingValue: false)
        now = 9.2
        recorder.setCompleted(id: second)

        XCTAssertEqual(recorder.snapshot.setEntrySampleCount, 2)
        XCTAssertEqual(recorder.snapshot.medianSetEntrySeconds, 4)
    }

    func testCorrectionCountsOncePerFocusedExistingValue() {
        let recorder = ActiveLoggingMetricsRecorder(defaults: makeDefaults(), buildNumber: "42", isEnabled: true)
        let setID = UUID()

        recorder.focusChanged(to: setID, field: .weight, replacesExistingValue: true)
        recorder.valueCommitted(for: setID, field: .weight)
        recorder.valueCommitted(for: setID, field: .weight)
        recorder.focusChanged(to: setID, field: .repetitions, replacesExistingValue: false)
        recorder.valueCommitted(for: setID, field: .repetitions)

        XCTAssertEqual(recorder.snapshot.valueCorrectionCount, 1)
    }

    func testBuildScopedAggregateSurvivesRelaunchAndResetsForANewBuild() {
        let defaults = makeDefaults()
        let recorder = ActiveLoggingMetricsRecorder(defaults: defaults, buildNumber: "42", isEnabled: true)
        recorder.setCompletionBlocked()
        recorder.restExpected()
        recorder.restStarted()

        let relaunched = ActiveLoggingMetricsRecorder(defaults: defaults, buildNumber: "42", isEnabled: true)
        XCTAssertEqual(relaunched.snapshot.blockedCompletionCount, 1)
        XCTAssertEqual(relaunched.snapshot.restStartedCount, 1)

        let nextBuild = ActiveLoggingMetricsRecorder(defaults: defaults, buildNumber: "43", isEnabled: true)
        XCTAssertFalse(nextBuild.snapshot.hasRecordedData)
    }

    func testDisabledRecorderNeverPersistsOrReportsMetrics() {
        let recorder = ActiveLoggingMetricsRecorder(defaults: makeDefaults(), buildNumber: "42", isEnabled: false)
        recorder.setCompletionBlocked()
        recorder.workoutSaved(isPartial: true)
        recorder.workoutDiscarded()

        XCTAssertFalse(recorder.snapshot.hasRecordedData)
    }

    func testSnapshotReportsRestAndSessionAggregatesWithoutDomainValues() {
        let recorder = ActiveLoggingMetricsRecorder(defaults: makeDefaults(), buildNumber: "42", isEnabled: true)
        recorder.setCompletionBlocked()
        recorder.completedSetReopened()
        recorder.restExpected()
        recorder.restStarted()
        recorder.restPaused()
        recorder.restResumed()
        recorder.restExtended()
        recorder.restSkipped()
        recorder.workoutMinimized()
        recorder.workoutSaved(isPartial: true)
        recorder.workoutDiscarded()

        let text = recorder.snapshot.diagnosticLines.map { "\($0.label): \($0.value)" }.joined(separator: "\n").lowercased()
        XCTAssertTrue(recorder.snapshot.hasRecordedData)
        XCTAssertTrue(text.contains("rest starts: 1 of 1"))
        XCTAssertFalse(text.contains("bench press"))
        XCTAssertFalse(text.contains("100"))
    }

    func testScenarioMedianSeparatesSlowPathFromFastOverallMedian() {
        var now: TimeInterval = 0
        let recorder = ActiveLoggingMetricsRecorder(
            defaults: makeDefaults(),
            buildNumber: "42",
            isEnabled: true,
            monotonicTime: { now }
        )

        for duration in [1.0, 2.0, 2.0, 3.0, 3.0] {
            let setID = UUID()
            recorder.focusChanged(to: setID, field: .repetitions, replacesExistingValue: false)
            now += duration
            recorder.setCompleted(id: setID)
        }

        let slowSetID = UUID()
        recorder.focusChanged(to: slowSetID, field: .weight, replacesExistingValue: false)
        recorder.toolUsed(.plateCalculator)
        now += 30
        recorder.setCompleted(id: slowSetID)

        XCTAssertEqual(recorder.snapshot.medianSetEntrySeconds, 2)
        XCTAssertEqual(
            recorder.snapshot.scenarioMedians.first(where: { $0.scenario == .weighted })?.medianSeconds,
            30
        )
        XCTAssertEqual(
            recorder.snapshot.scenarioMedians.first(where: { $0.scenario == .usedPlateCalculator })?.medianSeconds,
            30
        )
    }

    func testSampleCountsTowardEveryApplicableScenario() {
        var now: TimeInterval = 0
        let recorder = ActiveLoggingMetricsRecorder(
            defaults: makeDefaults(),
            buildNumber: "42",
            isEnabled: true,
            monotonicTime: { now }
        )
        let setID = UUID()

        recorder.focusChanged(to: setID, field: .repetitions, replacesExistingValue: false)
        recorder.focusChanged(to: setID, field: .weight, replacesExistingValue: true)
        recorder.valueCommitted(for: setID, field: .weight)
        now = 4
        recorder.setCompleted(id: setID)

        let scenarios = Set(recorder.snapshot.scenarioMedians.map(\.scenario))
        XCTAssertTrue(scenarios.contains(.weighted))
        XCTAssertTrue(scenarios.contains(.correction))
        XCTAssertFalse(scenarios.contains(.repsOnly))
    }

    func testPrefilledAcceptedRequiresNoOverwrite() {
        var now: TimeInterval = 0
        let recorder = ActiveLoggingMetricsRecorder(
            defaults: makeDefaults(),
            buildNumber: "42",
            isEnabled: true,
            monotonicTime: { now }
        )

        let acceptedID = UUID()
        recorder.focusChanged(to: acceptedID, field: .weight, replacesExistingValue: true)
        now = 2
        recorder.setCompleted(id: acceptedID)

        let correctedID = UUID()
        recorder.focusChanged(to: correctedID, field: .weight, replacesExistingValue: true)
        recorder.valueCommitted(for: correctedID, field: .weight)
        now = 5
        recorder.setCompleted(id: correctedID)

        let medians = recorder.snapshot.scenarioMedians
        XCTAssertEqual(medians.first(where: { $0.scenario == .prefilledAccepted })?.sampleCount, 1)
        XCTAssertEqual(medians.first(where: { $0.scenario == .correction })?.sampleCount, 1)
    }

    func testLegacyStoredPayloadDecodesWithoutScenarioBuckets() throws {
        let defaults = makeDefaults()
        var buckets = Array(repeating: 0, count: 121)
        buckets[7] = 1
        let payload: [String: Any] = [
            "buildNumber": "42",
            "entryDurationBuckets": buckets,
            "blockedCompletionCount": 1,
            "valueCorrectionCount": 0,
            "completedSetReopenCount": 0,
            "restExpectedCount": 0,
            "restStartedCount": 0,
            "restPauseCount": 0,
            "restResumeCount": 0,
            "restExtensionCount": 0,
            "restSkipCount": 0,
            "minimizedCount": 0,
            "savedCount": 0,
            "partialSaveCount": 0,
            "discardedCount": 0
        ]
        defaults.set(
            try JSONSerialization.data(withJSONObject: payload),
            forKey: DefaultsKey.activeLoggingMetrics
        )

        let recorder = ActiveLoggingMetricsRecorder(
            defaults: defaults,
            buildNumber: "42",
            isEnabled: true
        )

        XCTAssertEqual(recorder.snapshot.setEntrySampleCount, 1)
        XCTAssertEqual(recorder.snapshot.medianSetEntrySeconds, 7)
        XCTAssertEqual(recorder.snapshot.blockedCompletionCount, 1)
        XCTAssertTrue(recorder.snapshot.scenarioMedians.isEmpty)
    }
}

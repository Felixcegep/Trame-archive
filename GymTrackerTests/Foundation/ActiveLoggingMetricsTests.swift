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
}

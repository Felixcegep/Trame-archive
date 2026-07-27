import Foundation
import Observation

/// Build-scoped, privacy-safe aggregates from Active Workout interaction.
///
/// This recorder never retains an exercise name, workout identifier, entered
/// value, note, timestamp, or per-set event history. Set identifiers exist
/// only while a value is focused so a duration can be measured; they are never
/// encoded or exposed in a snapshot.
@MainActor
@Observable
final class ActiveLoggingMetricsRecorder {
    struct Snapshot: Sendable, Equatable {
        let setEntrySampleCount: Int
        let medianSetEntrySeconds: Int?
        let blockedCompletionCount: Int
        let valueCorrectionCount: Int
        let completedSetReopenCount: Int
        let restExpectedCount: Int
        let restStartedCount: Int
        let restPauseCount: Int
        let restResumeCount: Int
        let restExtensionCount: Int
        let restSkipCount: Int
        let minimizedCount: Int
        let savedCount: Int
        let partialSaveCount: Int
        let discardedCount: Int

        var hasRecordedData: Bool {
            setEntrySampleCount > 0
                || blockedCompletionCount > 0
                || valueCorrectionCount > 0
                || completedSetReopenCount > 0
                || restExpectedCount > 0
                || restStartedCount > 0
                || restPauseCount > 0
                || restResumeCount > 0
                || restExtensionCount > 0
                || restSkipCount > 0
                || minimizedCount > 0
                || savedCount > 0
                || partialSaveCount > 0
                || discardedCount > 0
        }

        var diagnosticLines: [(label: String, value: String)] {
            guard hasRecordedData else { return [] }

            let median = medianSetEntrySeconds.map { "\($0) s" } ?? String(localized: "No completed entries")
            return [
                (String(localized: "Set entry samples"), "\(setEntrySampleCount)"),
                (String(localized: "Median set entry"), median),
                (String(localized: "Blocked completions"), "\(blockedCompletionCount)"),
                (String(localized: "Value corrections"), "\(valueCorrectionCount + completedSetReopenCount)"),
                (String(localized: "Rest starts"), "\(restStartedCount) of \(restExpectedCount)"),
                (String(localized: "Rest controls"), "\(restPauseCount) pause, \(restResumeCount) resume, \(restExtensionCount) extend, \(restSkipCount) skip"),
                (String(localized: "Session outcomes"), "\(savedCount) saved, \(partialSaveCount) partial, \(discardedCount) discarded, \(minimizedCount) minimized")
            ]
        }
    }

    private struct StoredMetrics: Codable {
        var buildNumber: String
        var entryDurationBuckets: [Int]
        var blockedCompletionCount = 0
        var valueCorrectionCount = 0
        var completedSetReopenCount = 0
        var restExpectedCount = 0
        var restStartedCount = 0
        var restPauseCount = 0
        var restResumeCount = 0
        var restExtensionCount = 0
        var restSkipCount = 0
        var minimizedCount = 0
        var savedCount = 0
        var partialSaveCount = 0
        var discardedCount = 0

        init(buildNumber: String) {
            self.buildNumber = buildNumber
            // 0...120 seconds; the final bucket contains every longer entry.
            self.entryDurationBuckets = Array(repeating: 0, count: 121)
        }
    }

    private struct FocusedField: Equatable {
        let setID: UUID
        let field: SetInputFocus.Field
        let replacesExistingValue: Bool
    }

    private static let storageKey = DefaultsKey.activeLoggingMetrics
    private let defaults: UserDefaults
    private let buildNumber: String
    private let isEnabled: Bool
    private let monotonicTime: () -> TimeInterval
    private var stored: StoredMetrics
    private var activeSetID: UUID?
    private var activeSetStartedAt: TimeInterval?
    private var focusedField: FocusedField?
    private var recordedCorrectionForFocus = false

    init(
        defaults: UserDefaults = .standard,
        buildNumber: String? = nil,
        isEnabled: Bool? = nil,
        monotonicTime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.defaults = defaults
        let currentBuildNumber = buildNumber
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? BetaFeedbackContext.unknownValue
        self.buildNumber = currentBuildNumber
        self.isEnabled = isEnabled ?? FeatureFlags.current.isEnabled(.betaFeedback)
        self.monotonicTime = monotonicTime

        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(StoredMetrics.self, from: data),
           decoded.buildNumber == currentBuildNumber,
           decoded.entryDurationBuckets.count == 121 {
            stored = decoded
        } else {
            stored = StoredMetrics(buildNumber: currentBuildNumber)
        }
    }

    var snapshot: Snapshot {
        Snapshot(
            setEntrySampleCount: stored.entryDurationBuckets.reduce(0, +),
            medianSetEntrySeconds: medianSetEntrySeconds,
            blockedCompletionCount: stored.blockedCompletionCount,
            valueCorrectionCount: stored.valueCorrectionCount,
            completedSetReopenCount: stored.completedSetReopenCount,
            restExpectedCount: stored.restExpectedCount,
            restStartedCount: stored.restStartedCount,
            restPauseCount: stored.restPauseCount,
            restResumeCount: stored.restResumeCount,
            restExtensionCount: stored.restExtensionCount,
            restSkipCount: stored.restSkipCount,
            minimizedCount: stored.minimizedCount,
            savedCount: stored.savedCount,
            partialSaveCount: stored.partialSaveCount,
            discardedCount: stored.discardedCount
        )
    }

    func focusChanged(to setID: UUID, field: SetInputFocus.Field, replacesExistingValue: Bool) {
        guard isEnabled else { return }

        if activeSetID != setID {
            activeSetID = setID
            activeSetStartedAt = monotonicTime()
        }
        focusedField = FocusedField(
            setID: setID,
            field: field,
            replacesExistingValue: replacesExistingValue
        )
        recordedCorrectionForFocus = false
    }

    func valueCommitted(for setID: UUID, field: SetInputFocus.Field) {
        guard isEnabled,
              let focusedField,
              focusedField.setID == setID,
              focusedField.field == field,
              focusedField.replacesExistingValue,
              !recordedCorrectionForFocus
        else { return }

        stored.valueCorrectionCount += 1
        recordedCorrectionForFocus = true
        persist()
    }

    func setCompletionBlocked() {
        mutate { $0.blockedCompletionCount += 1 }
    }

    func setCompleted(id: UUID) {
        guard isEnabled else { return }
        if activeSetID == id, let startedAt = activeSetStartedAt {
            let seconds = max(0, monotonicTime() - startedAt)
            let bucket = min(120, Int(seconds.rounded(.down)))
            stored.entryDurationBuckets[bucket] += 1
            persist()
        }
        activeSetID = nil
        activeSetStartedAt = nil
        focusedField = nil
        recordedCorrectionForFocus = false
    }

    func completedSetReopened() {
        mutate { $0.completedSetReopenCount += 1 }
    }

    func restExpected() { mutate { $0.restExpectedCount += 1 } }
    func restStarted() { mutate { $0.restStartedCount += 1 } }
    func restPaused() { mutate { $0.restPauseCount += 1 } }
    func restResumed() { mutate { $0.restResumeCount += 1 } }
    func restExtended() { mutate { $0.restExtensionCount += 1 } }
    func restSkipped() { mutate { $0.restSkipCount += 1 } }
    func workoutMinimized() { mutate { $0.minimizedCount += 1 } }
    func workoutSaved(isPartial: Bool) {
        mutate {
            $0.savedCount += 1
            if isPartial { $0.partialSaveCount += 1 }
        }
    }
    func workoutDiscarded() { mutate { $0.discardedCount += 1 } }

    func reset() {
        activeSetID = nil
        activeSetStartedAt = nil
        focusedField = nil
        recordedCorrectionForFocus = false
        stored = StoredMetrics(buildNumber: buildNumber)
        defaults.removeObject(forKey: Self.storageKey)
    }

    private var medianSetEntrySeconds: Int? {
        let count = stored.entryDurationBuckets.reduce(0, +)
        guard count > 0 else { return nil }
        let targetIndex = (count - 1) / 2
        var seen = 0
        for (seconds, bucketCount) in stored.entryDurationBuckets.enumerated() {
            seen += bucketCount
            if seen > targetIndex { return seconds }
        }
        return nil
    }

    private func mutate(_ update: (inout StoredMetrics) -> Void) {
        guard isEnabled else { return }
        update(&stored)
        persist()
    }

    private func persist() {
        guard isEnabled, let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

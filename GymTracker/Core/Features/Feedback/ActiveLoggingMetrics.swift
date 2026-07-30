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
        /// Declared last and defaulted so existing callers stay source-compatible.
        var scenarioMedians: [ScenarioMedian] = []

        /// A median is only meaningful next to the number of entries behind it, so
        /// the two travel together and are reported as one line.
        struct ScenarioMedian: Sendable, Equatable {
            let scenario: SetEntryScenario
            let sampleCount: Int
            let medianSeconds: Int
        }

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
            // Each measured path gets its own line. The overall median above can
            // sit under five seconds while one ordinary path sits well over it,
            // and that is precisely the case this report has to expose.
            let scenarioLines = scenarioMedians.map { entry in
                (entry.scenario.title, "\(entry.medianSeconds) s · \(entry.sampleCount)")
            }
            return [
                (String(localized: "Set entry samples"), "\(setEntrySampleCount)"),
                (String(localized: "Median set entry"), median),
            ] + scenarioLines + [
                (String(localized: "Blocked completions"), "\(blockedCompletionCount)"),
                (String(localized: "Value corrections"), "\(valueCorrectionCount + completedSetReopenCount)"),
                (String(localized: "Rest starts"), "\(restStartedCount) of \(restExpectedCount)"),
                (String(localized: "Rest controls"), "\(restPauseCount) pause, \(restResumeCount) resume, \(restExtensionCount) extend, \(restSkipCount) skip"),
                (String(localized: "Session outcomes"), "\(savedCount) saved, \(partialSaveCount) partial, \(discardedCount) discarded, \(minimizedCount) minimized")
            ]
        }
    }

    /// The paths a single set entry can take, so one slow common path cannot hide
    /// behind a fast overall median — the failure mode the product audit calls out
    /// about the five-second target.
    ///
    /// A sample counts toward *every* scenario that applied to it, because the
    /// useful question is "how long does it take when the plate calculator is
    /// involved", not "which single label best describes this entry". Sample
    /// counts therefore sum to more than the total, which is why each scenario
    /// reports its own count alongside its median.
    ///
    /// Nothing here identifies an exercise, a value, or a time. The classification
    /// is derived from which fields were focused and which tools were opened.
    enum SetEntryScenario: String, CaseIterable, Codable, Sendable {
        /// Reps typed and nothing else — a bodyweight or reps-only movement.
        case repsOnly
        /// A load was typed. The common barbell case.
        case weighted
        /// A timed hold or carry.
        case duration
        /// At least one field overwrote a value that was already there.
        case correction
        /// Values arrived from the previous session and were accepted as-is.
        case prefilledAccepted
        case usedCopyLastSet
        case usedPlateCalculator
        case usedEffortChip

        var title: String {
            switch self {
            case .repsOnly: String(localized: "Reps only")
            case .weighted: String(localized: "Weighted")
            case .duration: String(localized: "Duration")
            case .correction: String(localized: "Corrected a value")
            case .prefilledAccepted: String(localized: "Accepted previous values")
            case .usedCopyLastSet: String(localized: "Copied last set")
            case .usedPlateCalculator: String(localized: "Used plate calculator")
            case .usedEffortChip: String(localized: "Logged effort")
            }
        }
    }

    /// Tools a lifter can reach for mid-entry, reported by the surfaces that own
    /// them. Distinct from `SetEntryScenario` so a call site names the action it
    /// performed rather than a classification.
    enum SetEntryTool: Sendable {
        case copyLastSet
        case plateCalculator
        case effortChip

        var scenario: SetEntryScenario {
            switch self {
            case .copyLastSet: .usedCopyLastSet
            case .plateCalculator: .usedPlateCalculator
            case .effortChip: .usedEffortChip
            }
        }
    }

    private struct StoredMetrics: Codable {
        var buildNumber: String
        var entryDurationBuckets: [Int]
        /// Per-scenario buckets, same shape as `entryDurationBuckets`. Optional so
        /// a payload written by an earlier build still decodes — a missing key
        /// means "this build had not started measuring scenarios", which is
        /// different from "every scenario had zero samples".
        var scenarioDurationBuckets: [String: [Int]]?
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
    /// Scenario evidence for the entry in progress, cleared with the entry. Held
    /// in memory only — none of it is persisted per set, only folded into the
    /// aggregate buckets when the set completes.
    private var fieldsTouchedDuringEntry: Set<SetInputFocus.Field> = []
    private var toolsUsedDuringEntry: Set<SetEntryScenario> = []
    private var didOverwriteDuringEntry = false
    private var didArriveWithValuesDuringEntry = false

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
            discardedCount: stored.discardedCount,
            scenarioMedians: scenarioMedians.map {
                Snapshot.ScenarioMedian(
                    scenario: $0.scenario,
                    sampleCount: $0.sampleCount,
                    medianSeconds: $0.medianSeconds
                )
            }
        )
    }

    func focusChanged(to setID: UUID, field: SetInputFocus.Field, replacesExistingValue: Bool) {
        guard isEnabled else { return }

        if activeSetID != setID {
            activeSetID = setID
            activeSetStartedAt = monotonicTime()
            beginScenarioEvidence()
        }
        // The first focus of an entry tells us whether the lifter arrived to a set
        // that already held values; a later one only tells us where they moved.
        if fieldsTouchedDuringEntry.isEmpty {
            didArriveWithValuesDuringEntry = replacesExistingValue
        }
        fieldsTouchedDuringEntry.insert(field)
        focusedField = FocusedField(
            setID: setID,
            field: field,
            replacesExistingValue: replacesExistingValue
        )
        recordedCorrectionForFocus = false
    }

    /// Reported by the surface that owns the tool, so the recorder never has to
    /// guess from a value change what the lifter reached for.
    func toolUsed(_ tool: SetEntryTool) {
        guard isEnabled, activeSetID != nil else { return }
        toolsUsedDuringEntry.insert(tool.scenario)
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
        didOverwriteDuringEntry = true
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
            for scenario in scenariosForCurrentEntry() {
                record(bucket: bucket, in: scenario)
            }
            persist()
        }
        activeSetID = nil
        activeSetStartedAt = nil
        focusedField = nil
        recordedCorrectionForFocus = false
        beginScenarioEvidence()
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
        beginScenarioEvidence()
        stored = StoredMetrics(buildNumber: buildNumber)
        defaults.removeObject(forKey: Self.storageKey)
    }

    private var medianSetEntrySeconds: Int? {
        Self.median(of: stored.entryDurationBuckets)
    }

    /// One median per scenario that has at least one sample. Scenarios with no
    /// samples are absent rather than reported as zero: "nobody used the plate
    /// calculator" and "the plate calculator is instant" are not the same finding.
    private var scenarioMedians: [(scenario: SetEntryScenario, sampleCount: Int, medianSeconds: Int)] {
        SetEntryScenario.allCases.compactMap { scenario in
            guard let buckets = stored.scenarioDurationBuckets?[scenario.rawValue] else { return nil }
            let count = buckets.reduce(0, +)
            guard count > 0, let median = Self.median(of: buckets) else { return nil }
            return (scenario, count, median)
        }
    }

    private static func median(of buckets: [Int]) -> Int? {
        let count = buckets.reduce(0, +)
        guard count > 0 else { return nil }
        let targetIndex = (count - 1) / 2
        var seen = 0
        for (seconds, bucketCount) in buckets.enumerated() {
            seen += bucketCount
            if seen > targetIndex { return seconds }
        }
        return nil
    }

    private func scenariosForCurrentEntry() -> Set<SetEntryScenario> {
        var scenarios = toolsUsedDuringEntry

        if fieldsTouchedDuringEntry.contains(.weight) {
            scenarios.insert(.weighted)
        }
        if fieldsTouchedDuringEntry.contains(.duration) {
            scenarios.insert(.duration)
        }
        if fieldsTouchedDuringEntry == [.repetitions] {
            scenarios.insert(.repsOnly)
        }
        if didOverwriteDuringEntry {
            scenarios.insert(.correction)
        } else if didArriveWithValuesDuringEntry {
            // Values were already present and survived untouched. That is the fast
            // path the five-second target most depends on, so it is worth its own
            // median rather than being averaged in with fresh entry.
            scenarios.insert(.prefilledAccepted)
        }
        return scenarios
    }

    private func record(bucket: Int, in scenario: SetEntryScenario) {
        var buckets = stored.scenarioDurationBuckets ?? [:]
        var scenarioBuckets = buckets[scenario.rawValue] ?? Array(repeating: 0, count: 121)
        guard scenarioBuckets.count == 121 else { return }
        scenarioBuckets[bucket] += 1
        buckets[scenario.rawValue] = scenarioBuckets
        stored.scenarioDurationBuckets = buckets
    }

    private func beginScenarioEvidence() {
        fieldsTouchedDuringEntry = []
        toolsUsedDuringEntry = []
        didOverwriteDuringEntry = false
        didArriveWithValuesDuringEntry = false
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

import Foundation
import SwiftData
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@MainActor
final class HealthKitIntegrationTests: XCTestCase {
    func testResetDeletesStandaloneHealthKitProvenanceAndReceipts() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(HealthKitBodyMassProvenance(
            healthKitSampleID: UUID().uuidString,
            bodyWeightEntryID: UUID(),
            sourceBundleIdentifier: "com.example.health",
            sampleStartDate: now,
            sampleEndDate: now,
            valueKilograms: 80
        ))
        context.insert(HealthKitWorkoutExportReceipt(
            workoutID: UUID(),
            status: .failed,
            workoutStartDate: now,
            workoutEndDate: now,
            completedExerciseCount: 0,
            completedSetCount: 0
        ))
        try context.save()

        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<HealthKitBodyMassProvenance>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HealthKitWorkoutExportReceipt>()).isEmpty)
    }

    func testWorkoutExportPreferenceIsOptInAndPersistsExplicitChoice() throws {
        let suiteName = "HealthKitIntegrationTests.export-preference.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(HealthKitWorkoutExportPreference.isEnabled(in: defaults))
        defaults.set(true, forKey: DefaultsKey.healthKitWorkoutExportEnabled)
        XCTAssertTrue(HealthKitWorkoutExportPreference.isEnabled(in: defaults))
        defaults.set(false, forKey: DefaultsKey.healthKitWorkoutExportEnabled)
        XCTAssertFalse(HealthKitWorkoutExportPreference.isEnabled(in: defaults))
    }

    func testPreviewDeduplicatesSamplesAndNeverOverwritesAuthoredSameDayWeight() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let authored = BodyWeightEntry(
            day: LocalDay(rawValue: "2026-01-02"),
            value: 80,
            unit: .kg,
            source: .settings,
            measuredAt: date("2026-01-02T08:00:00Z")
        )
        let imported = BodyWeightEntry(
            day: LocalDay(rawValue: "2026-01-03"),
            value: 81,
            unit: .kg,
            source: .healthKit,
            measuredAt: date("2026-01-03T08:00:00Z")
        )
        let existingSample = sample(id: "existing-sample", day: "2026-01-03", value: 81)
        let provenance = HealthKitBodyMassProvenance(
            healthKitSampleID: existingSample.sampleID.uuidString,
            bodyWeightEntryID: imported.id,
            sourceBundleIdentifier: "com.example.health",
            sampleStartDate: imported.measuredAt,
            sampleEndDate: imported.measuredAt,
            valueKilograms: 81
        )
        context.insert(authored)
        context.insert(imported)
        context.insert(provenance)

        let samples = [
            sample(id: "authored-sample", day: "2026-01-02", value: 79),
            existingSample,
            sample(id: "new-sample", day: "2026-01-04", value: 82)
        ]
        let preview = HealthKitBodyMassImportService.preview(
            samples: samples,
            existingEntries: [authored, imported],
            existingProvenance: [provenance],
            calendar: utcCalendar
        )

        XCTAssertEqual(preview.items.map(\.status), [
            .sameDayUserAuthored(existingEntryID: authored.id),
            .duplicateSample,
            .addition
        ])
        XCTAssertEqual(preview.importableItems.count, 1)
        XCTAssertEqual(authored.value, 80)
    }

    func testApplyPersistsHealthKitSourceAndProvenanceWithoutDetailedWorkoutTruth() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sample = sample(id: "new-sample", day: "2026-01-04", value: 82)
        let preview = HealthKitBodyMassImportService.preview(
            samples: [sample],
            existingEntries: [],
            existingProvenance: [],
            calendar: utcCalendar
        )

        let insertedIDs = try HealthKitBodyMassImportService.apply(
            importPreview: preview,
            to: context,
            importedAt: date("2026-01-04T09:00:00Z")
        )
        let entries = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let provenance = try context.fetch(FetchDescriptor<HealthKitBodyMassProvenance>())

        XCTAssertEqual(insertedIDs.count, 1)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, .healthKit)
        XCTAssertEqual(try XCTUnwrap(entries.first?.kilograms), 82, accuracy: 0.001)
        XCTAssertEqual(provenance.count, 1)
        XCTAssertEqual(provenance.first?.healthKitSampleID, sample.sampleID.uuidString)
        XCTAssertEqual(provenance.first?.bodyWeightEntryID, entries.first?.id)
    }

    func testAuthorizationIsOnlyRequestedThroughExplicitAuthorizationService() async throws {
        let recorder = AdapterRecorder()
        let adapter = TestHealthKitAdapter(recorder: recorder)

        XCTAssertEqual(recorder.authorizationCalls, 0)
        try await HealthKitAuthorizationService.requestAuthorization(using: adapter)
        XCTAssertEqual(recorder.authorizationCalls, 1)
    }

    func testWorkoutExportPersistsReceiptOnlyAfterCallerProvidesCommittedSummary() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let recorder = AdapterRecorder()
        let adapter = TestHealthKitAdapter(recorder: recorder)
        let summary = HealthKitWorkoutSummary(
            workoutID: UUID(),
            name: "Committed session",
            startDate: date("2026-01-05T10:00:00Z"),
            endDate: date("2026-01-05T11:00:00Z"),
            completedExerciseCount: 2,
            completedSetCount: 6
        )

        await HealthKitWorkoutExportService.exportAfterCommittedSave(
            summary: summary,
            adapter: adapter,
            context: context,
            attemptedAt: date("2026-01-05T11:01:00Z")
        )

        let receipts = try context.fetch(FetchDescriptor<HealthKitWorkoutExportReceipt>())
        XCTAssertEqual(recorder.exportedSummaries, [summary])
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts.first?.status, .exported)
        XCTAssertEqual(receipts.first?.completedSetCount, 6)

        await HealthKitWorkoutExportService.exportAfterCommittedSave(
            summary: summary,
            adapter: adapter,
            context: context
        )
        XCTAssertEqual(recorder.exportedSummaries.count, 1)
    }

    private let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func sample(id: String, day: String, value: Double) -> HealthKitBodyMassSample {
        let start = date("\(day)T08:00:00Z")
        let sampleID: UUID = switch id {
        case "authored-sample": UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case "existing-sample": UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        case "new-sample": UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        default: UUID()
        }
        return HealthKitBodyMassSample(
            sampleID: sampleID,
            valueKilograms: value,
            startDate: start,
            endDate: start,
            sourceRevision: HealthKitSourceRevision(bundleIdentifier: "com.example.health", version: "1", productType: "iPhone")
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter.date(from: value)!
    }
}

private final class AdapterRecorder: @unchecked Sendable {
    var authorizationCalls = 0
    var exportedSummaries: [HealthKitWorkoutSummary] = []
}

private struct TestHealthKitAdapter: HealthKitAdapter {
    let recorder: AdapterRecorder

    func requestAuthorization() async throws {
        recorder.authorizationCalls += 1
    }

    func readBodyMassSamples(from startDate: Date, through endDate: Date) async throws -> [HealthKitBodyMassSample] {
        []
    }

    func exportWorkoutSummary(_ summary: HealthKitWorkoutSummary) async throws -> HealthKitWorkoutExportResult {
        recorder.exportedSummaries.append(summary)
        return HealthKitWorkoutExportResult(healthKitWorkoutID: UUID())
    }
}

#endif

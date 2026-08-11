import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

#if canImport(HealthKit)
import HealthKit
#endif

struct HealthKitSourceRevision: Equatable, Hashable, Sendable {
    let bundleIdentifier: String
    let version: String?
    let productType: String?
}

struct HealthKitBodyMassSample: Equatable, Hashable, Sendable {
    let sampleID: UUID
    let externalID: String
    let valueKilograms: Double
    let startDate: Date
    let endDate: Date
    let sourceRevision: HealthKitSourceRevision

    var id: String { externalID }
    var kilograms: Double { valueKilograms }

    init(
        sampleID: UUID,
        valueKilograms: Double,
        startDate: Date,
        endDate: Date,
        sourceRevision: HealthKitSourceRevision
    ) {
        self.sampleID = sampleID
        self.externalID = sampleID.uuidString
        self.valueKilograms = valueKilograms
        self.startDate = startDate
        self.endDate = endDate
        self.sourceRevision = sourceRevision
    }

    /// Compatibility initializer for deterministic adapters that use a stable
    /// provider identifier rather than a UUID-shaped fixture value.
    init(
        id: String,
        startDate: Date,
        endDate: Date,
        kilograms: Double,
        sourceBundleIdentifier: String,
        sourceVersion: String?,
        sourceProductType: String?
    ) {
        self.sampleID = UUID(uuidString: id) ?? UUID()
        self.externalID = id
        self.valueKilograms = kilograms
        self.startDate = startDate
        self.endDate = endDate
        self.sourceRevision = HealthKitSourceRevision(
            bundleIdentifier: sourceBundleIdentifier,
            version: sourceVersion,
            productType: sourceProductType
        )
    }
}

struct HealthKitWorkoutSummary: Equatable, Hashable, Sendable {
    let workoutID: UUID
    let name: String?
    let startDate: Date
    let endDate: Date
    let completedExerciseCount: Int
    let completedSetCount: Int
}

struct HealthKitWorkoutExportResult: Equatable, Hashable, Sendable {
    let healthKitWorkoutID: UUID
}

enum HealthKitAuthorizationState: String, Equatable, Sendable {
    case notRequested
    case authorized
    case denied
    case unavailable
}

enum HealthKitWorkoutExportPreference {
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.healthKitWorkoutExportEnabled)
    }
}

enum HealthKitIntegrationError: Error, Equatable, LocalizedError, Sendable {
    case unavailable
    case authorizationRequired
    case noBodyMassType
    case noWorkoutType
    case invalidSample(UUID)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "Health data is unavailable on this device."
        case .authorizationRequired: "Health access must be explicitly authorized before this operation."
        case .noBodyMassType: "Body-mass data is unavailable on this OS."
        case .noWorkoutType: "Workout data is unavailable on this OS."
        case .invalidSample(let id): "HealthKit returned an invalid body-mass sample \(id.uuidString)."
        case .exportFailed(let message): "The workout summary could not be exported: \(message)"
        }
    }
}

/// The application owns the authorization moment. Import and export methods
/// never call `requestAuthorization` implicitly, which keeps permission
/// prompts user-triggered and deterministic in tests.
protocol HealthKitAdapter: Sendable {
    func requestAuthorization() async throws
    func requestBodyMassAuthorization() async throws
    func workoutAuthorizationState() async -> HealthKitAuthorizationState
    func readBodyMassSamples(from startDate: Date, through endDate: Date) async throws -> [HealthKitBodyMassSample]
    func exportWorkoutSummary(_ summary: HealthKitWorkoutSummary) async throws -> HealthKitWorkoutExportResult
}

extension HealthKitAdapter {
    /// Test and legacy adapters can use their existing authorization hook;
    /// the live adapter below overrides this with a body-mass-only request.
    func requestBodyMassAuthorization() async throws {
        try await requestAuthorization()
    }

    func workoutAuthorizationState() async -> HealthKitAuthorizationState { .authorized }
}

enum HealthKitAuthorizationService {
    /// Call only from an explicit user action. No import/export path invokes
    /// this helper implicitly.
    static func requestAuthorization(using adapter: any HealthKitAdapter) async throws {
        try await adapter.requestAuthorization()
    }

    static func requestBodyMassAuthorization(using adapter: any HealthKitAdapter) async throws {
        try await adapter.requestBodyMassAuthorization()
    }
}

struct UnavailableHealthKitAdapter: HealthKitAdapter {
    func requestAuthorization() async throws { throw HealthKitIntegrationError.unavailable }

    func workoutAuthorizationState() async -> HealthKitAuthorizationState { .unavailable }

    func readBodyMassSamples(from startDate: Date, through endDate: Date) async throws -> [HealthKitBodyMassSample] {
        throw HealthKitIntegrationError.unavailable
    }

    func exportWorkoutSummary(_ summary: HealthKitWorkoutSummary) async throws -> HealthKitWorkoutExportResult {
        throw HealthKitIntegrationError.unavailable
    }
}

#if canImport(HealthKit)

/// Thin production adapter. It maps HealthKit into value snapshots and never
/// exposes HKQuantitySample/HKWorkout to the local domain.
final class LiveHealthKitAdapter: HealthKitAdapter, @unchecked Sendable {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitIntegrationError.unavailable
        }
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitIntegrationError.noBodyMassType
        }
        let workoutType = HKObjectType.workoutType()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [workoutType], read: [bodyMassType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitIntegrationError.authorizationRequired)
                }
            }
        }
    }

    func requestBodyMassAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitIntegrationError.unavailable
        }
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitIntegrationError.noBodyMassType
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: [bodyMassType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitIntegrationError.authorizationRequired)
                }
            }
        }
    }

    func workoutAuthorizationState() async -> HealthKitAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        default: return .notRequested
        }
    }

    func readBodyMassSamples(from startDate: Date, through endDate: Date) async throws -> [HealthKitBodyMassSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitIntegrationError.unavailable
        }
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitIntegrationError.noBodyMassType
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HealthKitBodyMassSample], Error>) in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let mapped = (samples as? [HKQuantitySample] ?? []).compactMap { sample -> HealthKitBodyMassSample? in
                    let kilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    guard kilograms.isFinite, kilograms > 0 else { return nil }
                    return HealthKitBodyMassSample(
                        sampleID: sample.uuid,
                        valueKilograms: kilograms,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        sourceRevision: HealthKitSourceRevision(
                            bundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
                            version: sample.sourceRevision.version,
                            productType: sample.sourceRevision.productType
                        )
                    )
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    func exportWorkoutSummary(_ summary: HealthKitWorkoutSummary) async throws -> HealthKitWorkoutExportResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitIntegrationError.unavailable
        }
        let metadata: [String: Any] = [
            "GymTrackerWorkoutID": summary.workoutID.uuidString,
            "GymTrackerCompletedExerciseCount": summary.completedExerciseCount,
            "GymTrackerCompletedSetCount": summary.completedSetCount,
            HKMetadataKeyIndoorWorkout: true
        ]
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: summary.startDate,
            end: summary.endDate,
            duration: max(0, summary.endDate.timeIntervalSince(summary.startDate)),
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(workout) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitIntegrationError.exportFailed("HealthKit rejected the summary."))
                }
            }
        }
        return HealthKitWorkoutExportResult(healthKitWorkoutID: workout.uuid)
    }
}

typealias SystemHealthKitBodyMassProvider = LiveHealthKitAdapter

#endif

enum HealthKitBodyMassImportStatus: Equatable, Sendable {
    case addition
    case duplicateSample
    case sameDayUserAuthored(existingEntryID: UUID)
    case sameDayImported
}

struct HealthKitBodyMassImportItem: Equatable, Sendable {
    let sample: HealthKitBodyMassSample
    let dayKey: String
    let status: HealthKitBodyMassImportStatus
}

struct HealthKitBodyMassImportPreview: Equatable, Sendable {
    let items: [HealthKitBodyMassImportItem]

    var importableItems: [HealthKitBodyMassImportItem] {
        items.filter { $0.status == .addition }
    }
}

struct HealthKitBodyMassImportSummary: Equatable, Sendable {
    let importedCount: Int
    let updatedCount: Int
    let skippedAuthoredCount: Int
    let unchangedCount: Int
}

enum HealthKitBodyMassImportError: Error, Equatable, LocalizedError, Sendable {
    case unavailable
    case authorizationRequired
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "Apple Health is unavailable on this device."
        case .authorizationRequired: "Apple Health access is required before importing body mass."
        case .failed(let message): message
        }
    }
}

struct HealthKitBodyMassImportService {
    let modelContext: ModelContext
    let provider: any HealthKitAdapter

    init(modelContext: ModelContext, provider: any HealthKitAdapter) {
        self.modelContext = modelContext
        self.provider = provider
    }

    @MainActor
    func importBodyMass(now: Date = .now) async throws -> HealthKitBodyMassImportSummary {
        do {
            try await HealthKitAuthorizationService.requestBodyMassAuthorization(using: provider)
            let start = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now.addingTimeInterval(-31_536_000)
            let samples = try await provider.readBodyMassSamples(from: start, through: now)
            let entries = try modelContext.fetch(FetchDescriptor<BodyWeightEntry>())
            let provenance = try modelContext.fetch(FetchDescriptor<HealthKitBodyMassProvenance>())
            let preview = Self.preview(samples: samples, existingEntries: entries, existingProvenance: provenance)
            let imported = try Self.apply(importPreview: preview, to: modelContext, importedAt: now).count
            let authored = preview.items.filter {
                if case .sameDayUserAuthored = $0.status { return true }
                return false
            }.count
            let unchanged = preview.items.filter {
                if case .duplicateSample = $0.status { return true }
                return false
            }.count
            return HealthKitBodyMassImportSummary(
                importedCount: imported,
                updatedCount: 0,
                skippedAuthoredCount: authored,
                unchangedCount: unchanged
            )
        } catch let error as HealthKitIntegrationError {
            switch error {
            case .unavailable: throw HealthKitBodyMassImportError.unavailable
            case .authorizationRequired: throw HealthKitBodyMassImportError.authorizationRequired
            default: throw HealthKitBodyMassImportError.failed(error.localizedDescription)
            }
        } catch let error as HealthKitBodyMassImportError {
            throw error
        } catch {
            throw HealthKitBodyMassImportError.failed(error.localizedDescription)
        }
    }

    static func preview(
        samples: [HealthKitBodyMassSample],
        existingEntries: [BodyWeightEntry],
        existingProvenance: [HealthKitBodyMassProvenance],
        calendar: Calendar = .current
    ) -> HealthKitBodyMassImportPreview {
        var seenSampleIDs = Set(existingProvenance.map(\.healthKitSampleID))
        var importedDays = Set(existingEntries.filter { $0.source == .healthKit }.map(\.dayKey))
        var authoredDays = Set(existingEntries.filter { $0.source != .healthKit }.map(\.dayKey))
        var items: [HealthKitBodyMassImportItem] = []

        for sample in samples.sorted(by: { $0.startDate == $1.startDate ? $0.sampleID.uuidString < $1.sampleID.uuidString : $0.startDate < $1.startDate }) {
            let dayKey = LocalDay(date: sample.startDate, calendar: calendar).rawValue
            let status: HealthKitBodyMassImportStatus
            if !seenSampleIDs.insert(sample.sampleID.uuidString).inserted {
                status = .duplicateSample
            } else if let authored = existingEntries.first(where: { $0.dayKey == dayKey && $0.source != .healthKit }) {
                status = .sameDayUserAuthored(existingEntryID: authored.id)
                authoredDays.insert(dayKey)
            } else if let imported = existingEntries.first(where: { $0.dayKey == dayKey && $0.source == .healthKit }) {
                status = .sameDayImported
                importedDays.insert(dayKey)
            } else if authoredDays.contains(dayKey) {
                let authored = existingEntries.first(where: { $0.dayKey == dayKey && $0.source != .healthKit })
                status = .sameDayUserAuthored(existingEntryID: authored?.id ?? UUID())
            } else if importedDays.contains(dayKey) {
                status = .sameDayImported
            } else {
                status = .addition
                importedDays.insert(dayKey)
            }
            items.append(HealthKitBodyMassImportItem(sample: sample, dayKey: dayKey, status: status))
        }
        return HealthKitBodyMassImportPreview(items: items)
    }

    @MainActor
    static func apply(
        importPreview: HealthKitBodyMassImportPreview,
        to context: ModelContext,
        importedAt: Date = .now
    ) throws -> [UUID] {
        let entries = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let provenance = try context.fetch(FetchDescriptor<HealthKitBodyMassProvenance>())
        let current = Self.preview(samples: importPreview.items.map(\.sample), existingEntries: entries, existingProvenance: provenance)
        var insertedIDs: [UUID] = []
        for item in current.importableItems {
            let entry = BodyWeightEntry(
                day: LocalDay(rawValue: item.dayKey),
                value: Float(item.sample.valueKilograms),
                unit: .kg,
                source: .healthKit,
                measuredAt: item.sample.endDate,
                createdAt: importedAt,
                updatedAt: importedAt
            )
            let provenance = HealthKitBodyMassProvenance(
                healthKitSampleID: item.sample.sampleID.uuidString,
                bodyWeightEntryID: entry.id,
                sourceBundleIdentifier: item.sample.sourceRevision.bundleIdentifier,
                sourceVersion: item.sample.sourceRevision.version,
                sourceProductType: item.sample.sourceRevision.productType,
                sampleStartDate: item.sample.startDate,
                sampleEndDate: item.sample.endDate,
                valueKilograms: item.sample.valueKilograms,
                importedAt: importedAt,
                lastSeenAt: importedAt
            )
            context.insert(entry)
            context.insert(provenance)
            insertedIDs.append(entry.id)
        }
        try context.save()
        return insertedIDs
    }
}

struct HealthKitBodyMassExistingEntry: Equatable, Sendable {
    let id: UUID
    let dayKey: String
    let source: BodyWeightSource
}

struct HealthKitBodyMassExistingProvenance: Equatable, Sendable {
    let sampleID: String
    let entryID: UUID
}

enum HealthKitBodyMassImportDecision: Equatable, Sendable {
    case insert(HealthKitBodyMassSample)
    case skipAuthored(UUID, HealthKitBodyMassSample)
    case unchanged(entryID: UUID, sampleID: String)
}

struct HealthKitBodyMassImportPlan: Equatable, Sendable {
    let decisions: [HealthKitBodyMassImportDecision]
    let invalidSampleCount: Int
}

struct HealthKitBodyMassImportPlanner: Sendable {
    let calendar: Calendar

    func plan(
        samples: [HealthKitBodyMassSample],
        entries: [HealthKitBodyMassExistingEntry],
        provenance: [HealthKitBodyMassExistingProvenance]
    ) -> HealthKitBodyMassImportPlan {
        let valid = samples.filter { $0.kilograms.isFinite && $0.kilograms > 0 }
        let latestByDay = Dictionary(grouping: valid, by: { LocalDay(date: $0.startDate, calendar: calendar).rawValue })
            .compactMapValues { $0.max { lhs, rhs in lhs.startDate == rhs.startDate ? lhs.id < rhs.id : lhs.startDate < rhs.startDate } }
        var decisions: [HealthKitBodyMassImportDecision] = []
        for sample in latestByDay.values.sorted(by: { $0.startDate < $1.startDate }) {
            if let known = provenance.first(where: { $0.sampleID == sample.id }) {
                decisions.append(.unchanged(entryID: known.entryID, sampleID: sample.id))
            } else {
                let dayKey = LocalDay(date: sample.startDate, calendar: calendar).rawValue
                if let authored = entries.first(where: { $0.dayKey == dayKey && $0.source != .healthKit }) {
                    decisions.append(.skipAuthored(authored.id, sample))
                } else {
                    decisions.append(.insert(sample))
                }
            }
        }
        return HealthKitBodyMassImportPlan(decisions: decisions, invalidSampleCount: samples.count - valid.count)
    }
}

enum HealthKitWorkoutExportService {
    @MainActor
    static func exportAfterCommittedSave(
        summary: HealthKitWorkoutSummary,
        adapter: any HealthKitAdapter,
        context: ModelContext,
        attemptedAt: Date = .now
    ) async {
        let existing = (try? context.fetch(FetchDescriptor<HealthKitWorkoutExportReceipt>()))?.first { $0.workoutID == summary.workoutID }
        if existing?.status == .exported { return }

        guard await adapter.workoutAuthorizationState() == .authorized else {
            let receipt = existing ?? HealthKitWorkoutExportReceipt(
                workoutID: summary.workoutID,
                status: .skippedNotAuthorized,
                attemptedAt: attemptedAt,
                workoutStartDate: summary.startDate,
                workoutEndDate: summary.endDate,
                completedExerciseCount: summary.completedExerciseCount,
                completedSetCount: summary.completedSetCount,
                errorMessage: HealthKitIntegrationError.authorizationRequired.localizedDescription
            )
            receipt.status = .skippedNotAuthorized
            receipt.attemptedAt = attemptedAt
            receipt.errorMessage = HealthKitIntegrationError.authorizationRequired.localizedDescription
            if existing == nil { context.insert(receipt) }
            try? context.save()
            return
        }

        do {
            let result = try await adapter.exportWorkoutSummary(summary)
            let receipt = existing ?? HealthKitWorkoutExportReceipt(
                workoutID: summary.workoutID,
                status: .exported,
                attemptedAt: attemptedAt,
                workoutStartDate: summary.startDate,
                workoutEndDate: summary.endDate,
                completedExerciseCount: summary.completedExerciseCount,
                completedSetCount: summary.completedSetCount
            )
            receipt.healthKitWorkoutID = result.healthKitWorkoutID.uuidString
            receipt.status = .exported
            receipt.attemptedAt = attemptedAt
            receipt.errorMessage = nil
            if existing == nil { context.insert(receipt) }
        } catch {
            let receipt = existing ?? HealthKitWorkoutExportReceipt(
                workoutID: summary.workoutID,
                status: .failed,
                attemptedAt: attemptedAt,
                workoutStartDate: summary.startDate,
                workoutEndDate: summary.endDate,
                completedExerciseCount: summary.completedExerciseCount,
                completedSetCount: summary.completedSetCount
            )
            receipt.status = .failed
            receipt.attemptedAt = attemptedAt
            receipt.errorMessage = error.localizedDescription
            if existing == nil { context.insert(receipt) }
        }
        do {
            try context.save()
        } catch {
            print("HealthKitWorkoutExportService: receipt persistence failed: \(error)")
        }
    }
}

#endif

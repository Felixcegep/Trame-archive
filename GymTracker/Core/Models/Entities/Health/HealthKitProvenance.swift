import Foundation
import SwiftData

/// Durable provenance for one imported HealthKit body-mass sample. The
/// original BodyWeightEntry remains the value used by existing local views;
/// this record preserves the external object identity and source revision so
/// a later import can deduplicate without replacing authored observations.
@Model
final class HealthKitBodyMassProvenance {
    @Attribute(.unique) var healthKitSampleID: String
    var id: UUID
    var bodyWeightEntryID: UUID
    var sourceBundleIdentifier: String
    var sourceVersion: String?
    var sourceProductType: String?
    var sampleStartDate: Date
    var sampleEndDate: Date
    var valueKilograms: Double
    var importedAt: Date
    var lastSeenAt: Date

    init(
        healthKitSampleID: String,
        bodyWeightEntryID: UUID,
        sourceBundleIdentifier: String,
        sourceVersion: String? = nil,
        sourceProductType: String? = nil,
        sampleStartDate: Date,
        sampleEndDate: Date,
        valueKilograms: Double,
        importedAt: Date = .now,
        lastSeenAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.healthKitSampleID = healthKitSampleID
        self.id = id
        self.bodyWeightEntryID = bodyWeightEntryID
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceVersion = sourceVersion
        self.sourceProductType = sourceProductType
        self.sampleStartDate = sampleStartDate
        self.sampleEndDate = sampleEndDate
        self.valueKilograms = valueKilograms
        self.importedAt = importedAt
        self.lastSeenAt = lastSeenAt
    }
}

enum HealthKitWorkoutExportStatus: String, Codable, CaseIterable, Sendable {
    case exported
    case skippedNotAuthorized
    case failed
}

/// One idempotent attempt to publish a completed workout summary. This is
/// receipt/provenance only; it never stores detailed exercise or set truth.
@Model
final class HealthKitWorkoutExportReceipt {
    @Attribute(.unique) var workoutID: UUID
    var id: UUID
    var healthKitWorkoutID: String?
    var statusRaw: String
    var attemptedAt: Date
    var workoutStartDate: Date
    var workoutEndDate: Date
    var completedExerciseCount: Int
    var completedSetCount: Int
    var errorMessage: String?

    var status: HealthKitWorkoutExportStatus {
        get { HealthKitWorkoutExportStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        workoutID: UUID,
        healthKitWorkoutID: String? = nil,
        status: HealthKitWorkoutExportStatus,
        attemptedAt: Date = .now,
        workoutStartDate: Date,
        workoutEndDate: Date,
        completedExerciseCount: Int,
        completedSetCount: Int,
        errorMessage: String? = nil,
        id: UUID = UUID()
    ) {
        self.workoutID = workoutID
        self.id = id
        self.healthKitWorkoutID = healthKitWorkoutID
        self.statusRaw = status.rawValue
        self.attemptedAt = attemptedAt
        self.workoutStartDate = workoutStartDate
        self.workoutEndDate = workoutEndDate
        self.completedExerciseCount = completedExerciseCount
        self.completedSetCount = completedSetCount
        self.errorMessage = errorMessage
    }
}

import CryptoKit
import Foundation
import SwiftData

/// A recovered program listing whose source contains useful discovery facts
/// but no trustworthy structured prescription. It is deliberately not a
/// `ProgramDefinitionRecord`: it cannot be compiled, scheduled, or started.
enum ProgramDiscoveryAvailabilityReason: String, Codable, CaseIterable, Sendable {
    case structuredPrescriptionUnavailable
}

/// Why a recovered listing is not available to the current executable
/// Program Engine. This distinction prevents missing source structure from
/// being misreported as an engine limitation.
enum ProgramDiscoveryCompatibilityStatus: String, Codable, CaseIterable, Sendable {
    case incompleteRecovery
    case unsupportedEngineCapability
}

@Model
final class ProgramDiscoverySeed {
    /// The recovered slug is the durable identity across resource refreshes.
    @Attribute(.unique) var programKey: String
    var id: UUID
    var name: String
    var summary: String?
    var authorOrOrigin: String?
    var categoryOrDisciplineLabel: String?
    var daysPerWeekText: String?
    var durationWeeksText: String?
    var difficultyLabel: String?
    var progressionModelLabel: String?
    var equipmentText: String?
    var tags: [String]
    var sourceURLString: String?
    var imageURLString: String?
    var availabilityReasonRaw: String
    var compatibilityStatusRaw: String
    var compatibilityReason: String
    var isRunnable: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        programKey: String,
        name: String,
        summary: String? = nil,
        authorOrOrigin: String? = nil,
        categoryOrDisciplineLabel: String? = nil,
        daysPerWeekText: String? = nil,
        durationWeeksText: String? = nil,
        difficultyLabel: String? = nil,
        progressionModelLabel: String? = nil,
        equipmentText: String? = nil,
        tags: [String] = [],
        sourceURLString: String? = nil,
        imageURLString: String? = nil,
        availabilityReason: ProgramDiscoveryAvailabilityReason = .structuredPrescriptionUnavailable,
        compatibilityStatus: ProgramDiscoveryCompatibilityStatus = .incompleteRecovery,
        compatibilityReason: String = "Recovered metadata does not include a trustworthy structured day/set/rep prescription.",
        id: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.programKey = programKey
        self.id = id ?? Self.stableID(for: programKey)
        self.name = name
        self.summary = summary
        self.authorOrOrigin = authorOrOrigin
        self.categoryOrDisciplineLabel = categoryOrDisciplineLabel
        self.daysPerWeekText = daysPerWeekText
        self.durationWeeksText = durationWeeksText
        self.difficultyLabel = difficultyLabel
        self.progressionModelLabel = progressionModelLabel
        self.equipmentText = equipmentText
        self.tags = tags
        self.sourceURLString = sourceURLString
        self.imageURLString = imageURLString
        self.availabilityReasonRaw = availabilityReason.rawValue
        self.compatibilityStatusRaw = compatibilityStatus.rawValue
        self.compatibilityReason = compatibilityReason
        self.isRunnable = false
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var availabilityReason: ProgramDiscoveryAvailabilityReason {
        get {
            ProgramDiscoveryAvailabilityReason(rawValue: availabilityReasonRaw)
                ?? .structuredPrescriptionUnavailable
        }
        set { availabilityReasonRaw = newValue.rawValue }
    }

    var compatibilityStatus: ProgramDiscoveryCompatibilityStatus {
        get {
            ProgramDiscoveryCompatibilityStatus(rawValue: compatibilityStatusRaw)
                ?? .incompleteRecovery
        }
        set { compatibilityStatusRaw = newValue.rawValue }
    }

    /// Stable UUIDs make backup diffs, imports, and resource refreshes
    /// deterministic while keeping this listing independent of executable
    /// program-definition identities.
    static func stableID(for programKey: String) -> UUID {
        let digest = Array(SHA256.hash(data: Data("program-discovery|\(programKey)".utf8)).prefix(16))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return UUID(uuidString: "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))")!
    }
}

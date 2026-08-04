import Foundation
import SwiftData

@Model
final class MobilityAssessmentDefinition {
    var id: UUID
    var catalogueKey: String
    var name: String
    var nameLocalizationKey: String
    var instructionsLocalizationKey: String
    var setupInstructionsLocalizationKey: String
    var measurementDescriptionLocalizationKey: String
    var measurementLimitationsLocalizationKey: String
    var zoneRaw: String
    var definitionVersion: Int
    var preferredModeRaw: String
    var manualModeRaw: String
    var unitRaw: String
    var supportedSideRaws: [String]
    var setupKeys: [String]
    var defaultSetupKey: String
    var defaultIsActiveRange: Bool
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var zone: MobilityAssessmentZone {
        get { MobilityAssessmentZone(rawValue: zoneRaw) ?? .hips }
        set { zoneRaw = newValue.rawValue }
    }

    var preferredMode: MobilityMeasurementMode {
        get { MobilityMeasurementMode(rawValue: preferredModeRaw) ?? .manualAngle }
        set { preferredModeRaw = newValue.rawValue }
    }

    var manualMode: MobilityMeasurementMode {
        get { MobilityMeasurementMode(rawValue: manualModeRaw) ?? .manualAngle }
        set { manualModeRaw = newValue.rawValue }
    }

    var unit: MobilityMeasurementUnit {
        get { MobilityMeasurementUnit(rawValue: unitRaw) ?? .degrees }
        set { unitRaw = newValue.rawValue }
    }

    var supportedSides: [MobilityAssessmentSide] {
        get { supportedSideRaws.compactMap(MobilityAssessmentSide.init(rawValue:)) }
        set { supportedSideRaws = newValue.map(\.rawValue) }
    }

    init(
        catalogueKey: String,
        name: String,
        nameLocalizationKey: String,
        instructionsLocalizationKey: String,
        setupInstructionsLocalizationKey: String,
        measurementDescriptionLocalizationKey: String,
        measurementLimitationsLocalizationKey: String,
        zone: MobilityAssessmentZone,
        definitionVersion: Int = 1,
        preferredMode: MobilityMeasurementMode,
        manualMode: MobilityMeasurementMode,
        unit: MobilityMeasurementUnit,
        supportedSides: [MobilityAssessmentSide],
        setupKeys: [String],
        defaultSetupKey: String,
        defaultIsActiveRange: Bool,
        sortOrder: Int,
        isArchived: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.catalogueKey = catalogueKey
        self.name = name
        self.nameLocalizationKey = nameLocalizationKey
        self.instructionsLocalizationKey = instructionsLocalizationKey
        self.setupInstructionsLocalizationKey = setupInstructionsLocalizationKey
        self.measurementDescriptionLocalizationKey = measurementDescriptionLocalizationKey
        self.measurementLimitationsLocalizationKey = measurementLimitationsLocalizationKey
        self.zoneRaw = zone.rawValue
        self.definitionVersion = definitionVersion
        self.preferredModeRaw = preferredMode.rawValue
        self.manualModeRaw = manualMode.rawValue
        self.unitRaw = unit.rawValue
        self.supportedSideRaws = supportedSides.map(\.rawValue)
        self.setupKeys = setupKeys
        self.defaultSetupKey = defaultSetupKey
        self.defaultIsActiveRange = defaultIsActiveRange
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

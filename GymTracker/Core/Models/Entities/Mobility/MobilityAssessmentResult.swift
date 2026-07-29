import Foundation
import SwiftData

@Model
final class MobilityAssessmentResult {
    var id: UUID
    var orderIndex: Int
    var numericValue: Double?
    var criteriaRaw: String?
    var sideRaw: String
    var isWarm: Bool
    var setupKey: String
    var methodRaw: String
    var unitRaw: String
    var isActiveRange: Bool
    var dayKey: String
    var sourceRaw: String
    var confidenceRaw: String
    var definitionIDSnapshot: UUID
    var definitionCatalogueKeySnapshot: String
    var definitionNameSnapshot: String
    var definitionVersionSnapshot: Int
    var instructionsLocalizationKeySnapshot: String
    var setupInstructionsLocalizationKeySnapshot: String
    var measurementDescriptionLocalizationKeySnapshot: String
    var measurementLimitationsLocalizationKeySnapshot: String
    var createdAt: Date
    var updatedAt: Date
    var session: MobilityAssessmentSession?
    @Relationship(deleteRule: .cascade, inverse: \MobilityAssessmentSample.result)
    var sample: MobilityAssessmentSample?

    var criteria: MobilityAssessmentCriteriaObservation? {
        get { criteriaRaw.flatMap(MobilityAssessmentCriteriaObservation.init(rawValue:)) }
        set { criteriaRaw = newValue?.rawValue }
    }

    var side: MobilityAssessmentSide {
        get { MobilityAssessmentSide(rawValue: sideRaw) ?? .combined }
        set { sideRaw = newValue.rawValue }
    }

    var method: MobilityMeasurementMode {
        get { MobilityMeasurementMode(rawValue: methodRaw) ?? .manualAngle }
        set { methodRaw = newValue.rawValue }
    }

    var unit: MobilityMeasurementUnit {
        get { MobilityMeasurementUnit(rawValue: unitRaw) ?? .degrees }
        set { unitRaw = newValue.rawValue }
    }

    var day: LocalDay {
        get { LocalDay(rawValue: dayKey) }
        set { dayKey = newValue.rawValue }
    }

    var source: MobilityMeasurementSource {
        get { MobilityMeasurementSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var confidence: MobilityMeasurementConfidence {
        get { MobilityMeasurementConfidence(rawValue: confidenceRaw) ?? .unknown }
        set { confidenceRaw = newValue.rawValue }
    }

    init(
        definition: MobilityAssessmentDefinition,
        input: MobilityAssessmentResultInput,
        orderIndex: Int,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.numericValue = input.numericValue
        self.criteriaRaw = input.criteria?.rawValue
        self.sideRaw = input.side.rawValue
        self.isWarm = input.isWarm
        self.setupKey = input.setupKey
        self.methodRaw = input.method.rawValue
        self.unitRaw = input.unit.rawValue
        self.isActiveRange = input.isActiveRange
        self.dayKey = input.day.rawValue
        self.sourceRaw = input.source.rawValue
        self.confidenceRaw = input.confidence.rawValue
        self.definitionIDSnapshot = definition.id
        self.definitionCatalogueKeySnapshot = definition.catalogueKey
        self.definitionNameSnapshot = definition.name
        self.definitionVersionSnapshot = definition.definitionVersion
        self.instructionsLocalizationKeySnapshot = definition.instructionsLocalizationKey
        self.setupInstructionsLocalizationKeySnapshot = definition.setupInstructionsLocalizationKey
        self.measurementDescriptionLocalizationKeySnapshot = definition.measurementDescriptionLocalizationKey
        self.measurementLimitationsLocalizationKeySnapshot = definition.measurementLimitationsLocalizationKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

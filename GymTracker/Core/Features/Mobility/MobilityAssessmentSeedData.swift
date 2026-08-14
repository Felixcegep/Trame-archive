import Foundation
import SwiftData

enum MobilityAssessmentSeedData {
    struct DefinitionSpec {
        let id: UUID
        let key: String
        let name: String
        let zone: MobilityAssessmentZone
        let preferredMode: MobilityMeasurementMode
        let manualMode: MobilityMeasurementMode
        let unit: MobilityMeasurementUnit
        let sides: [MobilityAssessmentSide]
        let setupKey: String
        let defaultIsActiveRange: Bool
        let sortOrder: Int

        var localizationStem: String {
            key.replacingOccurrences(of: "-", with: ".")
        }

        func makeDefinition() -> MobilityAssessmentDefinition {
            MobilityAssessmentDefinition(
                catalogueKey: key,
                name: name,
                nameLocalizationKey: "\(localizationStem).name",
                instructionsLocalizationKey: "\(localizationStem).instructions",
                setupInstructionsLocalizationKey: "\(localizationStem).setup",
                measurementDescriptionLocalizationKey: "\(localizationStem).measures",
                measurementLimitationsLocalizationKey: "\(localizationStem).limitations",
                zone: zone,
                definitionVersion: 1,
                preferredMode: preferredMode,
                manualMode: manualMode,
                unit: unit,
                supportedSides: sides,
                setupKeys: [setupKey],
                defaultSetupKey: setupKey,
                defaultIsActiveRange: defaultIsActiveRange,
                sortOrder: sortOrder,
                id: id
            )
        }
    }

    static let definitions: [DefinitionSpec] = [
        DefinitionSpec(
            id: UUID(uuidString: "3C000001-0000-4000-8000-000000000001")!,
            key: "mobility-assessment.thoracic-rotation-seated",
            name: "Thoracic rotation, seated",
            zone: .thorax,
            preferredMode: .axialRotation,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "seated-upright",
            defaultIsActiveRange: true,
            sortOrder: 0
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000002-0000-4000-8000-000000000002")!,
            key: "mobility-assessment.open-book-rotation",
            name: "Open-book rotation",
            zone: .thorax,
            preferredMode: .axialRotation,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "side-lying-knees-stacked",
            defaultIsActiveRange: false,
            sortOrder: 1
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000003-0000-4000-8000-000000000003")!,
            key: "mobility-assessment.active-straight-leg-raise",
            name: "Active straight-leg raise",
            zone: .posteriorChain,
            preferredMode: .inclinometer,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "supine-pelvis-neutral",
            defaultIsActiveRange: true,
            sortOrder: 2
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000004-0000-4000-8000-000000000004")!,
            key: "mobility-assessment.knee-to-wall-dorsiflexion",
            name: "Knee-to-wall dorsiflexion",
            zone: .ankles,
            preferredMode: .inclinometer,
            manualMode: .manualLinear,
            unit: .centimetres,
            sides: [.left, .right],
            setupKey: "foot-flat-heel-down",
            defaultIsActiveRange: true,
            sortOrder: 3
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000005-0000-4000-8000-000000000005")!,
            key: "mobility-assessment.soleus-wall-stretch",
            name: "Soleus wall stretch",
            zone: .ankles,
            preferredMode: .inclinometer,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "knee-bent-heel-down",
            defaultIsActiveRange: false,
            sortOrder: 4
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000006-0000-4000-8000-000000000006")!,
            key: "mobility-assessment.90-90-hip-rotation",
            name: "90/90 hip rotation",
            zone: .hips,
            preferredMode: .inclinometer,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "seated-90-90",
            defaultIsActiveRange: true,
            sortOrder: 5
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000007-0000-4000-8000-000000000007")!,
            key: "mobility-assessment.straddle-frog-abduction",
            name: "Straddle / frog abduction",
            zone: .hips,
            preferredMode: .twoSegmentAngle,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.combined],
            setupKey: "same-device-edge-both-thighs",
            defaultIsActiveRange: false,
            sortOrder: 6
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000008-0000-4000-8000-000000000008")!,
            key: "mobility-assessment.sleeper-shoulder-rotation",
            name: "Sleeper shoulder rotation",
            zone: .shoulders,
            preferredMode: .inclinometer,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "side-lying-shoulder-stabilized",
            defaultIsActiveRange: false,
            sortOrder: 7
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000009-0000-4000-8000-000000000009")!,
            key: "mobility-assessment.wall-slide-arm-elevation",
            name: "Wall-slide arm elevation",
            zone: .overhead,
            preferredMode: .inclinometer,
            manualMode: .manualAngle,
            unit: .degrees,
            sides: [.left, .right],
            setupKey: "back-to-wall-ribs-stacked",
            defaultIsActiveRange: true,
            sortOrder: 8
        ),
        DefinitionSpec(
            id: UUID(uuidString: "3C000010-0000-4000-8000-000000000010")!,
            key: "mobility-assessment.wall-squat",
            name: "Wall squat",
            zone: .overhead,
            preferredMode: .manualCriteria,
            manualMode: .manualCriteria,
            unit: .criteria,
            sides: [.combined],
            setupKey: "wall-supported-squat",
            defaultIsActiveRange: true,
            sortOrder: 9
        )
    ]

    @MainActor
    static func stage(
        using context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        try registry.validateUniqueKeys(definitions.map(\.key))
        var existing = try context.fetch(FetchDescriptor<MobilityAssessmentDefinition>())
        var existingByID = Dictionary(
            existing.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var report = SystemSeedInstallReport()

        for spec in definitions {
            let entity: MobilityAssessmentDefinition
            let sourceKind: SystemSeedSourceKind
            if let record = try registry.record(
                for: spec.key,
                expectedKind: .mobilityAssessmentDefinition
            ) {
                guard let matched = existingByID[record.entityID] else {
                    throw SystemSeedError.danglingEntity(key: spec.key, entityID: record.entityID)
                }
                entity = matched
                sourceKind = record.sourceKind
                report.updated += 1
            } else {
                let candidates = existing.filter { $0.catalogueKey == spec.key }
                guard candidates.count <= 1 else {
                    throw SystemSeedError.ambiguousLegacyMatch(key: spec.key, count: candidates.count)
                }
                if let adopted = candidates.first {
                    entity = adopted
                    sourceKind = .migratedLegacy
                    report.adopted += 1
                } else {
                    entity = spec.makeDefinition()
                    context.insert(entity)
                    existing.append(entity)
                    existingByID[entity.id] = entity
                    sourceKind = .bundled
                    report.inserted += 1
                }
            }

            applyAuthoredFields(from: spec, to: entity)
            try registry.register(
                key: spec.key,
                kind: .mobilityAssessmentDefinition,
                entityID: entity.id,
                seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                sourceKind: sourceKind
            )
        }
        return report
    }

    private static func applyAuthoredFields(
        from spec: DefinitionSpec,
        to definition: MobilityAssessmentDefinition
    ) {
        let template = spec.makeDefinition()
        definition.catalogueKey = template.catalogueKey
        definition.name = template.name
        definition.nameLocalizationKey = template.nameLocalizationKey
        definition.instructionsLocalizationKey = template.instructionsLocalizationKey
        definition.setupInstructionsLocalizationKey = template.setupInstructionsLocalizationKey
        definition.measurementDescriptionLocalizationKey = template.measurementDescriptionLocalizationKey
        definition.measurementLimitationsLocalizationKey = template.measurementLimitationsLocalizationKey
        definition.zone = template.zone
        definition.definitionVersion = template.definitionVersion
        definition.preferredMode = template.preferredMode
        definition.manualMode = template.manualMode
        definition.unit = template.unit
        definition.supportedSides = template.supportedSides
        definition.setupKeys = template.setupKeys
        definition.defaultSetupKey = template.defaultSetupKey
        definition.defaultIsActiveRange = template.defaultIsActiveRange
        definition.sortOrder = template.sortOrder
        definition.updatedAt = .now
        // isArchived remains user-owned.
    }
}

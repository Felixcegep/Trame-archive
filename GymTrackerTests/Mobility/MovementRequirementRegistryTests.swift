import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MovementRequirementRegistryTests: XCTestCase {

    func testRegistryLookupReturnsConfiguredRequirements() {
        let squatReqs = MovementRequirementRegistry.requirements(for: "barbell_back_squat")
        XCTAssertEqual(squatReqs.count, 2)
        XCTAssertTrue(squatReqs.contains(where: { $0.jointZone == .ankles }))
        XCTAssertTrue(squatReqs.contains(where: { $0.jointZone == .hips }))
    }

    func testRegistryAndRecommendationKeysResolveAgainstSeededCatalogues() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)
        try MobilitySeedData.stage(using: context, registry: registry)
        try MobilityAssessmentSeedData.stage(using: context, registry: registry)

        let assessmentKeys = Set(
            try context.fetch(FetchDescriptor<MobilityAssessmentDefinition>())
                .map(\.catalogueKey)
        )
        XCTAssertTrue(
            MovementRequirementRegistry.assessmentCatalogueKeys.isSubset(of: assessmentKeys),
            "Every movement requirement must reference a seeded mobility assessment"
        )
        XCTAssertTrue(
            MobilityRecommendationService.recommendationsByAssessment.keys.allSatisfy(assessmentKeys.contains),
            "Every recommendation target must reference a seeded mobility assessment"
        )

        let routineSeedKeys = Set(
            try context.fetch(FetchDescriptor<SystemSeedRecord>())
                .filter { $0.entityKind == .mobilityRoutine }
                .map(\.seedKey)
        )
        XCTAssertTrue(
            MobilityRecommendationService.routineCatalogueKeys.isSubset(of: routineSeedKeys),
            "Every recommendation must reference a seeded mobility routine"
        )
    }

    func testEvaluatorReturnsSufficientCapacityWhenValueExceedsThreshold() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityAssessmentDefinition(
            catalogueKey: "mobility-assessment.knee-to-wall-dorsiflexion",
            name: "Knee-to-Wall Dorsiflexion",
            nameLocalizationKey: "knee_to_wall.name",
            instructionsLocalizationKey: "knee_to_wall.instructions",
            setupInstructionsLocalizationKey: "knee_to_wall.setup",
            measurementDescriptionLocalizationKey: "knee_to_wall.desc",
            measurementLimitationsLocalizationKey: "knee_to_wall.limitations",
            zone: .ankles,
            definitionVersion: 1,
            preferredMode: .manualLinear,
            manualMode: .manualLinear,
            unit: .centimetres,
            supportedSides: [.left, .right],
            setupKeys: ["standard"],
            defaultSetupKey: "standard",
            defaultIsActiveRange: true,
            sortOrder: 1
        )
        context.insert(definition)

        let day = LocalDay(rawValue: "2026-08-04")
        let input = MobilityAssessmentResultInput(
            numericValue: 14.0, // Threshold is 10.0cm
            side: .left,
            isWarm: true,
            setupKey: "standard",
            method: .manualLinear,
            unit: .centimetres,
            isActiveRange: true,
            day: day,
            source: .manual,
            confidence: .high
        )
        let result = MobilityAssessmentResult(definition: definition, input: input, orderIndex: 0)

        let verdicts = MovementRequirementEvaluator.evaluate(
            exerciseKey: "barbell_back_squat",
            latestResultsByAssessmentKey: ["mobility-assessment.knee-to-wall-dorsiflexion": result]
        )

        let ankleVerdict = verdicts.first(where: {
            if case .capacitySufficient = $0 { return true }
            return false
        })
        XCTAssertNotNil(ankleVerdict, "Expected capacitySufficient verdict for 14.0cm ankle dorsiflexion")
    }

    func testEvaluatorDetectsRestrictionAndRecommendationServiceGeneratesRoutine() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityAssessmentDefinition(
            catalogueKey: "mobility-assessment.knee-to-wall-dorsiflexion",
            name: "Knee-to-Wall Dorsiflexion",
            nameLocalizationKey: "knee_to_wall.name",
            instructionsLocalizationKey: "knee_to_wall.instructions",
            setupInstructionsLocalizationKey: "knee_to_wall.setup",
            measurementDescriptionLocalizationKey: "knee_to_wall.desc",
            measurementLimitationsLocalizationKey: "knee_to_wall.limitations",
            zone: .ankles,
            definitionVersion: 1,
            preferredMode: .manualLinear,
            manualMode: .manualLinear,
            unit: .centimetres,
            supportedSides: [.left, .right],
            setupKeys: ["standard"],
            defaultSetupKey: "standard",
            defaultIsActiveRange: true,
            sortOrder: 1
        )
        context.insert(definition)

        let day = LocalDay(rawValue: "2026-08-04")
        let input = MobilityAssessmentResultInput(
            numericValue: 6.0, // Restricted (threshold is 10.0cm, gap is 4.0cm)
            side: .left,
            isWarm: true,
            setupKey: "standard",
            method: .manualLinear,
            unit: .centimetres,
            isActiveRange: true,
            day: day,
            source: .manual,
            confidence: .high
        )
        let result = MobilityAssessmentResult(definition: definition, input: input, orderIndex: 0)

        let verdicts = MovementRequirementEvaluator.evaluate(
            exerciseKey: "barbell_back_squat",
            latestResultsByAssessmentKey: ["mobility-assessment.knee-to-wall-dorsiflexion": result]
        )

        let recommendations = MobilityRecommendationService.recommendRoutines(for: verdicts)
        XCTAssertFalse(recommendations.isEmpty, "Expected mobility recommendation for restricted ankle dorsiflexion")
        XCTAssertEqual(recommendations.first?.routineCatalogueKey, "mobility-routine.ankle-foot-mobilization")
    }
}

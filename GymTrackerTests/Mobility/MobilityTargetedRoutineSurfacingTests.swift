import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class MobilityTargetedRoutineSurfacingTests: XCTestCase {
    func testProductionAdapterUsesSeededKeysAndDegradesWithoutAuthoredBands() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)
        try MobilitySeedData.stage(using: context, registry: registry)
        try MobilityAssessmentSeedData.stage(using: context, registry: registry)

        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        let definitions = try context.fetch(FetchDescriptor<MobilityAssessmentDefinition>())
        let seededRoutineKeys = Set(routines.compactMap(\.catalogueKey))
        let referencedRoutineKeys = Set(
            MobilityTargetedRoutineSurfacingService.authoredMappings
                .flatMap(\.routineCatalogueKeys)
        )

        XCTAssertFalse(referencedRoutineKeys.isEmpty)
        XCTAssertTrue(referencedRoutineKeys.isSubset(of: seededRoutineKeys))
        XCTAssertFalse(referencedRoutineKeys.contains("ankle_dorsiflexion_pnf"))
        XCTAssertTrue(
            MobilityTargetedRoutineSurfacingService.authoredMappings.allSatisfy { mapping in
                mapping.protocolID.hasPrefix("mobility-assessment.")
                    && mapping.movementID.hasPrefix("mobility-definition.")
            }
        )

        let candidates = MobilityTargetedRoutineSurfacingService.candidates(from: routines)
        XCTAssertTrue(candidates.allSatisfy { seededRoutineKeys.contains($0.routineID) })
        XCTAssertEqual(candidates.count, routines.count)

        let surface = MobilityTargetedRoutineSurfacingService.surface(
            definitions: definitions,
            results: [],
            routines: routines
        )
        XCTAssertTrue(
            surface.recommendations.isEmpty,
            "No population bands are authored, so the adapter must remain neutral."
        )
    }
    func testOnlyNumericBelowObservationCanSurfaceWithNeutralWhyData() {
        let measurement = makeMeasurement(
            id: "hip-left",
            protocolID: "hip-ir",
            value: .numeric(value: 35, unit: .degrees),
            band: .positioned(makeEvidence(position: .below))
        )
        let profile = makeProfile(measurements: [measurement])
        let mapping = makeMapping(protocolID: "hip-ir", movementID: "90-90", name: "90/90 position")
        let routine = makeRoutine(
            id: "routine-short",
            name: "Short mobility",
            movementIDs: ["90-90"],
            duration: 8
        )

        let surface = MobilityTargetedRoutineSurfacingService.surface(
            profile: profile,
            mappings: [mapping],
            routines: [routine],
            timeBudgetMinutes: 10
        )

        XCTAssertEqual(surface.recommendations.count, 1)
        let recommendation = try! XCTUnwrap(surface.recommendations.first)
        XCTAssertEqual(recommendation.rankWithinMeasurement, 1)
        XCTAssertEqual(recommendation.timeFit, .fitsBudget)
        XCTAssertEqual(recommendation.why.protocolID, "hip-ir")
        XCTAssertEqual(recommendation.why.observedValue, 35)
        XCTAssertEqual(recommendation.why.unit, .degrees)
        XCTAssertEqual(recommendation.why.bandPosition, .below)
        XCTAssertEqual(recommendation.why.movementName, "90/90 position")
        XCTAssertEqual(recommendation.why.bandEvidence.lowerBound, 40)
        XCTAssertEqual(recommendation.why.bandEvidence.upperBound, 60)
        XCTAssertEqual(recommendation.why.bandEvidence.rulesetVersion, 1)
        XCTAssertEqual(recommendation.why.bandEvidence.sourceCitation, "Evidence review pending")
        XCTAssertEqual(
            recommendation.why.bandEvidence.populationDescription,
            "Population context required before release"
        )
    }

    func testMissingCriteriaWithinAboveAndIncompatibleResultsNeverSurface() {
        let measurements = [
            makeMeasurement(id: "missing", value: .missing(unit: .degrees), band: .notMeasured),
            makeMeasurement(
                id: "criteria",
                value: .criteria(value: .criteriaNotObserved, unit: .criteria),
                band: .notNumeric
            ),
            makeMeasurement(
                id: "within",
                value: .numeric(value: 45, unit: .degrees),
                band: .positioned(makeEvidence(position: .within))
            ),
            makeMeasurement(
                id: "above",
                value: .numeric(value: 70, unit: .degrees),
                band: .positioned(makeEvidence(position: .above))
            ),
            makeMeasurement(
                id: "incompatible",
                value: .numeric(value: 25, unit: .degrees),
                expectedUnit: .centimetres,
                band: .incompatibleProtocol
            )
        ]
        let profile = makeProfile(measurements: measurements)
        let mapping = makeMapping(protocolID: "hip-ir")
        let routine = makeRoutine(movementIDs: [mapping.movementID])

        let surface = MobilityTargetedRoutineSurfacingService.surface(
            profile: profile,
            mappings: [mapping],
            routines: [routine]
        )

        XCTAssertTrue(surface.recommendations.isEmpty)
    }

    func testDifferentUnitsAreRankedWithinTheirOwnMeasurementOnly() {
        let degreeMeasurement = makeMeasurement(
            id: "degrees-deep",
            protocolID: "hip-ir",
            value: .numeric(value: 1, unit: .degrees),
            band: .positioned(makeEvidence(position: .below, lowerBound: 40, upperBound: 60))
        )
        let secondDegreeMeasurement = makeMeasurement(
            id: "degrees-shallow",
            protocolID: "hip-flexion",
            value: .numeric(value: 20, unit: .degrees),
            band: .positioned(makeEvidence(position: .below, lowerBound: 40, upperBound: 60))
        )
        let centimetreMeasurement = makeMeasurement(
            id: "centimetres-measurement",
            protocolID: "ankle-dorsiflexion",
            value: .numeric(value: 1000, unit: .centimetres),
            expectedUnit: .centimetres,
            band: .positioned(makeEvidence(position: .below, unit: .centimetres, lowerBound: 1001, upperBound: 1100))
        )
        let mappings = [
            makeMapping(protocolID: "hip-ir", movementID: "hip-movement", priority: 0),
            makeMapping(protocolID: "hip-flexion", movementID: "hip-flexion-movement", priority: 0),
            makeMapping(protocolID: "ankle-dorsiflexion", movementID: "ankle-movement", priority: 0)
        ]
        let routines = [
            makeRoutine(id: "hip-routine", movementIDs: ["hip-movement"]),
            makeRoutine(id: "hip-flexion-routine", movementIDs: ["hip-flexion-movement"]),
            makeRoutine(id: "ankle-routine", movementIDs: ["ankle-movement"])
        ]

        let surface = MobilityTargetedRoutineSurfacingService.surface(
            profile: makeProfile(measurements: [degreeMeasurement, secondDegreeMeasurement, centimetreMeasurement]),
            mappings: mappings,
            routines: routines
        )

        XCTAssertEqual(surface.unitGroups.map(\.unit), [.degrees, .centimetres])
        XCTAssertEqual(
            surface.unitGroups[0].measurements.map(\.measurementID),
            ["degrees-deep", "degrees-shallow"]
        )
        XCTAssertEqual(
            surface.unitGroups[0].measurements.map(\.distanceBelowLowerBound),
            [39, 20]
        )
        XCTAssertEqual(surface.unitGroups[1].measurements.map(\.unit), [.centimetres])
        XCTAssertEqual(surface.unitGroups[1].measurements[0].distanceBelowLowerBound, 1)
    }

    func testRankingUsesExplicitRelevanceTimeFitAndStableTies() {
        let measurement = makeMeasurement(
            id: "measurement",
            value: .numeric(value: 30, unit: .degrees),
            band: .positioned(makeEvidence(position: .below))
        )
        let directMapping = makeMapping(
            movementID: "direct-movement",
            relevance: .direct,
            priority: 10
        )
        let supportingMapping = makeMapping(
            movementID: "supporting-movement",
            relevance: .supporting,
            priority: 0
        )
        let routines = [
            makeRoutine(id: "unknown", movementIDs: ["direct-movement"], duration: nil),
            makeRoutine(id: "over-budget", movementIDs: ["direct-movement"], duration: 20),
            makeRoutine(id: "direct-fit-b", movementIDs: ["direct-movement"], duration: 5),
            makeRoutine(id: "direct-fit-a", movementIDs: ["direct-movement"], duration: 5),
            makeRoutine(id: "supporting-fit", movementIDs: ["supporting-movement"], duration: 1)
        ]

        let surface = MobilityTargetedRoutineSurfacingService.surface(
            profile: makeProfile(measurements: [measurement]),
            mappings: [supportingMapping, directMapping],
            routines: routines,
            timeBudgetMinutes: 10
        )

        XCTAssertEqual(
            surface.recommendations.map(\.routineID),
            ["direct-fit-a", "direct-fit-b", "unknown", "supporting-fit"]
        )
        XCTAssertEqual(surface.recommendations.map(\.rankWithinMeasurement), [1, 2, 3, 4])
        XCTAssertFalse(surface.recommendations.contains { $0.routineID == "over-budget" })
    }

    func testInvalidBudgetOrUnrelatedRoutineProducesNoSuggestions() {
        let measurement = makeMeasurement(
            value: .numeric(value: 30, unit: .degrees),
            band: .positioned(makeEvidence(position: .below))
        )
        let mapping = makeMapping(movementID: "mapped-movement")
        let unrelated = makeRoutine(movementIDs: ["other-movement"])

        XCTAssertTrue(
            MobilityTargetedRoutineSurfacingService.surface(
                profile: makeProfile(measurements: [measurement]),
                mappings: [mapping],
                routines: [unrelated],
                timeBudgetMinutes: -1
            ).recommendations.isEmpty
        )
        XCTAssertTrue(
            MobilityTargetedRoutineSurfacingService.surface(
                profile: makeProfile(measurements: [measurement]),
                mappings: [mapping],
                routines: [unrelated]
            ).recommendations.isEmpty
        )
    }

    private func makeProfile(measurements: [MobilityAssessmentProfileMeasurement]) -> MobilityAssessmentProfile {
        MobilityAssessmentProfile(
            measurements: measurements,
            sideGaps: [],
            coverage: MobilityAssessmentProfileCoverage(
                expectedCount: measurements.count,
                measuredCount: measurements.count,
                missingProtocolIDs: []
            )
        )
    }

    private func makeMeasurement(
        id: String = "measurement",
        protocolID: String = "hip-ir",
        value: MobilityAssessmentProfileValue,
        expectedUnit: MobilityMeasurementUnit = .degrees,
        band: MobilityAssessmentProfileBandState
    ) -> MobilityAssessmentProfileMeasurement {
        MobilityAssessmentProfileMeasurement(
            id: id,
            protocolID: protocolID,
            protocolVersion: 1,
            testName: "Mobility observation",
            side: .left,
            expectedUnit: expectedUnit,
            value: value,
            resultID: nil,
            recordedAt: nil,
            actualMethod: nil,
            actualSource: nil,
            history: .noPriorObservation,
            band: band
        )
    }

    private func makeMapping(
        protocolID: String = "hip-ir",
        movementID: String = "90-90",
        name: String = "90/90 position",
        relevance: MobilityTargetedRoutineRelevance = .direct,
        priority: Int = 0
    ) -> MobilityAssessmentMovementMapping {
        MobilityAssessmentMovementMapping(
            protocolID: protocolID,
            protocolVersion: 1,
            movementID: movementID,
            movementName: name,
            relevance: relevance,
            priority: priority
        )
    }

    private func makeRoutine(
        id: String = "routine",
        name: String = "Mobility routine",
        movementIDs: [String] = ["90-90"],
        duration: Int? = 5,
        priority: Int = 0
    ) -> MobilityTargetedRoutineCandidate {
        MobilityTargetedRoutineCandidate(
            routineID: id,
            routineName: name,
            movementIDs: movementIDs,
            estimatedDurationMinutes: duration,
            priority: priority
        )
    }

    private func makeEvidence(
        position: MobilityReferenceBandPosition,
        unit: MobilityMeasurementUnit = .degrees,
        lowerBound: Double? = 40,
        upperBound: Double? = 60
    ) -> MobilityAssessmentProfileBandEvidence {
        MobilityAssessmentProfileBandEvidence(
            position: position,
            lowerBound: lowerBound,
            upperBound: upperBound,
            unit: unit,
            rulesetVersion: 1,
            sourceCitation: "Evidence review pending",
            populationDescription: "Population context required before release",
            limitations: "This comparison range is not a diagnosis or universal target."
        )
    }
}

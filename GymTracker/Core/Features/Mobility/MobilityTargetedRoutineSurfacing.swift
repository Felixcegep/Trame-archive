import Foundation

/// Describes an authored relationship between one exact assessment protocol
/// revision and a movement. The rank is metadata supplied by the catalog; the
/// surfacing service never infers a relationship from measurement values.
struct MobilityAssessmentMovementMapping: Codable, Equatable, Hashable, Sendable {
    let protocolID: String
    let protocolVersion: Int
    let movementID: String
    let movementName: String
    let relevance: MobilityTargetedRoutineRelevance
    let priority: Int
    /// When present, limits this authored relationship to these stable routine
    /// catalogue keys. An empty list preserves the general-purpose kernel's
    /// movement-membership behavior for callers that supply their own catalog.
    let routineCatalogueKeys: [String]

    init(
        protocolID: String,
        protocolVersion: Int,
        movementID: String,
        movementName: String,
        relevance: MobilityTargetedRoutineRelevance,
        priority: Int,
        routineCatalogueKeys: [String] = []
    ) {
        self.protocolID = protocolID
        self.protocolVersion = protocolVersion
        self.movementID = movementID
        self.movementName = movementName
        self.relevance = relevance
        self.priority = priority
        self.routineCatalogueKeys = routineCatalogueKeys
    }

    private enum CodingKeys: String, CodingKey {
        case protocolID, protocolVersion, movementID, movementName, relevance, priority, routineCatalogueKeys
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            protocolID: try values.decode(String.self, forKey: .protocolID),
            protocolVersion: try values.decode(Int.self, forKey: .protocolVersion),
            movementID: try values.decode(String.self, forKey: .movementID),
            movementName: try values.decode(String.self, forKey: .movementName),
            relevance: try values.decode(MobilityTargetedRoutineRelevance.self, forKey: .relevance),
            priority: try values.decode(Int.self, forKey: .priority),
            routineCatalogueKeys: try values.decodeIfPresent([String].self, forKey: .routineCatalogueKeys) ?? []
        )
    }

    var id: String {
        [protocolID, String(protocolVersion), movementID].joined(separator: "|")
    }
}

enum MobilityTargetedRoutineRelevance: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case direct
    case supporting

    fileprivate var sortRank: Int {
        switch self {
        case .direct: 0
        case .supporting: 1
        }
    }
}

/// A value-only routine catalog entry. A caller can adapt persisted routines
/// into this shape without giving the surfacing contract permission to mutate
/// or auto-start anything.
struct MobilityTargetedRoutineCandidate: Codable, Equatable, Hashable, Identifiable, Sendable {
    let routineID: String
    let routineName: String
    let movementIDs: [String]
    let estimatedDurationMinutes: Int?
    let priority: Int

    var id: String { routineID }
}

enum MobilityTargetedRoutineTimeFit: String, Codable, Equatable, Hashable, Sendable {
    case notConstrained
    case fitsBudget
    case durationUnknown
}

/// Typed evidence for neutral UI copy. It intentionally contains no sentence,
/// medical conclusion, or localized string.
struct MobilityTargetedRoutineWhy: Codable, Equatable, Hashable, Sendable {
    let protocolID: String
    let protocolVersion: Int
    let assessmentName: String
    let side: MobilityAssessmentSide
    let observedValue: Double
    let unit: MobilityMeasurementUnit
    let bandPosition: MobilityReferenceBandPosition
    let movementID: String
    let movementName: String
    let bandEvidence: MobilityAssessmentProfileBandEvidence
}

struct MobilityTargetedRoutineRecommendation: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let measurementID: String
    let routineID: String
    let routineName: String
    let movementID: String
    let movementName: String
    let relevance: MobilityTargetedRoutineRelevance
    let estimatedDurationMinutes: Int?
    let timeFit: MobilityTargetedRoutineTimeFit
    let rankWithinMeasurement: Int
    let why: MobilityTargetedRoutineWhy
}

struct MobilityTargetedRoutineMeasurementGroup: Codable, Equatable, Hashable, Identifiable, Sendable {
    let measurementID: String
    let unit: MobilityMeasurementUnit
    let distanceBelowLowerBound: Double
    let recommendations: [MobilityTargetedRoutineRecommendation]

    var id: String { measurementID }
}

struct MobilityTargetedRoutineUnitGroup: Codable, Equatable, Hashable, Identifiable, Sendable {
    let unit: MobilityMeasurementUnit
    let measurements: [MobilityTargetedRoutineMeasurementGroup]

    var id: String { unit.rawValue }
}

struct MobilityTargetedRoutineSurface: Codable, Equatable, Sendable {
    /// Units are explicit groups: measurement distances are ordered only
    /// within one unit. The stable unit-group order is presentation plumbing,
    /// not a cross-unit numeric ranking.
    let unitGroups: [MobilityTargetedRoutineUnitGroup]

    var recommendations: [MobilityTargetedRoutineRecommendation] {
        unitGroups.flatMap { $0.measurements.flatMap(\.recommendations) }
    }
}

/// Pure targeted-routine surfacing over an already-built mobility profile.
///
/// Eligibility is intentionally narrow: the profile must contain a finite
/// numeric value and an exact, authored `.below` band position. Missing,
/// criteria, above/within, and incompatible observations return no suggestion.
enum MobilityTargetedRoutineSurfacingService {
    private struct ProtocolRevision: Hashable {
        let id: String
        let version: Int
    }

    private struct MappingIdentity: Hashable {
        let protocolID: String
        let protocolVersion: Int
        let movementID: String
    }

    /// The authored assessment-to-routine relationships used by the
    /// production adapter. IDs intentionally match the current system seed
    /// keys; they are not inferred from display names or measurement values.
    static let authoredMappings: [MobilityAssessmentMovementMapping] = [
        mapping(
            protocolID: "mobility-assessment.thoracic-rotation-seated",
            movementName: "Thoracic Rotation",
            relevance: .direct,
            routineKeys: [
                "mobility-routine.upper-body-bench-warmup",
                "mobility-routine.lower-back-decompression",
                "mobility-routine.front-rack-and-wrist-preparation",
                "mobility-routine.bench-preparation-v2",
                "mobility-routine.snatch-preparation-v2",
                "mobility-routine.strongman-overhead-preparation-v2"
            ]
        ),
        mapping(
            protocolID: "mobility-assessment.open-book-rotation",
            movementName: "Thread the Needle",
            relevance: .supporting,
            routineKeys: ["mobility-routine.lower-back-decompression"]
        ),
        mapping(
            protocolID: "mobility-assessment.active-straight-leg-raise",
            movementName: "Active Straight Leg Raise",
            relevance: .direct,
            routineKeys: ["mobility-routine.deadlift-preparation-v2"]
        ),
        mapping(
            protocolID: "mobility-assessment.knee-to-wall-dorsiflexion",
            movementName: "Knee-to-Wall Ankle Mobilization",
            relevance: .direct,
            routineKeys: [
                "mobility-routine.ankle-foot-mobilization",
                "mobility-routine.loaded-mobility-foundations",
                "mobility-routine.squat-preparation",
                "mobility-routine.olympic-lifting-preparation",
                "mobility-routine.squat-preparation-v2",
                "mobility-routine.snatch-preparation-v2",
                "mobility-routine.clean-and-jerk-preparation-v2",
                "mobility-routine.strongman-carry-preparation-v2",
                "mobility-routine.fitness-racing-preparation-v2"
            ]
        ),
        mapping(
            protocolID: "mobility-assessment.soleus-wall-stretch",
            movementName: "Soleus Wall Stretch",
            relevance: .direct,
            routineKeys: ["mobility-routine.ankle-foot-mobilization"]
        ),
        mapping(
            protocolID: "mobility-assessment.90-90-hip-rotation",
            movementName: "90/90 Hip Switch",
            relevance: .direct,
            routineKeys: [
                "mobility-routine.daily-mobility-reset",
                "mobility-routine.post-leg-day-reset",
                "mobility-routine.strongman-event-preparation",
                "mobility-routine.squat-preparation-v2",
                "mobility-routine.snatch-preparation-v2",
                "mobility-routine.clean-and-jerk-preparation-v2",
                "mobility-routine.strongman-carry-preparation-v2"
            ]
        ),
        mapping(
            protocolID: "mobility-assessment.straddle-frog-abduction",
            movementName: "Tactical Frog",
            relevance: .supporting,
            routineKeys: ["mobility-routine.squat-preparation"]
        ),
        mapping(
            protocolID: "mobility-assessment.sleeper-shoulder-rotation",
            movementName: "Shoulder Pass-Throughs",
            relevance: .supporting,
            routineKeys: [
                "mobility-routine.upper-body-bench-warmup",
                "mobility-routine.bench-preparation-v2"
            ]
        ),
        mapping(
            protocolID: "mobility-assessment.wall-slide-arm-elevation",
            movementName: "Wall Slides",
            relevance: .direct,
            routineKeys: [
                "mobility-routine.upper-body-bench-warmup",
                "mobility-routine.overhead-shoulder-saver",
                "mobility-routine.bench-preparation-v2",
                "mobility-routine.snatch-preparation-v2",
                "mobility-routine.strongman-overhead-preparation-v2"
            ]
        )
    ]

    /// Builds the production surface from persisted assessment data and the
    /// real seeded routine graph. Bands remain caller-supplied because no
    /// population bands are authored in the current catalogue.
    @MainActor
    static func surface(
        definitions: [MobilityAssessmentDefinition],
        results: [MobilityAssessmentResult],
        routines: [MobilityRoutine],
        bands: [MobilityReferenceBand] = [],
        timeBudgetMinutes: Int? = nil
    ) -> MobilityTargetedRoutineSurface {
        let activeDefinitions = definitions.filter { !$0.isArchived }
        let protocols = activeDefinitions.flatMap(protocols(for:))
        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: protocols,
            results: results,
            bands: bands
        )
        return surface(
            profile: profile,
            mappings: authoredMappings,
            routines: candidates(from: routines),
            timeBudgetMinutes: timeBudgetMinutes
        )
    }

    /// Converts live routines into the value-only candidate shape consumed by
    /// the pure ranker. User-created routines without a stable catalogue key
    /// are deliberately excluded from this authored recommendation surface.
    @MainActor
    static func candidates(from routines: [MobilityRoutine]) -> [MobilityTargetedRoutineCandidate] {
        routines
            .filter { !$0.isArchived }
            .compactMap { routine in
                guard let routineKey = routine.catalogueKey,
                      routineKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                else { return nil }
                let movementIDs = routine.orderedItems.compactMap { $0.definition.catalogueKey }
                guard movementIDs.isEmpty == false else { return nil }
                let estimate = MobilityRoutineDurationEstimate.estimate(for: routine)
                let duration: Int? = estimate.completeness == .unknown
                    ? nil
                    : Int(ceil(Double(estimate.knownDurationSeconds) / 60.0))
                return MobilityTargetedRoutineCandidate(
                    routineID: routineKey,
                    routineName: routine.name,
                    movementIDs: movementIDs,
                    estimatedDurationMinutes: duration,
                    priority: 0
                )
            }
    }

    static func surface(
        profile: MobilityAssessmentProfile,
        mappings: [MobilityAssessmentMovementMapping],
        routines: [MobilityTargetedRoutineCandidate],
        timeBudgetMinutes: Int? = nil
    ) -> MobilityTargetedRoutineSurface {
        guard timeBudgetMinutes == nil || timeBudgetMinutes! >= 0 else {
            return MobilityTargetedRoutineSurface(unitGroups: [])
        }

        let validMappings = mappings.filter { isValidMapping($0) }
        let validRoutines = routines.filter { isValidRoutine($0) }
        var mappingsByProtocol: [ProtocolRevision: [MobilityAssessmentMovementMapping]] = [:]
        var mappingPriorityByID: [MappingIdentity: Int] = [:]
        for mapping in validMappings {
            let key = ProtocolRevision(id: mapping.protocolID, version: mapping.protocolVersion)
            mappingsByProtocol[key, default: []].append(mapping)
            // Preserve `first(where:)` semantics if malformed input repeats a
            // stable mapping identity.
            let identity = MappingIdentity(
                protocolID: mapping.protocolID,
                protocolVersion: mapping.protocolVersion,
                movementID: mapping.movementID
            )
            if mappingPriorityByID[identity] == nil {
                mappingPriorityByID[identity] = mapping.priority
            }
        }
        for key in Array(mappingsByProtocol.keys) {
            mappingsByProtocol[key]?.sort { mappingPrecedes($0, $1) }
        }

        var routinePriorityByID: [String: Int] = [:]
        for routine in validRoutines where routinePriorityByID[routine.routineID] == nil {
            routinePriorityByID[routine.routineID] = routine.priority
        }

        var measurementByID: [String: MobilityAssessmentProfileMeasurement] = [:]
        for measurement in profile.measurements where measurementByID[measurement.id] == nil {
            measurementByID[measurement.id] = measurement
        }
        var recommendationsByMeasurement: [String: [MobilityTargetedRoutineRecommendation]] = [:]

        for measurement in profile.measurements {
            guard let measurementEligibility = eligibility(for: measurement) else { continue }
            let key = ProtocolRevision(id: measurement.protocolID, version: measurement.protocolVersion)
            let matchingMappings = mappingsByProtocol[key] ?? []

            for mapping in matchingMappings {
                for routine in validRoutines where routine.movementIDs.contains(mapping.movementID)
                    && (mapping.routineCatalogueKeys.isEmpty
                        || mapping.routineCatalogueKeys.contains(routine.routineID)) {
                    guard let timeFit = timeFit(
                        for: routine.estimatedDurationMinutes,
                        budget: timeBudgetMinutes
                    ) else {
                        continue
                    }
                    guard case let .numeric(value, unit) = measurement.value else {
                        continue
                    }

                    let recommendation = MobilityTargetedRoutineRecommendation(
                        id: [measurement.id, routine.routineID, mapping.movementID].joined(separator: "|"),
                        measurementID: measurement.id,
                        routineID: routine.routineID,
                        routineName: routine.routineName,
                        movementID: mapping.movementID,
                        movementName: mapping.movementName,
                        relevance: mapping.relevance,
                        estimatedDurationMinutes: routine.estimatedDurationMinutes,
                        timeFit: timeFit,
                        rankWithinMeasurement: 0,
                        why: MobilityTargetedRoutineWhy(
                            protocolID: measurement.protocolID,
                            protocolVersion: measurement.protocolVersion,
                            assessmentName: measurement.testName,
                            side: measurement.side,
                            observedValue: value,
                            unit: unit,
                            bandPosition: .below,
                            movementID: mapping.movementID,
                            movementName: mapping.movementName,
                            bandEvidence: measurementEligibility.evidence
                        )
                    )
                    recommendationsByMeasurement[measurement.id, default: []].append(recommendation)
                }
            }
        }

        let measurementGroups: [MobilityTargetedRoutineMeasurementGroup] = recommendationsByMeasurement.compactMap { element in
            let (measurementID, _) = element
            guard let measurement = measurementByID[measurementID],
                  let eligibility = eligibility(for: measurement)
            else { return nil }
            let ordered = (recommendationsByMeasurement[measurementID] ?? [])
                .sorted { lhs, rhs in
                    recommendationPrecedes(
                        lhs,
                        rhs,
                        routinePriorityByID: routinePriorityByID,
                        mappingPriorityByID: mappingPriorityByID
                    )
                }
            let ranked = ordered.enumerated().map { offset, recommendation in
                MobilityTargetedRoutineRecommendation(
                    id: recommendation.id,
                    measurementID: recommendation.measurementID,
                    routineID: recommendation.routineID,
                    routineName: recommendation.routineName,
                    movementID: recommendation.movementID,
                    movementName: recommendation.movementName,
                    relevance: recommendation.relevance,
                    estimatedDurationMinutes: recommendation.estimatedDurationMinutes,
                    timeFit: recommendation.timeFit,
                    rankWithinMeasurement: offset + 1,
                    why: recommendation.why
                )
            }
            return MobilityTargetedRoutineMeasurementGroup(
                measurementID: measurementID,
                unit: eligibility.unit,
                distanceBelowLowerBound: eligibility.distance,
                recommendations: ranked
            )
        }

        let unitGroups: [MobilityTargetedRoutineUnitGroup] = MobilityMeasurementUnit.allCases.compactMap { unit in
            let measurements = measurementGroups
                .filter { $0.unit == unit }
                .sorted { lhs, rhs in
                    if lhs.distanceBelowLowerBound != rhs.distanceBelowLowerBound {
                        return lhs.distanceBelowLowerBound > rhs.distanceBelowLowerBound
                    }
                    return lhs.measurementID < rhs.measurementID
                }
            guard measurements.isEmpty == false else { return nil }
            return MobilityTargetedRoutineUnitGroup(unit: unit, measurements: measurements)
        }

        return MobilityTargetedRoutineSurface(unitGroups: unitGroups)
    }

    private static func eligibility(
        for measurement: MobilityAssessmentProfileMeasurement
    ) -> (value: Double, unit: MobilityMeasurementUnit, distance: Double, evidence: MobilityAssessmentProfileBandEvidence)? {
        guard case let .numeric(value, unit) = measurement.value,
              value.isFinite,
              unit == measurement.expectedUnit
        else {
            return nil
        }
        guard let evidence = measurement.bandEvidence,
              evidence.unit == unit,
              let distance = evidence.distanceBelowLowerBound(for: value)
        else {
            return nil
        }
        return (value, unit, distance, evidence)
    }

    private static func isValidMapping(_ mapping: MobilityAssessmentMovementMapping) -> Bool {
        mapping.protocolID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && mapping.protocolVersion > 0
            && mapping.movementID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && mapping.movementName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && mapping.priority >= 0
            && mapping.routineCatalogueKeys.allSatisfy {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
    }

    private static func mapping(
        protocolID: String,
        movementName: String,
        relevance: MobilityTargetedRoutineRelevance,
        routineKeys: [String]
    ) -> MobilityAssessmentMovementMapping {
        MobilityAssessmentMovementMapping(
            protocolID: protocolID,
            protocolVersion: 1,
            movementID: SystemSeedKey.make(namespace: "mobility-definition", legacyName: movementName),
            movementName: movementName,
            relevance: relevance,
            priority: 0,
            routineCatalogueKeys: routineKeys
        )
    }

    private static func protocols(
        for definition: MobilityAssessmentDefinition
    ) -> [MobilityAssessmentProtocol] {
        definition.supportedSides.map { side in
            MobilityAssessmentProtocol(
                protocolID: definition.catalogueKey,
                protocolVersion: definition.definitionVersion,
                measurement: definition.measurementDescriptionLocalizationKey,
                testName: definition.name,
                position: definition.defaultSetupKey,
                setupKey: definition.defaultSetupKey,
                side: side,
                unit: definition.unit,
                activePassive: definition.defaultIsActiveRange ? .active : .passive,
                recordsWarmCold: true,
                preferredMethod: method(for: definition.preferredMode),
                manualFallback: true,
                reliabilitySource: "App-authored assessment protocol",
                limitations: definition.measurementLimitationsLocalizationKey
            )
        }
    }

    private static func method(
        for mode: MobilityMeasurementMode
    ) -> MobilityAssessmentProtocol.Method {
        switch mode {
        case .manualAngle, .manualLinear, .manualCriteria, .cameraPose: .manual
        case .inclinometer: .inclinometer
        case .axialRotation, .twoSegmentAngle, .dynamicRange: .deviceMotion
        }
    }

    private static func isValidRoutine(_ routine: MobilityTargetedRoutineCandidate) -> Bool {
        routine.routineID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && routine.routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && routine.movementIDs.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
            && (routine.estimatedDurationMinutes == nil || routine.estimatedDurationMinutes! >= 0)
            && routine.priority >= 0
    }

    private static func timeFit(for duration: Int?, budget: Int?) -> MobilityTargetedRoutineTimeFit? {
        guard let budget else {
            return duration == nil ? .durationUnknown : .notConstrained
        }
        guard let duration else { return .durationUnknown }
        return duration <= budget ? .fitsBudget : nil
    }

    private static func mappingPrecedes(
        _ lhs: MobilityAssessmentMovementMapping,
        _ rhs: MobilityAssessmentMovementMapping
    ) -> Bool {
        if lhs.relevance.sortRank != rhs.relevance.sortRank {
            return lhs.relevance.sortRank < rhs.relevance.sortRank
        }
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        if lhs.movementID != rhs.movementID {
            return lhs.movementID < rhs.movementID
        }
        return lhs.id < rhs.id
    }

    private static func recommendationPrecedes(
        _ lhs: MobilityTargetedRoutineRecommendation,
        _ rhs: MobilityTargetedRoutineRecommendation,
        routinePriorityByID: [String: Int],
        mappingPriorityByID: [MappingIdentity: Int]
    ) -> Bool {
        if lhs.relevance.sortRank != rhs.relevance.sortRank {
            return lhs.relevance.sortRank < rhs.relevance.sortRank
        }
        let lhsMappingID = MappingIdentity(
            protocolID: lhs.why.protocolID,
            protocolVersion: lhs.why.protocolVersion,
            movementID: lhs.movementID
        )
        let rhsMappingID = MappingIdentity(
            protocolID: rhs.why.protocolID,
            protocolVersion: rhs.why.protocolVersion,
            movementID: rhs.movementID
        )
        let lhsMappingPriority = mappingPriorityByID[lhsMappingID] ?? Int.max
        let rhsMappingPriority = mappingPriorityByID[rhsMappingID] ?? Int.max
        if lhsMappingPriority != rhsMappingPriority {
            return lhsMappingPriority < rhsMappingPriority
        }
        let lhsTimeRank = timeFitRank(lhs.timeFit)
        let rhsTimeRank = timeFitRank(rhs.timeFit)
        if lhsTimeRank != rhsTimeRank {
            return lhsTimeRank < rhsTimeRank
        }
        if lhs.estimatedDurationMinutes != rhs.estimatedDurationMinutes {
            switch (lhs.estimatedDurationMinutes, rhs.estimatedDurationMinutes) {
            case let (.some(left), .some(right)): return left < right
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): break
            }
        }
        let lhsPriority = routinePriorityByID[lhs.routineID] ?? Int.max
        let rhsPriority = routinePriorityByID[rhs.routineID] ?? Int.max
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        if lhs.routineID != rhs.routineID {
            return lhs.routineID < rhs.routineID
        }
        return lhs.movementID < rhs.movementID
    }

    private static func timeFitRank(_ fit: MobilityTargetedRoutineTimeFit) -> Int {
        switch fit {
        case .fitsBudget: 0
        case .notConstrained: 1
        case .durationUnknown: 2
        }
    }
}

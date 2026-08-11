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
        var recommendationsByMeasurement: [String: [MobilityTargetedRoutineRecommendation]] = [:]

        for measurement in profile.measurements {
            guard let measurementEligibility = eligibility(for: measurement) else { continue }
            let matchingMappings = validMappings
                .filter {
                    $0.protocolID == measurement.protocolID
                        && $0.protocolVersion == measurement.protocolVersion
                }
                .sorted { mappingPrecedes($0, $1) }

            for mapping in matchingMappings {
                for routine in validRoutines where routine.movementIDs.contains(mapping.movementID) {
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
            guard let measurement = profile.measurements.first(where: { $0.id == measurementID }),
                  let eligibility = eligibility(for: measurement)
            else { return nil }
            let ordered = (recommendationsByMeasurement[measurementID] ?? [])
                .sorted { lhs, rhs in
                    recommendationPrecedes(lhs, rhs, routines: validRoutines, mappings: validMappings)
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
        routines: [MobilityTargetedRoutineCandidate],
        mappings: [MobilityAssessmentMovementMapping]
    ) -> Bool {
        if lhs.relevance.sortRank != rhs.relevance.sortRank {
            return lhs.relevance.sortRank < rhs.relevance.sortRank
        }
        let lhsMapping = mappings.first {
            $0.protocolID == lhs.why.protocolID
                && $0.protocolVersion == lhs.why.protocolVersion
                && $0.movementID == lhs.movementID
        }
        let rhsMapping = mappings.first {
            $0.protocolID == rhs.why.protocolID
                && $0.protocolVersion == rhs.why.protocolVersion
                && $0.movementID == rhs.movementID
        }
        if lhsMapping?.priority != rhsMapping?.priority {
            return (lhsMapping?.priority ?? Int.max) < (rhsMapping?.priority ?? Int.max)
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
        let lhsPriority = routines.first { $0.routineID == lhs.routineID }?.priority ?? Int.max
        let rhsPriority = routines.first { $0.routineID == rhs.routineID }?.priority ?? Int.max
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

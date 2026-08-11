import Foundation

/// Raw value carried by one profile measurement. The profile never converts a
/// missing value into zero and never turns criteria evidence into a number.
enum MobilityAssessmentProfileValue: Equatable, Sendable {
    case missing(unit: MobilityMeasurementUnit)
    case numeric(value: Double, unit: MobilityMeasurementUnit)
    case criteria(value: MobilityAssessmentCriteriaObservation, unit: MobilityMeasurementUnit)
}

enum MobilityAssessmentProfileHistory: Equatable, Sendable {
    case noPriorObservation
    case directlyComparableDelta(Double)
    case directlyComparableWithoutNumericDelta
    case notComparable(differingConditions: [MobilityAssessmentConditionDifference])
}

/// Band state is deliberately neutral. It says whether a protocol-bound
/// comparison exists, never whether a person is good/bad or safe/unsafe.
enum MobilityAssessmentProfileBandState: Equatable, Sendable {
    case notMeasured
    case notAuthored
    case incompatibleProtocol
    case notNumeric
    case positioned(MobilityAssessmentProfileBandEvidence)
}

/// The exact authored comparison context carried alongside a positioned
/// observation. Keeping provenance here prevents a UI or recommendation
/// layer from reconstructing a band explanation from a position alone.
struct MobilityAssessmentProfileBandEvidence: Codable, Equatable, Hashable, Sendable {
    let position: MobilityReferenceBandPosition
    let lowerBound: Double?
    let upperBound: Double?
    let unit: MobilityMeasurementUnit
    let rulesetVersion: Int
    let sourceCitation: String
    let populationDescription: String
    let limitations: String

    /// Returns a raw-unit distance only for a below-band observation with an
    /// authored lower bound. No conversion or cross-unit normalization occurs.
    func distanceBelowLowerBound(for observedValue: Double) -> Double? {
        guard position == .below,
              let lowerBound,
              observedValue.isFinite,
              lowerBound.isFinite,
              observedValue < lowerBound
        else { return nil }
        return lowerBound - observedValue
    }
}

struct MobilityAssessmentProfileMeasurement: Equatable, Identifiable, Sendable {
    let id: String
    let protocolID: String
    let protocolVersion: Int
    let testName: String
    let side: MobilityAssessmentSide
    let expectedUnit: MobilityMeasurementUnit
    let value: MobilityAssessmentProfileValue
    let resultID: UUID?
    let recordedAt: Date?
    let actualMethod: MobilityMeasurementMode?
    let actualSource: MobilityMeasurementSource?
    let history: MobilityAssessmentProfileHistory
    let band: MobilityAssessmentProfileBandState

    var bandEvidence: MobilityAssessmentProfileBandEvidence? {
        guard case let .positioned(evidence) = band else { return nil }
        return evidence
    }
}

enum MobilityAssessmentProfileSideDifference: Equatable, Sendable {
    case missingObservation
    case notNumeric
    case incompatibleUnits
    case available(gap: Double, unit: MobilityMeasurementUnit)
}

struct MobilityAssessmentProfileSideGap: Equatable, Identifiable, Sendable {
    let id: String
    let protocolID: String
    let protocolVersion: Int
    let unit: MobilityMeasurementUnit
    let difference: MobilityAssessmentProfileSideDifference
}

struct MobilityAssessmentProfileCoverage: Equatable, Sendable {
    let expectedCount: Int
    let measuredCount: Int
    let missingProtocolIDs: [String]

    var isComplete: Bool {
        expectedCount > 0 && measuredCount == expectedCount
    }
}

struct MobilityAssessmentProfile: Equatable, Sendable {
    let measurements: [MobilityAssessmentProfileMeasurement]
    let sideGaps: [MobilityAssessmentProfileSideGap]
    let coverage: MobilityAssessmentProfileCoverage
}

/// Builds a read-only mobility profile over immutable assessment results.
///
/// The service intentionally accepts protocols and bands as value inputs. It
/// does not fetch, mutate, or persist a profile entity, and it has no global
/// score or zone-level aggregate. A caller can therefore rebuild the same
/// projection from local domain truth after a catalog change without rewriting
/// historical results.
@MainActor
enum MobilityAssessmentProfileProjectionService {
    static func project(
        protocols: [MobilityAssessmentProtocol],
        results: [MobilityAssessmentResult],
        bands: [MobilityReferenceBand] = []
    ) -> MobilityAssessmentProfile {
        let uniqueProtocols = uniqueProtocols(protocols)
        let measurements = uniqueProtocols.map { protocolValue in
            makeMeasurement(
                for: protocolValue,
                results: results,
                bands: bands
            )
        }

        let expectedIDs = Set(uniqueProtocols.map(expectedID(for:)))
        let measuredIDs = Set(measurements.compactMap { measurement in
            measurement.resultID == nil ? nil : measurement.id
        })
        let missing = uniqueProtocols
            .filter { protocolValue in
                measuredIDs.contains(expectedID(for: protocolValue)) == false
            }
            .map(\.protocolID)

        return MobilityAssessmentProfile(
            measurements: measurements,
            sideGaps: makeSideGaps(
                protocols: uniqueProtocols,
                measurements: measurements
            ),
            coverage: MobilityAssessmentProfileCoverage(
                expectedCount: expectedIDs.count,
                measuredCount: measuredIDs.count,
                missingProtocolIDs: missing
            )
        )
    }

    private static func uniqueProtocols(
        _ protocols: [MobilityAssessmentProtocol]
    ) -> [MobilityAssessmentProtocol] {
        var byID: [String: MobilityAssessmentProtocol] = [:]
        for protocolValue in protocols {
            // A profile slot is one exact protocol/version/side. Duplicate
            // authoring input must not inflate coverage or produce duplicate
            // rows; the first authored value remains deterministic.
            byID[expectedID(for: protocolValue)] = byID[expectedID(for: protocolValue)] ?? protocolValue
        }
        return byID.values.sorted {
            if $0.protocolID == $1.protocolID {
                if $0.protocolVersion == $1.protocolVersion {
                    return sideOrder($0.side) < sideOrder($1.side)
                }
                return $0.protocolVersion < $1.protocolVersion
            }
            return $0.protocolID < $1.protocolID
        }
    }

    private static func makeMeasurement(
        for protocolValue: MobilityAssessmentProtocol,
        results: [MobilityAssessmentResult],
        bands: [MobilityReferenceBand]
    ) -> MobilityAssessmentProfileMeasurement {
        let id = expectedID(for: protocolValue)
        guard let result = latestResult(for: protocolValue, among: results) else {
            return MobilityAssessmentProfileMeasurement(
                id: id,
                protocolID: protocolValue.protocolID,
                protocolVersion: protocolValue.protocolVersion,
                testName: protocolValue.testName,
                side: protocolValue.side,
                expectedUnit: protocolValue.unit,
                value: .missing(unit: protocolValue.unit),
                resultID: nil,
                recordedAt: nil,
                actualMethod: nil,
                actualSource: nil,
                history: .noPriorObservation,
                band: .notMeasured
            )
        }

        let value = profileValue(from: result)
        let matchingHistory = results.filter {
            $0.definitionCatalogueKeySnapshot == result.definitionCatalogueKeySnapshot
                && $0.side == result.side
                && $0.definitionVersionSnapshot == result.definitionVersionSnapshot
        }
        let history = history(for: result, among: matchingHistory)
        let band = bandState(
            for: protocolValue,
            result: result,
            value: value,
            bands: bands
        )

        return MobilityAssessmentProfileMeasurement(
            id: id,
            protocolID: protocolValue.protocolID,
            protocolVersion: protocolValue.protocolVersion,
            testName: protocolValue.testName,
            side: protocolValue.side,
            expectedUnit: protocolValue.unit,
            value: value,
            resultID: result.id,
            recordedAt: result.createdAt,
            actualMethod: result.method,
            actualSource: result.source,
            history: history,
            band: band
        )
    }

    private static func latestResult(
        for protocolValue: MobilityAssessmentProtocol,
        among results: [MobilityAssessmentResult]
    ) -> MobilityAssessmentResult? {
        results
            .filter {
                $0.definitionCatalogueKeySnapshot == protocolValue.protocolID
                    && $0.side == protocolValue.side
            }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString > $1.id.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
            .first
    }

    private static func profileValue(
        from result: MobilityAssessmentResult
    ) -> MobilityAssessmentProfileValue {
        if let numericValue = result.numericValue, numericValue.isFinite {
            return .numeric(value: numericValue, unit: result.unit)
        }
        if let criteria = result.criteria {
            return .criteria(value: criteria, unit: result.unit)
        }
        return .missing(unit: result.unit)
    }

    private static func history(
        for result: MobilityAssessmentResult,
        among results: [MobilityAssessmentResult]
    ) -> MobilityAssessmentProfileHistory {
        let comparison = MobilityAssessmentComparisonService.latestComparison(
            for: result,
            among: results
        )
        guard comparison.previousResultID != nil else {
            return .noPriorObservation
        }
        switch comparison.comparability {
        case .direct:
            if let delta = comparison.numericDelta, delta.isFinite {
                return .directlyComparableDelta(delta)
            }
            return .directlyComparableWithoutNumericDelta
        case .notDirect:
            return .notComparable(differingConditions: comparison.differingConditions)
        }
    }

    private static func bandState(
        for protocolValue: MobilityAssessmentProtocol,
        result: MobilityAssessmentResult,
        value: MobilityAssessmentProfileValue,
        bands: [MobilityReferenceBand]
    ) -> MobilityAssessmentProfileBandState {
        guard protocolValue.validate() == nil,
              exactProtocolMatch(protocolValue, result: result)
        else {
            return .incompatibleProtocol
        }
        guard let band = bands.first(where: {
            $0.protocolID == protocolValue.protocolID
                && $0.protocolVersion == protocolValue.protocolVersion
        }) else {
            return .notAuthored
        }
        guard band.validate(against: protocolValue) == nil else {
            return .incompatibleProtocol
        }
        guard case let .numeric(numericValue, unit) = value else {
            return .notNumeric
        }
        guard unit == protocolValue.unit,
              let position = band.classify(numericValue)
        else {
            return .incompatibleProtocol
        }
        return .positioned(
            MobilityAssessmentProfileBandEvidence(
                position: position,
                lowerBound: band.lowerBound,
                upperBound: band.upperBound,
                unit: band.unit,
                rulesetVersion: band.rulesetVersion,
                sourceCitation: band.sourceCitation,
                populationDescription: band.populationDescription,
                limitations: band.limitations
            )
        )
    }

    /// Result conditions are compared against the authored protocol before a
    /// reference band is shown. Manual entry is allowed only when the protocol
    /// explicitly offers a manual fallback; imported observations never
    /// acquire a local protocol interpretation by inference.
    private static func exactProtocolMatch(
        _ protocolValue: MobilityAssessmentProtocol,
        result: MobilityAssessmentResult
    ) -> Bool {
        guard result.definitionCatalogueKeySnapshot == protocolValue.protocolID,
              result.definitionVersionSnapshot == protocolValue.protocolVersion,
              result.side == protocolValue.side,
              result.unit == protocolValue.unit,
              protocolValue.setupKey.map({ $0 == result.setupKey }) ?? true,
              result.isActiveRange == (protocolValue.activePassive == .active),
              let actualMethod = actualMethod(for: result)
        else {
            return false
        }

        switch actualMethod {
        case .manual:
            return protocolValue.preferredMethod == .manual || protocolValue.manualFallback
        case .inclinometer, .deviceMotion:
            return protocolValue.preferredMethod == actualMethod
        }
    }

    private static func actualMethod(
        for result: MobilityAssessmentResult
    ) -> MobilityAssessmentProtocol.Method? {
        switch result.source {
        case .manual:
            return result.method.isManual ? .manual : nil
        case .deviceMotion:
            switch result.method {
            case .inclinometer:
                return .inclinometer
            case .axialRotation, .twoSegmentAngle, .dynamicRange:
                return .deviceMotion
            case .manualAngle, .manualLinear, .manualCriteria, .cameraPose:
                return nil
            }
        case .imported:
            return nil
        }
    }

    private static func makeSideGaps(
        protocols: [MobilityAssessmentProtocol],
        measurements: [MobilityAssessmentProfileMeasurement]
    ) -> [MobilityAssessmentProfileSideGap] {
        let measurementByID = Dictionary(uniqueKeysWithValues: measurements.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: protocols) {
            "\($0.protocolID)|\($0.protocolVersion)"
        }

        return grouped.compactMap { key, values in
            guard let left = values.first(where: { $0.side == .left }),
                  let right = values.first(where: { $0.side == .right })
            else { return nil }

            let leftMeasurement = measurementByID[expectedID(for: left)]
            let rightMeasurement = measurementByID[expectedID(for: right)]
            let difference: MobilityAssessmentProfileSideDifference

            guard let leftMeasurement, let rightMeasurement,
                  leftMeasurement.resultID != nil, rightMeasurement.resultID != nil
            else {
                difference = .missingObservation
                return MobilityAssessmentProfileSideGap(
                    id: key,
                    protocolID: left.protocolID,
                    protocolVersion: left.protocolVersion,
                    unit: left.unit,
                    difference: difference
                )
            }

            guard left.unit == right.unit else {
                difference = .incompatibleUnits
                return MobilityAssessmentProfileSideGap(
                    id: key,
                    protocolID: left.protocolID,
                    protocolVersion: left.protocolVersion,
                    unit: left.unit,
                    difference: difference
                )
            }

            guard case let .numeric(leftValue, leftUnit) = leftMeasurement.value,
                  case let .numeric(rightValue, rightUnit) = rightMeasurement.value
            else {
                difference = .notNumeric
                return MobilityAssessmentProfileSideGap(
                    id: key,
                    protocolID: left.protocolID,
                    protocolVersion: left.protocolVersion,
                    unit: left.unit,
                    difference: difference
                )
            }

            guard leftUnit == rightUnit, leftUnit == left.unit else {
                difference = .incompatibleUnits
                return MobilityAssessmentProfileSideGap(
                    id: key,
                    protocolID: left.protocolID,
                    protocolVersion: left.protocolVersion,
                    unit: left.unit,
                    difference: difference
                )
            }

            difference = .available(
                gap: abs(leftValue - rightValue),
                unit: leftUnit
            )
            return MobilityAssessmentProfileSideGap(
                id: key,
                protocolID: left.protocolID,
                protocolVersion: left.protocolVersion,
                unit: leftUnit,
                difference: difference
            )
        }
        .sorted { $0.id < $1.id }
    }

    private static func expectedID(
        for protocolValue: MobilityAssessmentProtocol
    ) -> String {
        "\(protocolValue.protocolID)|v\(protocolValue.protocolVersion)|\(protocolValue.side.rawValue)"
    }

    private static func sideOrder(_ side: MobilityAssessmentSide) -> Int {
        switch side {
        case .left: 0
        case .right: 1
        case .combined: 2
        }
    }
}

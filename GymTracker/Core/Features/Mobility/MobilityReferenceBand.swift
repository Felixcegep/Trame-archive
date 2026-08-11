import Foundation

/// An evidence-backed interval for one exact mobility protocol and population.
/// Bands are authored data, not universal targets or a score input.
struct MobilityReferenceBand: Codable, Equatable, Hashable, Identifiable, Sendable {
    let protocolID: String
    let protocolVersion: Int
    let unit: MobilityMeasurementUnit
    let lowerBound: Double?
    let upperBound: Double?
    let sourceCitation: String
    let populationDescription: String
    let rulesetVersion: Int
    let limitations: String
    let measurementError: MobilityAssessmentMeasurementError?

    /// A deterministic identity for a band revision within a population.
    /// Population is included because the same protocol/ruleset may have
    /// separately authored comparison bands.
    var id: String {
        [protocolID, String(protocolVersion), String(rulesetVersion), populationDescription]
            .joined(separator: "|")
    }

    init(
        protocolID: String,
        protocolVersion: Int,
        unit: MobilityMeasurementUnit,
        lowerBound: Double? = nil,
        upperBound: Double? = nil,
        sourceCitation: String,
        populationDescription: String,
        rulesetVersion: Int,
        limitations: String,
        measurementError: MobilityAssessmentMeasurementError? = nil
    ) {
        self.protocolID = protocolID
        self.protocolVersion = protocolVersion
        self.unit = unit
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.sourceCitation = sourceCitation
        self.populationDescription = populationDescription
        self.rulesetVersion = rulesetVersion
        self.limitations = limitations
        self.measurementError = measurementError
    }
}

enum MobilityReferenceBandValidationError: Error, Equatable, Sendable {
    case emptyProtocolID
    case invalidProtocolVersion
    case missingBounds
    case nonFiniteBound
    case invertedBounds
    case emptySourceCitation
    case emptyPopulationDescription
    case invalidRulesetVersion
    case emptyLimitations
    case invalidMeasurementError
    case protocolMismatch
    case unitMismatch
}

enum MobilityReferenceBandPosition: String, Codable, Equatable, Hashable, Sendable {
    case below
    case within
    case above
}

extension MobilityReferenceBand {
    func validate() -> MobilityReferenceBandValidationError? {
        guard protocolID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyProtocolID
        }
        guard protocolVersion > 0 else { return .invalidProtocolVersion }
        guard lowerBound != nil || upperBound != nil else { return .missingBounds }

        let bounds = [lowerBound, upperBound]
        guard bounds.allSatisfy({ value in
            guard let value else { return true }
            return value.isFinite
        }) else {
            return .nonFiniteBound
        }
        if let lowerBound, let upperBound, lowerBound > upperBound {
            return .invertedBounds
        }
        guard sourceCitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptySourceCitation
        }
        guard populationDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyPopulationDescription
        }
        guard rulesetVersion > 0 else { return .invalidRulesetVersion }
        guard limitations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyLimitations
        }

        if let measurementError {
            let values = [
                measurementError.standardErrorOfMeasurement,
                measurementError.minimalDetectableChange
            ]
            guard values.contains(where: { $0 != nil }),
                  values.allSatisfy({ value in
                      guard let value else { return true }
                      return value.isFinite && value >= 0
                  })
            else {
                return .invalidMeasurementError
            }
        }

        return nil
    }

    func validate(
        against protocolValue: MobilityAssessmentProtocol
    ) -> MobilityReferenceBandValidationError? {
        guard validate() == nil else { return validate() }
        guard protocolID == protocolValue.protocolID,
              protocolVersion == protocolValue.protocolVersion
        else { return .protocolMismatch }
        guard unit == protocolValue.unit else { return .unitMismatch }
        return nil
    }

    /// Returns nil for absent/non-finite observations. Missing is not treated
    /// as zero and therefore cannot acquire a band position.
    func classify(_ value: Double?) -> MobilityReferenceBandPosition? {
        guard let value, value.isFinite else { return nil }
        if let lowerBound, value < lowerBound { return .below }
        if let upperBound, value > upperBound { return .above }
        return .within
    }
}

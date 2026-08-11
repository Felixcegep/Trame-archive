import Foundation

/// The small authored bridge between seeded catalogue definitions and the
/// device-motion adapter. A sensor axis is never inferred from a definition's
/// name or from its preferred mode alone.
struct MobilityInclinometerDefinition: Equatable, Sendable {
    let catalogueKey: String
    let axis: MobilityInclinometerAxis
    let mode: MobilityInclinometerCaptureMode
    let placementGuidance: String

    var configuration: MobilityInclinometerCaptureConfiguration {
        MobilityInclinometerCaptureConfiguration(axis: axis, mode: mode)
    }

    /// Mobility range is recorded as a non-negative magnitude. Core Motion's
    /// sign describes rotation direction in the phone coordinate system and
    /// flips with placement/side; it is not a left-versus-right result value.
    func resultDegrees(from signedDeviceDegrees: Double) -> Double {
        min(180, abs(signedDeviceDegrees))
    }
}

enum MobilityInclinometerDefinitionRegistry {
    /// Only degree-based seeded definitions with a defensible single-device
    /// orientation are offered. Linear and two-segment tests remain manual.
    static let seeded: [MobilityInclinometerDefinition] = [
        MobilityInclinometerDefinition(
            catalogueKey: "mobility-assessment.thoracic-rotation-seated",
            axis: .yaw,
            mode: .relativeRotation,
            placementGuidance: "Place the device flat on the upper chest and keep the hips still."
        ),
        MobilityInclinometerDefinition(
            catalogueKey: "mobility-assessment.open-book-rotation",
            axis: .yaw,
            mode: .relativeRotation,
            placementGuidance: "Place the device flat on the upper chest and keep the knees stacked."
        ),
        MobilityInclinometerDefinition(
            catalogueKey: "mobility-assessment.active-straight-leg-raise",
            axis: .pitch,
            mode: .gravityReferenced,
            placementGuidance: "Place the device along the raised leg and keep the pelvis still."
        ),
        MobilityInclinometerDefinition(
            catalogueKey: "mobility-assessment.soleus-wall-stretch",
            axis: .pitch,
            mode: .gravityReferenced,
            placementGuidance: "Place the device along the shin and keep the heel down."
        ),
        MobilityInclinometerDefinition(
            catalogueKey: "mobility-assessment.wall-slide-arm-elevation",
            axis: .pitch,
            mode: .gravityReferenced,
            placementGuidance: "Place the device along the upper arm and keep the ribs stacked."
        )
    ]

    static func definition(
        catalogueKey: String,
        unit: MobilityMeasurementUnit,
        preferredMode: MobilityMeasurementMode
    ) -> MobilityInclinometerDefinition? {
        guard unit == .degrees,
              preferredMode == .inclinometer || preferredMode == .axialRotation
        else { return nil }
        return seeded.first {
            $0.catalogueKey == catalogueKey
                && ($0.mode == .gravityReferenced && preferredMode == .inclinometer
                    || $0.mode == .relativeRotation && preferredMode == .axialRotation)
        }
    }

    static func definition(for definition: MobilityAssessmentDefinition) -> MobilityInclinometerDefinition? {
        self.definition(
            catalogueKey: definition.catalogueKey,
            unit: definition.unit,
            preferredMode: definition.preferredMode
        )
    }
}

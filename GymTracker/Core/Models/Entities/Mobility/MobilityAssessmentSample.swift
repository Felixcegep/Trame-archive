import Foundation
import SwiftData

/// Bounded raw evidence for a qualifying hold. 3c manual results have no
/// sample; 3d can attach one without changing the session/result contract.
@Model
final class MobilityAssessmentSample {
    var id: UUID
    var sampleCount: Int
    var median: Double
    var minimum: Double
    var maximum: Double
    var standardDeviation: Double
    var offAxisExcessDegrees: Double
    var captureDuration: TimeInterval
    var createdAt: Date
    var result: MobilityAssessmentResult?

    init(
        sampleCount: Int,
        median: Double,
        minimum: Double,
        maximum: Double,
        standardDeviation: Double,
        offAxisExcessDegrees: Double,
        captureDuration: TimeInterval,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.sampleCount = sampleCount
        self.median = median
        self.minimum = minimum
        self.maximum = maximum
        self.standardDeviation = standardDeviation
        self.offAxisExcessDegrees = offAxisExcessDegrees
        self.captureDuration = captureDuration
        self.createdAt = createdAt
    }
}

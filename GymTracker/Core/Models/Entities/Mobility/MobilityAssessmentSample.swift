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

    /// Constructs a MobilityAssessmentSample from repeated trial measurements.
    static func create(from trials: [Double], createdAt: Date = .now) -> MobilityAssessmentSample? {
        guard trials.isEmpty == false, trials.allSatisfy(\.isFinite) else { return nil }
        let sorted = trials.sorted()
        let count = sorted.count
        guard let min = sorted.first, let max = sorted.last else { return nil }
        let median: Double
        if count % 2 == 1 {
            median = sorted[count / 2]
        } else {
            median = (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        }
        let mean = trials.reduce(0.0, +) / Double(count)
        let variance = trials.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(count)
        let stdDev = sqrt(variance)
        return MobilityAssessmentSample(
            sampleCount: count,
            median: median,
            minimum: min,
            maximum: max,
            standardDeviation: stdDev,
            offAxisExcessDegrees: 0.0,
            captureDuration: 0.0,
            createdAt: createdAt
        )
    }
}

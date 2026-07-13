import Foundation

enum UnitConversion {
    private static let poundsPerKilogram: Float = 2.204_622_6

    static func weight(_ value: Float, from source: WeightType, to target: WeightType) -> Float {
        guard source != target else { return value }
        return switch (source, target) {
        case (.kg, .lbs):
            value * poundsPerKilogram
        case (.lbs, .kg):
            value / poundsPerKilogram
        default:
            value
        }
    }

    static func distance(_ value: Float, from source: DistanceType, to target: DistanceType) -> Float {
        guard source != target else { return value }
        let meters: Float
        switch source {
        case .meters: meters = value
        case .kilometers: meters = value * 1_000
        case .miles: meters = value * 1_609.344
        }

        switch target {
        case .meters: return meters
        case .kilometers: return meters / 1_000
        case .miles: return meters / 1_609.344
        }
    }
}

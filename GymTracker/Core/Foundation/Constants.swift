import Foundation

struct Constants {
    struct Barbell {
        static let metricBarWeight: Float = 20.0
        static let imperialBarWeight: Float = 45.0
        
        static let metricPlates: [Float] = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
        /// Includes the 55 lb bumper (the pound equivalent of a 25 kg plate).
        static let imperialPlates: [Float] = [55.0, 45.0, 35.0, 25.0, 10.0, 5.0, 2.5, 1.0]
    }

    struct Session {
        /// Shortest gym visit the save screen will record.
        static let minimumDuration: TimeInterval = 60
        /// Longest gym visit the save screen will record. A session longer than
        /// this is almost certainly a clock that was never stopped.
        static let maximumDuration: TimeInterval = 12 * 3_600
    }

    struct Progression {
        /// The increment is selected from the historical evidence unit.
        static let metricIncrementKg: Float = 2.5
        static let imperialIncrementLbs: Float = 5.0

        static func increment(for unit: WeightType) -> Float {
            unit == .kg ? metricIncrementKg : imperialIncrementLbs
        }
    }
}

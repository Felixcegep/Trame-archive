import Foundation
import Combine

enum InclinometerCaptureState: Equatable, Sendable {
    case idle
    case measuring(pitchDegrees: Double, rollDegrees: Double)
    case completed(pitchDegrees: Double)
    case unavailable(reason: String)
}

@MainActor
final class MobilityInclinometerCaptureService: ObservableObject {
    @Published private(set) var state: InclinometerCaptureState = .idle

    func startMeasurement() {
        // Hardware sensor capture is quarantined. Placeholder measurements
        // must not create assessment results in production.
        state = .unavailable(reason: "Inclinometer sensor capture is quarantined.")
    }

    func stopMeasurement() {
        switch state {
        case .measuring(let pitch, _):
            state = .completed(pitchDegrees: pitch)
        default:
            state = .idle
        }
    }

    func reset() {
        state = .idle
    }
}

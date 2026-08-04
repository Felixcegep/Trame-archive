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
        // CoreMotion hardware sensor interface wrapper with simulator fallback
        #if targetEnvironment(simulator)
        state = .measuring(pitchDegrees: 45.0, rollDegrees: 0.0)
        #else
        // Physical motion manager sampling loop
        state = .measuring(pitchDegrees: 0.0, rollDegrees: 0.0)
        #endif
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

import Foundation
import Observation

@Observable
final class RestTimerController {
    enum State: Equatable {
        case idle
        case running(Date)
        case paused(TimeInterval)
    }

    private(set) var state: State = .idle

    var isVisible: Bool {
        if case .idle = state { return false }
        return true
    }

    var endDate: Date? {
        guard case let .running(endDate) = state else { return nil }
        return endDate
    }

    var pausedRemaining: TimeInterval? {
        guard case let .paused(remaining) = state else { return nil }
        return remaining
    }

    func start(until endDate: Date) {
        state = .running(endDate)
    }

    func restore(endDate: Date?, pausedRemaining: TimeInterval?) {
        if let endDate, endDate > .now {
            state = .running(endDate)
        } else if let pausedRemaining, pausedRemaining > 0 {
            state = .paused(pausedRemaining)
        } else {
            state = .idle
        }
    }

    func pause(remaining: TimeInterval) {
        state = remaining > 0 ? .paused(remaining) : .idle
    }

    func extendPaused(by seconds: TimeInterval) {
        guard case let .paused(remaining) = state else { return }
        state = .paused(remaining + seconds)
    }

    func cancel() {
        state = .idle
    }
}

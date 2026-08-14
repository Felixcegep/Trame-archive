import Foundation
import Observation

@Observable
final class RestTimerSession {
    enum State: Equatable {
        case idle
        case running(Date)
        case paused(TimeInterval)
        case ready
    }

    private(set) var state: State = .idle

    /// How long this rest period was *meant* to last, in seconds.
    ///
    /// Persisted rest state is a deadline (`Workout.restEndDate`) and nothing
    /// else, which is enough to render a countdown but not enough to render a
    /// ring: "1:12 left" answers a different question than "you are two thirds
    /// through". The rest takeover asks the second one, so the planned length
    /// is tracked here alongside the deadline.
    ///
    /// It is deliberately **in-memory only**. A cold launch mid-rest restores
    /// the deadline from SwiftData and leaves this `nil`, and the takeover
    /// simply drops the ring and keeps the digits — a degraded reading rather
    /// than a wrong one. Persisting it would mean a schema migration for a
    /// progress arc, which is not a trade worth making.
    private(set) var plannedDuration: TimeInterval?

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

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    func start(until endDate: Date) {
        state = .running(endDate)
    }

    /// Records how long the rest period that is now running was meant to be.
    /// Called by the view model at the one place a rest is *started* from a
    /// known duration; restores deliberately leave it alone.
    func planDuration(_ seconds: TimeInterval?) {
        plannedDuration = seconds.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Grows the planned length alongside the deadline.
    ///
    /// Without this, "+30s" would push the deadline past a total that stayed
    /// fixed, and the ring would report more time remaining than the rest was
    /// ever supposed to have — a progress arc reading over 100%.
    func extendPlannedDuration(by seconds: TimeInterval) {
        guard let plannedDuration else { return }
        self.plannedDuration = max(0, plannedDuration + seconds)
    }

    func restore(endDate: Date?, pausedRemaining: TimeInterval?) {
        if let endDate {
            state = endDate > .now ? .running(endDate) : .ready
        } else if let pausedRemaining, pausedRemaining > 0 {
            state = .paused(pausedRemaining)
        } else {
            state = .idle
        }
    }

    func pause(remaining: TimeInterval) {
        state = remaining > 0 ? .paused(remaining) : .idle
    }

    func ready() {
        state = .ready
    }

    func extendPaused(by seconds: TimeInterval) {
        guard case let .paused(remaining) = state else { return }
        state = .paused(remaining + seconds)
    }

    func cancel() {
        state = .idle
        plannedDuration = nil
    }
}

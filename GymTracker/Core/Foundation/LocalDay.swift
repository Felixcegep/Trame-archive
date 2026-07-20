import Foundation

/// A stable, calendar-day key for user-owned daily records. The key is derived
/// in the user's current calendar and time zone; timestamps remain available on
/// the owning records for audit and ordering.
struct LocalDay: Codable, Hashable, Comparable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.rawValue = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static var today: LocalDay { LocalDay(date: .now) }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

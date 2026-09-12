import Foundation

/// A stable, calendar-day key for user-owned daily records. The key is derived
/// in the user's current calendar and time zone; timestamps remain available on
/// the owning records for audit and ordering.
nonisolated struct LocalDay: Codable, Hashable, Comparable, Sendable, RawRepresentable {
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

    func adding(days: Int, calendar: Calendar = .current) -> LocalDay {
        guard let date = startDate(calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: days, to: date)
        else { return self }
        return LocalDay(date: shifted, calendar: calendar)
    }

    func startDate(calendar: Calendar = .current) -> Date? {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    func displayName(relativeTo today: LocalDay = .today) -> String {
        if self == today { return "Today" }
        if self == today.adding(days: -1) { return "Yesterday" }
        if self == today.adding(days: 1) { return "Tomorrow" }
        return rawValue
    }
}

import Foundation

struct Formatters {
    // Cached, thread-safe date formatter
    static let workoutDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Keep numeric labels compact and stable while avoiding raw Float precision noise.
    static func formatFloat(_ value: Float) -> String {
        value.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...2))
        )
    }

    static func formatEstimatedLoad(_ value: Float) -> String {
        value.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0))
        )
    }

    static func sessionDuration(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration) / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 {
            return String(localized: "\(hours)h \(remainder)m")
        }
        return String(localized: "\(max(1, minutes)) min")
    }

    static func formatGroupedMetric(_ value: Float) -> String {
        value.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(0...1))
        )
    }
}

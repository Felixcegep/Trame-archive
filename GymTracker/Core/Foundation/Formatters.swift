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
}

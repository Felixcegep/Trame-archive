import Foundation

struct Formatters {
    // Cached, thread-safe date formatter
    static let workoutDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Unifies the trailing-zero removal logic for floats (weights, distances, reps)
    static func formatFloat(_ value: Float) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}

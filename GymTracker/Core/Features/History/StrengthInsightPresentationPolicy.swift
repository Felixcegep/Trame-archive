import Foundation

enum StrengthInsightPresentationPolicy {
    static func changeSummary(for analytics: ExerciseDetailAnalytics) -> String? {
        guard let comparison = analytics.sessionComparison, let latest = analytics.latestSession else { return nil }
        let unit = comparison.unit.rawValue
        let latestSets = latest.workingSets.map {
            "\(Formatters.formatFloat(UnitConversion.weight($0.weight, from: $0.weightType, to: comparison.unit))) \(unit) × \(Formatters.formatFloat($0.repetitions))"
        }.joined(separator: ", ")
        let volumeChange = comparison.latestVolume - comparison.previousVolume
        let volumeText: String
        if comparison.previousVolume > 0 {
            let percentage = Int((abs(volumeChange / comparison.previousVolume) * 100).rounded())
            if percentage == 0 {
                volumeText = "Volume was about the same."
            } else {
                volumeText = "Volume was \(percentage)% \(volumeChange > 0 ? "higher" : "lower") than the previous session."
            }
        } else {
            volumeText = "The previous session has no comparable working-set volume."
        }
        return "You completed \(latestSets). \(volumeText)"
    }

    static func volumeTakeaway(sessionCount: Int, weeklyVolumes: [Float]) -> String? {
        guard sessionCount > 0 else { return nil }
        guard sessionCount >= 4, weeklyVolumes.count >= 8 else {
            return "Early pattern — based on \(sessionCount) completed \(sessionCount == 1 ? "session" : "sessions")."
        }

        let previous = weeklyVolumes.prefix(4).reduce(Float.zero, +)
        let recent = weeklyVolumes.suffix(4).reduce(Float.zero, +)
        guard previous > 0 else {
            return "The recent four weeks contain completed work, but there is no earlier four-week baseline."
        }
        let change = (recent - previous) / previous
        let percentage = Int((abs(change) * 100).rounded())
        if percentage < 5 {
            return "Weekly volume was about the same across the recent and previous four weeks."
        }
        return "The recent four weeks contained \(percentage)% \(change > 0 ? "more" : "less") completed volume than the previous four weeks."
    }
}

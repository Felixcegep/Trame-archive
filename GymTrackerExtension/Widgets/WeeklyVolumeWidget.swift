import SwiftUI
import WidgetKit

struct WeeklyVolumeWidget: Widget {
    let kind = "WeeklyVolumeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            WeeklyVolumeWidgetView(data: entry.snapshot.weeklyVolume)
                .containerBackground(Color.gymCard, for: .widget)
        }
        .configurationDisplayName("Weekly Volume")
        .description("Shows this week's completed workouts, sets, and load volume.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WeeklyVolumeWidgetView: View {
    let data: WeeklyVolumeWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This Week").font(.caption).foregroundStyle(Color.gymSubduedText)
            Text("\(data.completedWorkoutCount)").font(.title).bold().foregroundStyle(Color.gymText)
            Text(data.completedWorkoutCount == 1 ? "workout" : "workouts").font(.caption).foregroundStyle(Color.gymSubduedText)
            Spacer(minLength: 4)
            Text("\(data.workingSetCount) working sets").font(.subheadline).foregroundStyle(Color.gymText)
            if let loadVolume = data.loadVolume, let unitSymbol = data.unitSymbol {
                Text("\(Int(loadVolume)) \(unitSymbol) volume").font(.caption).foregroundStyle(Color.gymSubduedText)
            }
        }
    }
}

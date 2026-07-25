import SwiftUI
import WidgetKit

struct TodayWorkoutWidget: Widget {
    let kind = "TodayWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            TodayWorkoutWidgetView(data: entry.snapshot.today)
                .containerBackground(Color.gymCard, for: .widget)
        }
        .configurationDisplayName("Today's Workout")
        .description("Shows today's active or scheduled workout.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct TodayWorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: TodayWidgetData

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title).font(.headline).lineLimit(1)
                Text(subtitle).font(.caption)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("Today").font(.caption).foregroundStyle(Color.gymSubduedText)
                Text(data.title).font(.headline).foregroundStyle(Color.gymText).lineLimit(2)
                Spacer(minLength: 4)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.gymSubduedText)
                if let currentExerciseName = data.currentExerciseName {
                    Text(currentExerciseName).font(.caption).foregroundStyle(Color.gymPrimary).lineLimit(1)
                }
            }
        }
    }

    private var subtitle: String {
        switch data.state {
        case .noWorkout: "No workout scheduled"
        case .activeWorkout, .scheduledWorkout: "\(data.completedSetCount) / \(data.totalSetCount) sets"
        }
    }
}

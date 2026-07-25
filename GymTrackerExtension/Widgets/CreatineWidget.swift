import SwiftUI
import WidgetKit

struct CreatineWidget: Widget {
    let kind = "CreatineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            CreatineWidgetView(data: entry.snapshot.creatine)
                .containerBackground(Color.gymCard, for: .widget)
        }
        .configurationDisplayName("Creatine Today")
        .description("Shows whether today's creatine is confirmed.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

private struct CreatineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: CreatineWidgetData

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: data.isConfirmed ? "checkmark.circle.fill" : "circle")
                .font(.title2)
        case .accessoryRectangular:
            HStack(spacing: 4) {
                Image(systemName: data.isConfirmed ? "checkmark.circle.fill" : "circle")
                Text("Creatine")
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: data.isConfirmed ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(data.isConfirmed ? Color.gymSecondary : Color.gymSubduedText)
                Text("Creatine").font(.subheadline).foregroundStyle(Color.gymText)
                Text(data.isConfirmed ? "Confirmed today" : "Not yet today")
                    .font(.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }
}

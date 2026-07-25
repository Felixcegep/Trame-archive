import SwiftUI
import WidgetKit

struct CaffeineWidget: Widget {
    let kind = "CaffeineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            CaffeineWidgetView(data: entry.snapshot.caffeine)
                .containerBackground(Color.gymCard, for: .widget)
        }
        .configurationDisplayName("Caffeine Today")
        .description("Shows today's logged caffeine against your daily reference.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private struct CaffeineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: CaffeineWidgetData

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: min(data.loggedMilligrams, data.referenceMilligrams ?? data.loggedMilligrams), in: 0...(data.referenceMilligrams ?? max(data.loggedMilligrams, 1))) {
                Text("Caffeine")
            } currentValueLabel: {
                Text("\(Int(data.loggedMilligrams))")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Caffeine").font(.headline)
                Text(subtitle).font(.caption)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("Caffeine").font(.caption).foregroundStyle(Color.gymSubduedText)
                Text("\(Int(data.loggedMilligrams)) mg").font(.title2).bold().foregroundStyle(Color.gymText)
                Spacer(minLength: 4)
                Text(subtitle).font(.caption).foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private var subtitle: String {
        guard let referenceMilligrams = data.referenceMilligrams else {
            return "\(Int(data.loggedMilligrams)) mg logged"
        }
        return "of \(Int(referenceMilligrams)) mg"
    }
}

import SwiftUI
import WidgetKit
import AppIntents

struct QueueMobilityCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete mobility movement"
    static let description = IntentDescription("Opens Trame and safely completes the mobility movement shown by this widget.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Session ID") var sessionID: String
    @Parameter(title: "Entry ID") var entryID: String

    init() {}

    init(sessionID: UUID, entryID: UUID) {
        self.sessionID = sessionID.uuidString
        self.entryID = entryID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let sessionID = UUID(uuidString: sessionID), let entryID = UUID(uuidString: entryID) else {
            return .result()
        }
        try MobilityWidgetCommandStore.submit(
            .init(commandID: UUID(), sessionID: sessionID, entryID: entryID, createdAt: .now)
        )
        return .result()
    }
}

struct MobilityWidget: Widget {
    let kind = "MobilityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            MobilityWidgetView(data: entry.snapshot.mobility ?? .placeholder, generatedAt: entry.snapshot.generatedAt)
                .containerBackground(Color.gymCard, for: .widget)
        }
        .configurationDisplayName(String(localized: "widget.mobility.displayName", defaultValue: "Mobility Today"))
        .description(String(localized: "widget.mobility.description", defaultValue: "Shows an active mobility session or your latest mobility session."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct MobilityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: MobilityWidgetData
    let generatedAt: Date

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: WidgetLayout.compactSpacing) {
                    Text(accessoryTitle).font(.headline).lineLimit(1)
                    Text(accessorySubtitle).font(.caption).lineLimit(1)
                }
            default:
                VStack(alignment: .leading, spacing: WidgetLayout.contentSpacing) {
                    Text(String(localized: "widget.mobility.title", defaultValue: "Mobility"))
                        .font(.caption)
                        .foregroundStyle(Color.gymSubduedText)
                    content
                    Spacer(minLength: WidgetLayout.compactSpacing)
                    Text(String(format: String(localized: "widget.mobility.week", defaultValue: "%lld completed this week"), Int64(data.completedSessionCountThisWeek)))
                        .font(.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("mobility-widget")
    }

    @ViewBuilder
    private var content: some View {
        switch data.state {
        case .activeSession:
            Text(data.title)
                .font(.headline)
                .foregroundStyle(Color.gymText)
                .lineLimit(2)
            if let currentMovementName = data.currentMovementName {
                Text(String(format: String(localized: "widget.mobility.current", defaultValue: "Current: %@"), currentMovementName))
                    .font(.caption)
                    .foregroundStyle(Color.gymPrimary)
                    .lineLimit(1)
            }
            Text(progress)
                .font(.subheadline)
                .foregroundStyle(Color.gymSubduedText)
            if family != .accessoryRectangular,
               let sessionID = data.sessionID,
               let entryID = data.currentEntryID,
               MobilityWidgetActionPolicy.canOfferCompletion(data: data, generatedAt: generatedAt, now: .now) {
                Button(intent: QueueMobilityCompletionIntent(sessionID: sessionID, entryID: entryID)) {
                    Label(
                        String(localized: "widget.mobility.complete", defaultValue: "Complete movement"),
                        systemImage: AppIcon.checkmark
                    )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(String(localized: "widget.mobility.complete.hint", defaultValue: "Opens Trame and verifies this movement is still current before saving."))
            } else if data.state == .activeSession && !isFresh {
                Text(String(localized: "widget.mobility.stale", defaultValue: "Open Trame to refresh"))
                    .font(.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        case .latestCompleted:
            Text(String(localized: "widget.mobility.latest", defaultValue: "Latest session"))
                .font(.subheadline)
                .foregroundStyle(Color.gymSubduedText)
            Text(data.title)
                .font(.headline)
                .foregroundStyle(Color.gymText)
                .lineLimit(2)
        case .noSession:
            Text(String(localized: "widget.mobility.empty", defaultValue: "No mobility session"))
                .font(.headline)
                .foregroundStyle(Color.gymText)
            Text(String(localized: "widget.mobility.empty.detail", defaultValue: "Start one from Trame"))
                .font(.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private var isFresh: Bool {
        generatedAt <= .now && Date.now.timeIntervalSince(generatedAt) <= MobilityWidgetActionPolicy.freshnessInterval
    }

    private var progress: String {
        String(format: String(localized: "widget.mobility.progress", defaultValue: "%lld of %lld movements"), Int64(data.completedEntryCount), Int64(data.totalEntryCount))
    }

    private var accessoryTitle: String {
        switch data.state {
        case .activeSession: String(localized: "widget.mobility.title", defaultValue: "Mobility")
        case .latestCompleted: String(localized: "widget.mobility.latest", defaultValue: "Latest session")
        case .noSession: String(localized: "widget.mobility.title", defaultValue: "Mobility")
        }
    }

    private var accessorySubtitle: String {
        switch data.state {
        case .activeSession:
            String(format: String(localized: "widget.mobility.accessory.active", defaultValue: "%@ · %@/%@"), data.title, "\(data.completedEntryCount)", "\(data.totalEntryCount)")
        case .latestCompleted:
            String(localized: "widget.mobility.accessory.latest", defaultValue: "Latest session")
        case .noSession:
            String(localized: "widget.mobility.accessory.empty", defaultValue: "Not started")
        }
    }

    private var accessibilityLabel: String {
        switch data.state {
        case .activeSession:
            String(format: String(localized: "widget.mobility.accessibility.active", defaultValue: "Mobility session %@, %@ of %@ movements complete"), data.title, "\(data.completedEntryCount)", "\(data.totalEntryCount)")
        case .latestCompleted:
            String(format: String(localized: "widget.mobility.accessibility.latest", defaultValue: "Latest mobility session: %@, %@ completed this week"), data.title, "\(data.completedSessionCountThisWeek)")
        case .noSession:
            String(localized: "widget.mobility.accessibility.empty", defaultValue: "No mobility session started")
        }
    }
}

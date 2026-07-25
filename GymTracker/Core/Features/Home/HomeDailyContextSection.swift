import SwiftData
import SwiftUI

struct HomeDailyContextSection: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isShowingDailyCheckIn: Bool

    @Query private var dailyLogEntries: [DailyLogEntry]
    @Query private var supplementOccurrences: [SupplementOccurrence]

    private var todayDay: LocalDay { .today }

    private var dailyLogEntry: DailyLogEntry? {
        dailyLogEntries.first { $0.dayKey == todayDay.rawValue }
    }

    private var dailyCheckInTitle: String {
        guard let dailyLogEntry else { return "Daily check-in" }
        return dailyLogEntry.status == .completed ? "Daily check-in complete" : "Daily check-in skipped"
    }

    private var dailyCheckInDetail: String {
        guard let dailyLogEntry else { return "Reflect on sleep, energy, and training" }
        return dailyLogEntry.status == .completed ? "You can edit today’s reflection" : "You can still add a reflection"
    }

    private var creatineOccurrence: SupplementOccurrence? {
        supplementOccurrences.first {
            $0.dayKey == todayDay.rawValue && $0.kind == .creatine
        }
    }

    private var creatineTaken: Bool {
        creatineOccurrence?.status == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("TODAY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            Button {
                isShowingDailyCheckIn = true
            } label: {
                HomeDailyContextRow(
                    icon: "text.book.closed",
                    iconColor: Color.gymAccent,
                    title: dailyCheckInTitle,
                    detail: dailyCheckInDetail,
                    completion: dailyLogEntry?.status == .completed
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("open-daily-check-in")

            Button(action: toggleCreatine) {
                HomeDailyContextRow(
                    icon: "drop.fill",
                    iconColor: Color.gymSecondary,
                    title: "Creatine",
                    detail: creatineTaken ? "Confirmed for today" : "Confirm today’s dose",
                    completion: creatineTaken
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("toggle-creatine")
            .accessibilityValue(creatineTaken ? "Confirmed" : "Not confirmed")
        }
    }

    private func toggleCreatine() {
        _ = SupplementOccurrenceService.setCreatine(
            taken: !creatineTaken,
            day: todayDay,
            using: modelContext
        )
    }
}

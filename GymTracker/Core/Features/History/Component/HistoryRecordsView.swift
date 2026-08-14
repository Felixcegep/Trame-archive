import SwiftData
import SwiftUI

struct HistoryRecordsView: View {
    let workouts: [Workout]

    var body: some View {
        let projection = HistoryRecordsProjection.make(
            workouts: workouts,
            displayWeightType: UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        )
        let loadRecords = projection.loadRecords
        let repRecords = projection.repRecords
        let velocity = projection.velocityRecords
        let specialized = projection.specializedMetricRecords
        let blockScores = projection.blockScoreRecords
        let notable = projection.notableSessions

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Records")
                        .font(AppFont.displayMedium)
                    Text("Personal bests from completed workouts.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }

                if loadRecords.isEmpty && repRecords.isEmpty && velocity.isEmpty && specialized.isEmpty && blockScores.isEmpty && notable.isEmpty {
                    ContentUnavailableView(
                        "No records yet",
                        systemImage: AppIcon.trophy,
                        description: Text("Complete weighted or rep-based sets to establish personal bests.")
                    )
                } else {
                    if !loadRecords.isEmpty {
                        recordsSection("Best load", icon: AppIcon.workout, records: loadRecords)
                    }
                    if !repRecords.isEmpty {
                        recordsSection("Best reps", icon: AppIcon.number, records: repRecords)
                    }
                    if !velocity.isEmpty {
                        recordsSection("Velocity records", icon: AppIcon.progression, records: velocity)
                    }
                    if !specialized.isEmpty {
                        recordsSection("Power & implement records", icon: AppIcon.trophy, records: specialized)
                    }
                    if !blockScores.isEmpty {
                        recordsSection("Format records", icon: AppIcon.relationship, records: blockScores)
                    }
                    if !notable.isEmpty {
                        notableSection(notable)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
    }

    private func recordsSection(_ title: String, icon: String, records: [HistoryRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label(title, systemImage: icon)
                .font(AppFont.titleSmallSemibold)
            ForEach(records) { record in
                recordRow(record)
            }
        }
    }

    private func notableSection(_ sessions: [HistorySessionRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("Notable sessions", systemImage: AppIcon.favoriteFilled)
                .font(AppFont.titleSmallSemibold)
            ForEach(sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(session.title)
                            .font(AppFont.bodyMedium)
                        Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    Spacer()
                    Text("\(Formatters.formatFloat(session.volume)) \(session.unit) volume")
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymPrimary)
                }
                .padding(Spacing.m)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
    }

    private func recordRow(_ record: HistoryRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(record.exercise)
                    .font(AppFont.bodyMedium)
                Text(record.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer()
            Text(record.valueText)
                .font(AppFont.headlineMonospaced)
                .foregroundStyle(Color.gymPrimary)
        }
        .padding(Spacing.m)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .combine)
    }

}

struct HistoryRecord: Identifiable {
    let exercise: String
    let value: Float
    let unit: String
    let date: Date
    let kind: String
    var displayValueText: String? = nil

    var id: String { "\(kind)-\(exercise)-\(date.timeIntervalSinceReferenceDate)" }
    var valueText: String { displayValueText ?? "\(Formatters.formatFloat(value)) \(unit)" }
}

struct HistorySessionRecord: Identifiable {
    let title: String
    let volume: Float
    let unit: String
    let date: Date
    var id: String { "\(title)-\(date.timeIntervalSinceReferenceDate)" }
}

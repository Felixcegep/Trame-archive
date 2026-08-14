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
                GymSectionHeader(title: "Personal bests")

                if loadRecords.isEmpty && repRecords.isEmpty && velocity.isEmpty && specialized.isEmpty && blockScores.isEmpty && notable.isEmpty {
                    ContentUnavailableView(
                        "No records yet",
                        systemImage: AppIcon.trophy,
                        description: Text("Complete weighted or rep-based sets to establish personal bests.")
                    )
                } else {
                    recordsBoard(
                        loadRecords: loadRecords,
                        repRecords: repRecords,
                        velocity: velocity,
                        specialized: specialized,
                        blockScores: blockScores
                    )
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

    @ViewBuilder
    private func recordsBoard(
        loadRecords: [HistoryRecord],
        repRecords: [HistoryRecord],
        velocity: [HistoryRecord],
        specialized: [HistoryRecord],
        blockScores: [HistoryRecord]
    ) -> some View {
        GymCard(variant: .completed) {
            GymEyebrow("Measured bests", tint: .gymSecondary)
            if !loadRecords.isEmpty {
                recordGroup("Load", records: loadRecords)
            }
            if !repRecords.isEmpty {
                recordGroup("Reps", records: repRecords)
            }
            if !velocity.isEmpty {
                recordGroup("Velocity", records: velocity)
            }
            if !specialized.isEmpty {
                recordGroup("Power", records: specialized)
            }
            if !blockScores.isEmpty {
                recordGroup("Format", records: blockScores)
            }
        }
    }

    private func recordGroup(_ title: String, records: [HistoryRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
                Spacer()
                Text("\(records.count)")
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymSubduedText)
            }
            ForEach(records) { record in
                recordRow(record)
            }
        }
    }

    private func notableSection(_ sessions: [HistorySessionRecord]) -> some View {
        GymCard {
            GymEyebrow("Notable sessions", tint: .gymSecondary)

            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                if index > 0 { Divider() }
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
                        .foregroundStyle(Color.gymText)
                }
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .accessibilityElement(children: .combine)
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
        .frame(minHeight: ComponentSize.minimumTouchTarget)
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

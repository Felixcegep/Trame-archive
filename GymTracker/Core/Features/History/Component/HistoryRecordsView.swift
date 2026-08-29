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
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                TrameSectionRule(title: "Personal bests")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("history-records-heading")

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
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.trameCanvas)
    }

    @ViewBuilder
    private func recordsBoard(
        loadRecords: [HistoryRecord],
        repRecords: [HistoryRecord],
        velocity: [HistoryRecord],
        specialized: [HistoryRecord],
        blockScores: [HistoryRecord]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if !loadRecords.isEmpty {
                recordGroup("Measured bests", records: loadRecords)
            }
            if !repRecords.isEmpty {
                recordGroup("Rep bests", records: repRecords)
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
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(title.uppercased())
                    .font(AppFont.eyebrow)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameSubdued)
                Spacer()
                Text("\(records.count)")
                    .font(AppFont.metadata)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameSubdued)
            }
            ForEach(records) { record in
                recordRow(record)
            }
        }
    }

    private func notableSection(_ sessions: [HistorySessionRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("NOTABLE SESSIONS")
                .font(AppFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)

            ForEach(sessions) { session in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(session.title)
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(Color.trameText)
                        Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                    }
                    Spacer()
                    Text("\(Formatters.formatFloat(session.volume)) \(session.unit) volume")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                }
                .padding(.vertical, Spacing.s)
                .overlay(alignment: .bottom) {
                    Divider().overlay(Color.trameSeparator)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func recordRow(_ record: HistoryRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(record.exercise)
                    .font(AppFont.body.weight(.semibold))
                    .foregroundStyle(Color.trameText)

                Text(record.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }

            Spacer(minLength: Spacing.m)

            Text(record.valueText)
                .font(AppFont.metricCompact)
                .foregroundStyle(Color.trameText)
        }
        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.trameSeparator)
        }
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

import SwiftData
import SwiftUI

struct HistoryRecordsView: View {
    let workouts: [Workout]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Records")
                        .font(AppFont.displayMedium)
                    Text("Personal bests from completed workouts.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }

                if bestLoadRecords.isEmpty && bestRepRecords.isEmpty && notableSessions.isEmpty {
                    ContentUnavailableView(
                        "No records yet",
                        systemImage: AppIcon.trophy,
                        description: Text("Complete weighted or rep-based sets to establish personal bests.")
                    )
                } else {
                    if !bestLoadRecords.isEmpty {
                        recordsSection("Best load", icon: AppIcon.workout, records: bestLoadRecords)
                    }
                    if !bestRepRecords.isEmpty {
                        recordsSection("Best reps", icon: AppIcon.number, records: bestRepRecords)
                    }
                    if !notableSessions.isEmpty {
                        notableSection
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

    private var notableSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("Notable sessions", systemImage: AppIcon.favoriteFilled)
                .font(AppFont.titleSmallSemibold)
            ForEach(notableSessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(session.title)
                            .font(AppFont.bodyMedium)
                        Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }
                    Spacer()
                    Text("\(Formatters.formatFloat(session.volume)) volume")
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
                    .foregroundStyle(WorkoutPalette.subduedText)
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

    private var bestLoadRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises where exercise.exercise.trackingType.usesWeight {
                for set in exercise.orderedSets where set.done && set.weight > 0 {
                    let candidate = HistoryRecord(exercise: exercise.exercise.name, value: set.weight, unit: set.weightType.rawValue, date: workout.startTime, kind: "load")
                    if candidate.value > (best[exercise.exercise.name]?.value ?? 0) { best[exercise.exercise.name] = candidate }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var bestRepRecords: [HistoryRecord] {
        var best: [String: HistoryRecord] = [:]
        for workout in workouts {
            for exercise in workout.orderedExercises where exercise.exercise.trackingType.usesReps {
                for set in exercise.orderedSets where set.done && set.repetitions > 0 {
                    let candidate = HistoryRecord(exercise: exercise.exercise.name, value: set.repetitions, unit: "reps", date: workout.startTime, kind: "reps")
                    if candidate.value > (best[exercise.exercise.name]?.value ?? 0) { best[exercise.exercise.name] = candidate }
                }
            }
        }
        return best.values.sorted { $0.value > $1.value }
    }

    private var notableSessions: [HistorySessionRecord] {
        workouts.map { workout in
            let volume = workout.orderedExercises.reduce(Float.zero) { total, exercise in
                total + exercise.orderedSets.filter(\.done).reduce(Float.zero) { subtotal, set in
                    subtotal + (exercise.exercise.trackingType.usesWeight && exercise.exercise.trackingType.usesReps ? set.weight * set.repetitions : 0)
                }
            }
            return HistorySessionRecord(title: workout.displayTitle, volume: volume, date: workout.startTime)
        }
        .filter { $0.volume > 0 }
        .sorted { $0.volume > $1.volume }
        .prefix(3)
        .map { $0 }
    }
}

struct HistoryRecord: Identifiable {
    let exercise: String
    let value: Float
    let unit: String
    let date: Date
    let kind: String

    var id: String { "\(kind)-\(exercise)-\(date.timeIntervalSinceReferenceDate)" }
    var valueText: String { "\(Formatters.formatFloat(value)) \(unit)" }
}

struct HistorySessionRecord: Identifiable {
    let title: String
    let volume: Float
    let date: Date
    var id: String { "\(title)-\(date.timeIntervalSinceReferenceDate)" }
}

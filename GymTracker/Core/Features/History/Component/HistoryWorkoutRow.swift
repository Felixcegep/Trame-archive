import SwiftData
import SwiftUI

struct HistoryWorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Text(workoutTitle)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                Text(workoutDate)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
            }

            HStack(spacing: Spacing.m) {
                metadataItem(workoutDuration, icon: AppIcon.timer)
                metadataItem(exerciseSummary, icon: AppIcon.workout)
                metadataItem(setSummary, icon: AppIcon.checkmarkCircle)
            }

            if let sourceName {
                Label("From \(sourceName)", systemImage: AppIcon.folders)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func metadataItem(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
            .lineLimit(1)
    }

    private var workoutTitle: String {
        workout.displayTitle
    }

    private var workoutDate: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(workout.startTime) {
            return "Today, \(workout.startTime.formatted(date: .omitted, time: .shortened))"
        }
        return workout.startTime.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var workoutDuration: String {
        guard let endTime = workout.endTime else { return "0 min" }
        let minutes = max(1, Int(endTime.timeIntervalSince(workout.startTime)) / 60)
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes) min"
    }

    private var exerciseSummary: String {
        let count = workout.orderedExercises.count
        return "\(count) \(count == 1 ? "exercise" : "exercises")"
    }

    private var setSummary: String {
        let count = workout.completedSetCount
        return "\(count) \(count == 1 ? "set" : "sets")"
    }

    private var sourceName: String? {
        if let templateName = workout.sourceTemplate?.name, !templateName.isEmpty {
            return templateName
        }
        if let planName = workout.sourcePlanName, !planName.isEmpty {
            return planName
        }
        return nil
    }

    private var accessibilitySummary: String {
        var values = [workoutTitle, workoutDate, workoutDuration, exerciseSummary, setSummary]
        if let sourceName { values.append("From \(sourceName)") }
        return values.joined(separator: ", ")
    }
}

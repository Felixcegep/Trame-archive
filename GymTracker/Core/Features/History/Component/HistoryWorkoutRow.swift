import SwiftData
import SwiftUI

struct HistoryWorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Text(workoutTitle)
                    .font(AppFont.body.weight(.semibold))
                    .foregroundStyle(Color.trameText)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                Text(workoutDate)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .lineLimit(1)
            }

            HStack(spacing: Spacing.xs) {
                Text([workoutDuration, exerciseSummary, setSummary].joined(separator: " · "))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .lineLimit(1)
            }

            if let sourceName {
                Text("From \(sourceName)")
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameStrength)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
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

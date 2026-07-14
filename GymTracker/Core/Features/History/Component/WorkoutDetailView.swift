//
//  WorkoutDetailView.swift
//  GymTracker
//

import SwiftUI
import SwiftData

struct HistoryWorkoutView: View {
    let workout: Workout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                workoutHeader

                if let notes = workout.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    notesSection(notes)
                }

                if let sourceName {
                    sourceBadge(sourceName)
                }

                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text("Exercises")
                        .font(AppFont.titleSmallSemibold)
                        .foregroundStyle(Color.gymText)

                    ForEach(workout.orderedExercises) { exercise in
                        WorkoutDetailView(exercise: exercise)
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xl)
        }
        .background(Color.gymBackground)
        .navigationTitle(workout.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(workout.displayTitle)
                .font(AppFont.displayMedium)
                .foregroundStyle(Color.gymText)

            Text(workout.startTime, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(AppFont.subheadline)
                .foregroundStyle(WorkoutPalette.subduedText)

            HStack(spacing: Spacing.m) {
                summaryItem(workoutDuration, icon: AppIcon.timer)
                summaryItem(exerciseSummary, icon: AppIcon.workout)
                summaryItem(setSummary, icon: AppIcon.checkmarkCircle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.displayTitle), \(workoutDuration), \(exerciseSummary), \(setSummary)")
    }

    private func summaryItem(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppFont.caption)
            .foregroundStyle(WorkoutPalette.subduedText)
            .lineLimit(1)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label("Notes", systemImage: "note.text")
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            Text(notes)
                .font(AppFont.body)
                .foregroundStyle(WorkoutPalette.subduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private func sourceBadge(_ sourceName: String) -> some View {
        Label("From \(sourceName)", systemImage: AppIcon.folders)
            .font(AppFont.footnoteMedium)
            .foregroundStyle(Color.gymAccent)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Color.gymAccentSurface, in: Capsule())
            .accessibilityLabel("Source template: \(sourceName)")
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
}

struct WorkoutDetailView: View {
    let exercise: ExerciceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(exercise.exercice.name)
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.gymText)

            if let note = exercise.Comment?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note)
                    .font(AppFont.footnote)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            let comparison = WorkoutPerformanceComparison(exercise: exercise)
            if comparison.hasTargets {
                PerformanceComparisonView(comparison: comparison)
            }

            setTable
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var setTable: some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.s) {
            GridRow {
                ForEach(tableColumns, id: \.self) { column in
                    Text(column)
                        .font(AppFont.captionBold)
                        .foregroundStyle(WorkoutPalette.subduedText)
                        .frame(maxWidth: .infinity, alignment: column == "Set" ? .leading : .trailing)
                }
            }

            Divider().gridCellColumns(tableColumns.count)

            ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                GridRow {
                    tableValue(setLabel(for: set, index: index), alignment: .leading)
                    if exercise.exercice.trackingType.usesWeight {
                        tableValue(weightText(for: set))
                    }
                    if exercise.exercice.trackingType.usesReps {
                        tableValue("\(Formatters.formatFloat(set.repetition))")
                    }
                    if exercise.exercice.trackingType.usesDuration {
                        tableValue(durationText(for: set))
                    }
                    if exercise.exercice.trackingType.usesDistance {
                        tableValue(distanceText(for: set))
                    }
                    if showsRPE {
                        tableValue(set.rpe.map { "\($0)" } ?? "—")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityDescription(for: set, index: index))
            }
        }
    }

    private var showsRPE: Bool {
        exercise.orderedSets.contains { $0.rpe != nil }
    }

    private var tableColumns: [String] {
        var columns = ["Set"]
        if exercise.exercice.trackingType.usesWeight { columns.append("Weight") }
        if exercise.exercice.trackingType.usesReps { columns.append("Reps") }
        if exercise.exercice.trackingType.usesDuration { columns.append("Time") }
        if exercise.exercice.trackingType.usesDistance { columns.append("Distance") }
        if showsRPE { columns.append("RPE") }
        return columns
    }

    private func tableValue(_ value: String, alignment: Alignment = .trailing) -> some View {
        Text(value)
            .font(AppFont.subheadlineMediumMonospaced)
            .foregroundStyle(Color.gymText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func setLabel(for set: ExerciseSet, index: Int) -> String {
        guard set.setType != .normal else { return "\(index + 1)" }
        return "\(index + 1) · \(set.setType.title)"
    }

    private func weightText(for set: ExerciseSet) -> String {
        "\(Formatters.formatFloat(set.weight)) \(set.weightType.rawValue)"
    }

    private func durationText(for set: ExerciseSet) -> String {
        let seconds = Int(set.duration ?? 0)
        return seconds >= 60 ? "\(seconds / 60):\(String(format: "%02d", seconds % 60))" : "\(seconds)s"
    }

    private func distanceText(for set: ExerciseSet) -> String {
        guard let distance = set.distance else { return "—" }
        return "\(Formatters.formatFloat(distance)) \(set.distanceType.rawValue)"
    }

    private func accessibilityDescription(for set: ExerciseSet, index: Int) -> String {
        var values = ["Set \(setLabel(for: set, index: index))"]
        if exercise.exercice.trackingType.usesWeight { values.append("\(weightText(for: set))") }
        if exercise.exercice.trackingType.usesReps { values.append("\(Formatters.formatFloat(set.repetition)) reps") }
        if exercise.exercice.trackingType.usesDuration { values.append(durationText(for: set)) }
        if exercise.exercice.trackingType.usesDistance { values.append(distanceText(for: set)) }
        if let rpe = set.rpe { values.append("RPE \(rpe)") }
        return values.joined(separator: ", ")
    }
}

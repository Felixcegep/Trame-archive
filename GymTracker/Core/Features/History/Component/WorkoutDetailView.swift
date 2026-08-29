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

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    TrameSectionRule(title: "Exercises")

                    ForEach(workout.orderedExercises) { exercise in
                        WorkoutDetailView(exercise: exercise)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.l)
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Color.trameCanvas)
        .navigationTitle(workout.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(workout.displayTitle)
                .font(AppFont.screenTitle)
                .foregroundStyle(Color.trameText)

            Text(workout.startTime, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)

            Text([workoutDuration, exerciseSummary, setSummary].joined(separator: " · "))
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.displayTitle), \(workoutDuration), \(exerciseSummary), \(setSummary)")
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("NOTES")
                .font(AppFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)
            Text(notes)
                .font(AppFont.body)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.trameSeparator)
        }
    }

    private func sourceBadge(_ sourceName: String) -> some View {
        Text("From \(sourceName)")
            .font(AppFont.micro)
            .foregroundStyle(Color.trameStrength)
            .accessibilityLabel("Source workout: \(sourceName)")
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
    let exercise: ExerciseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if exercise.supersetGroupID != nil {
                Text("SUPERSET")
                    .font(AppFont.micro)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameStrength)
                    .accessibilityLabel("Superset exercise")
            }
            Text(exercise.occurrenceDisplayName)
                .font(AppFont.stageTitle)
                .foregroundStyle(Color.trameText)

            if let original = exercise.originalExerciseNameSnapshot,
               exercise.selectedSubstituteExerciseIDSnapshot != nil {
                Text("Substituted for \(original)")
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityLabel("Substituted for \(original)")
            }

            if let note = exercise.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }

            let comparison = WorkoutPerformanceComparison(exercise: exercise)
            if comparison.hasTargets {
                PerformanceComparisonView(comparison: comparison)
            }

            setTable
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.m)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.trameSeparator)
        }
    }

    private var setTable: some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.s) {
            GridRow {
                ForEach(tableColumns, id: \.self) { column in
                    Text(column.uppercased())
                        .font(AppFont.eyebrow)
                        .tracking(0.8)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(maxWidth: .infinity, alignment: column == "Set" ? .leading : .trailing)
                }
            }

            Divider().overlay(Color.trameSeparator).gridCellColumns(tableColumns.count)

            ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                GridRow {
                    tableValue(setLabel(for: set, index: index), alignment: .leading)
                    if exercise.trackingTypeSnapshot.usesWeight {
                        tableValue(weightText(for: set))
                    }
                    if exercise.trackingTypeSnapshot.usesReps {
                        tableValue("\(Formatters.formatFloat(set.repetitions))")
                    }
                    if exercise.trackingTypeSnapshot.usesDuration {
                        tableValue(durationText(for: set))
                    }
                    if exercise.trackingTypeSnapshot.usesDistance {
                        tableValue(distanceText(for: set))
                    }
                    if exercise.trackingTypeSnapshot.usesCalories {
                        tableValue(caloriesText(for: set))
                    }
                    if showsRPE {
                        tableValue(set.rpe.map { Formatters.formatFloat(Float($0)) } ?? "—")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityDescription(for: set, index: index))

                if !set.orderedComplexComponents.isEmpty {
                    GridRow {
                        Text(complexComponentText(for: set))
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .fixedSize(horizontal: false, vertical: true)
                            .gridCellColumns(tableColumns.count)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Complex components: \(complexComponentText(for: set))")
                }
            }
        }
    }

    private var showsRPE: Bool {
        exercise.orderedSets.contains { $0.rpe != nil }
    }

    private var tableColumns: [String] {
        var columns = ["Set"]
        if exercise.trackingTypeSnapshot.usesWeight { columns.append("Weight") }
        if exercise.trackingTypeSnapshot.usesReps { columns.append("Reps") }
        if exercise.trackingTypeSnapshot.usesDuration { columns.append("Time") }
        if exercise.trackingTypeSnapshot.usesDistance { columns.append("Distance") }
        if exercise.trackingTypeSnapshot.usesCalories { columns.append("Calories") }
        if showsRPE { columns.append("RPE") }
        return columns
    }

    private func tableValue(_ value: String, alignment: Alignment = .trailing) -> some View {
        Text(value)
            .font(AppFont.bodyMedium)
            .monospacedDigit()
            .foregroundStyle(Color.trameText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func setLabel(for set: ExerciseSet, index: Int) -> String {
        guard set.setType != .normal else { return "\(index + 1)" }
        return "\(index + 1) · \(set.setType.title)"
    }

    private func complexComponentText(for set: ExerciseSet) -> String {
        let components = set.orderedComplexComponents
            .map { "\($0.exerciseNameSnapshot) ×\($0.performedRepetitions)/\($0.prescribedRepetitions): \($0.outcome.title)" }
            .joined(separator: " · ")
        guard let outcome = set.olympicAttemptOutcome else { return components }
        return "Attempt: \(outcome.title) · \(components)"
    }

    private func weightText(for set: ExerciseSet) -> String {
        "\(Formatters.formatFloat(set.weight)) \(set.weightType.rawValue)"
    }

    private func durationText(for set: ExerciseSet) -> String {
        let seconds = Int(set.duration ?? 0)
        return seconds >= 60 ? "\(seconds / 60):\(String(format: "%02d", seconds % 60))" : "\(seconds)s"
    }

    private func distanceText(for set: ExerciseSet) -> String {
        guard let measurement = WorkoutDistancePolicy.displayMeasurement(
            for: set,
            system: UserDefaults.standard.unitSystem
        ) else { return "—" }
        return "\(Formatters.formatFloat(measurement.value)) \(measurement.unit.symbol)"
    }

    private func caloriesText(for set: ExerciseSet) -> String {
        guard let calories = set.calories else { return "—" }
        return "\(Formatters.formatFloat(Float(calories))) cal"
    }

    private func accessibilityDescription(for set: ExerciseSet, index: Int) -> String {
        var values = ["Set \(setLabel(for: set, index: index))"]
        if exercise.trackingTypeSnapshot.usesWeight { values.append("\(weightText(for: set))") }
        if exercise.trackingTypeSnapshot.usesReps { values.append("\(Formatters.formatFloat(set.repetitions)) reps") }
        if exercise.trackingTypeSnapshot.usesDuration { values.append(durationText(for: set)) }
        if exercise.trackingTypeSnapshot.usesDistance { values.append(distanceText(for: set)) }
        if exercise.trackingTypeSnapshot.usesCalories { values.append(caloriesText(for: set)) }
        if let rpe = set.rpe { values.append("RPE \(Formatters.formatFloat(Float(rpe)))") }
        if let tempo = set.prescribedTempo,
           !tempo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append("prescribed tempo \(tempo)")
        }
        return values.joined(separator: ", ")
    }
}

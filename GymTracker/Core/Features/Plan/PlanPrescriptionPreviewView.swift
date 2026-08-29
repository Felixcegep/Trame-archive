import SwiftUI

/// A read-only, set-level preview of the prescriptions that will be generated
/// from a saved plan. It deliberately reads the plan model rather than the
/// active run, so editing or starting a run cannot reinterpret completed work.
struct PlanPrescriptionPreviewView: View {
    let plan: WorkoutPlan

    var body: some View {
        List {
            Section {
                Label {
                    Text("This preview shows the prescriptions currently stored in the plan. A workout snapshot freezes these values when you start a session.")
                        .font(AppFont.body)
                } icon: {
                    Image(systemName: AppIcon.info)
                        .foregroundStyle(Color.trameActionDeep)
                }
                .accessibilityIdentifier("program-preview-summary")
            }

            Section {
                LabeledContent("Schedule", value: scheduleSummary)
                LabeledContent("Weeks", value: "\(plan.durationWeeks)")
                LabeledContent("Workouts", value: "\(workoutCount)")
                LabeledContent("Exercises", value: "\(exerciseCount)")
            } header: {
                TrameDomainSectionRule(title: "Schedule", color: Color.trameStrength)
            }

            ForEach(plan.orderedWeeks) { week in
                Section {
                    DisclosureGroup {
                        ForEach(week.orderedPlannedWorkouts) { workout in
                            PlanPrescriptionPreviewWorkout(workout: workout)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(weekTitle(for: week))
                                    .font(AppFont.subheadlineSemibold)
                                Text(phaseTitle(for: week))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.trameSubdued)
                            }
                            Spacer()
                            Text("\(week.orderedPlannedWorkouts.count) sessions")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.trameSubdued)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Prescription Preview")
    }

    private var scheduleSummary: String {
        switch plan.scheduleMode {
        case .fixedWeekdays:
            return "Fixed weekdays · \(plan.daysPerWeek)/week"
        case .sequential:
            return "Sequential sessions"
        case .everyNDays:
            return "Every \(plan.scheduleIntervalDays) days"
        }
    }

    private var workoutCount: Int {
        plan.orderedWeeks.reduce(0) { $0 + $1.orderedPlannedWorkouts.count }
    }

    private var exerciseCount: Int {
        plan.orderedWeeks.reduce(0) { total, week in
            total + week.orderedPlannedWorkouts.reduce(0) { $0 + $1.orderedPlannedExercises.count }
        }
    }

    private func weekTitle(for week: PlanWeek) -> String {
        if let name = week.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "Week \(week.weekIndex + 1) · \(name)"
        }
        return "Week \(week.weekIndex + 1)"
    }

    private func phaseTitle(for week: PlanWeek) -> String {
        guard let block = plan.orderedBlocks.first(where: { $0.orderedWeeks.contains { $0.id == week.id } }) else {
            return "Training phase"
        }
        if block.isDeload {
            return "\(block.name) · Deload · −\(block.effectiveDeloadVolumeReductionPercent)% sets · −\(block.effectiveDeloadIntensityReductionPercent)% load"
        }
        return "\(block.name) · \(block.phaseType.title)"
    }
}

private struct PlanPrescriptionPreviewWorkout: View {
    let workout: PlannedWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(workout.name)
                    .font(AppFont.sectionTitle)
                Spacer()
                Text("Day \(workout.dayOffset + 1)")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }

            ForEach(workout.orderedPlannedExercises) { exercise in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(exercise.exercise.name)
                                .font(AppFont.bodyMedium)
                        if exercise.supersetGroupID != nil {
                            Label("Superset", systemImage: AppIcon.relationship)
                                .font(AppFont.micro)
                                .foregroundStyle(Color.trameActionDeep)
                        }
                        Spacer()
                        if exercise.isOptional {
                            Text("Optional")
                                .font(AppFont.micro)
                                .foregroundStyle(Color.trameSubdued)
                        }
                    }

                    if exercise.orderedPlannedSets.isEmpty {
                        Text(fallbackSummary(for: exercise))
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                    } else {
                        ForEach(exercise.orderedPlannedSets, id: \.orderIndex) { plannedSet in
                            Label(setSummary(for: plannedSet), systemImage: plannedSet.setType.icon)
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.trameSubdued)
                                .accessibilityIdentifier("program-preview-set-\(workout.id)-\(exercise.id)-\(plannedSet.orderIndex)")
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func fallbackSummary(for exercise: PlannedExercise) -> String {
        var value = "\(exercise.targetSets) × \(exercise.repRangeMinimum)–\(exercise.repRangeMaximum) reps"
        if let load = exercise.suggestedLoad, let loadType = exercise.suggestedLoadType {
            value += " · \(load.formatted(.number.precision(.fractionLength(0...2)))) \(loadType.rawValue)"
        }
        value += " · \(exercise.restSeconds)s rest"
        if let rpe = exercise.targetRPE {
            value += " · RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))"
        }
        if let rir = exercise.targetRIR {
            value += " · RIR \(rir)"
        }
        return value
    }

    private func setSummary(for plannedSet: PlannedSet) -> String {
        let reps: String
        if let exact = plannedSet.repetitions {
            reps = "\(exact) reps"
        } else if let minimum = plannedSet.repRangeMinimum, let maximum = plannedSet.repRangeMaximum {
            reps = "\(minimum)–\(max(minimum, maximum)) reps"
        } else {
            reps = "open target"
        }

        var value = reps
        if let load = plannedSet.suggestedLoad, let loadType = plannedSet.suggestedLoadType {
            value += " · \(load.formatted(.number.precision(.fractionLength(0...2)))) \(loadType.rawValue)"
        }
        if let rest = plannedSet.restSeconds {
            value += " · \(rest)s rest"
        }
        if let rpe = plannedSet.targetRPE {
            value += " · RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))"
        }
        if let rir = plannedSet.targetRIR {
            value += " · RIR \(rir)"
        }
        if let tempo = plannedSet.tempo, !tempo.isEmpty {
            value += " · Tempo \(tempo)"
        }
        if !plannedSet.progressionEligible {
            value += " · no progression"
        }
        if plannedSet.isOptional {
            value += " · optional"
        }
        return value
    }
}

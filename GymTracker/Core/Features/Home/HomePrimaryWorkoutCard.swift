import SwiftUI

struct HomePrimaryWorkoutCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activeWorkout: Workout?
    let activePlanRun: PlanRun?
    let activePlanProgress: PlanWorkoutProgress?
    let summary: TodayWorkoutSummary
    let onOpen: () -> Void
    let onOpenSavedWorkouts: () -> Void
    let onPostpone: () -> Void
    let onReschedule: (PlanWorkoutProgress) -> Void
    let onSkip: (PlanWorkoutProgress) -> Void

    private var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                primaryContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .disabled(summary.kind == .unavailable)
            .accessibilityLabel(cardAccessibilityLabel)
            .accessibilityHint(cardHint)
            .accessibilityIdentifier(cardAccessibilityIdentifier)

            if showsSavedWorkoutsFooter {
                Divider()
                    .overlay(Color.trameSeparator)

                Button(action: onOpenSavedWorkouts) {
                    HStack(spacing: Spacing.m) {
                        Text("Saved workouts")
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.trameText)

                        Spacer(minLength: Spacing.s)

                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.micro)
                            .foregroundStyle(Color.trameSubdued)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityHint("Opens your saved workouts.")
                .accessibilityIdentifier("today-open-saved-workouts")
            }

            scheduleActions
        }
    }

    private var primaryContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            primaryHeading

            supportingData

            if let activeWorkout, activeWorkout.totalSetCount > 0 {
                ProgressView(
                    value: Double(activeWorkout.completedSetCount),
                    total: Double(activeWorkout.totalSetCount)
                )
                .tint(Color.trameStrength)
                .accessibilityHidden(true)
            }

            primaryActionLabel
        }
        .padding(.leading, showsSemanticRail ? Spacing.l : 0)
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .leading) {
            if showsSemanticRail {
                Rectangle()
                    .fill(semanticRailColor)
                    .frame(width: 6)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var primaryHeading: some View {
        if dynamicTypeSize.isAccessibilitySize || displayedExerciseCount == nil {
            VStack(alignment: .leading, spacing: Spacing.s) {
                titleStack
                exerciseCountView
            }
        } else {
            HStack(alignment: .bottom, spacing: Spacing.xl) {
                titleStack
                Spacer(minLength: Spacing.s)
                exerciseCountView
            }
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if showsEyebrow {
                Text(cardLabel)
                    .font(AppFont.eyebrow)
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.trameSubdued)
            }

            cardTitleText
                .font(AppFont.stageTitle)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var exerciseCountView: some View {
        if let displayedExerciseCount {
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(displayedExerciseCount, format: .number.precision(.integerLength(2)))
                    .font(AppFont.metricHero)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameText)

                Text(displayedExerciseCount == 1 ? "EXERCISE" : "EXERCISES")
                    .font(AppFont.micro)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameSubdued)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(displayedExerciseCount) exercises")
        }
    }

    @ViewBuilder
    private var supportingData: some View {
        if let activeWorkout, activeWorkout.totalSetCount > 0 {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Text("\(activeWorkout.completedSetCount) / \(activeWorkout.totalSetCount) SETS")
                    .font(AppFont.eyebrow)
                    .monospacedDigit()
                    .tracking(0.8)
                    .foregroundStyle(Color.trameText)

                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(width: 1, height: 18)
                    .accessibilityHidden(true)

                Text(nextExerciseDescription(in: activeWorkout))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .lineLimit(2)
            }
        } else if showsSubtitle {
            Text(cardSubtitle)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryActionLabel: some View {
        HStack(spacing: Spacing.m) {
            Text(primaryActionTitle)
                .font(AppFont.titleSmallSemibold)

            Spacer(minLength: Spacing.s)

            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.subheadlineSemibold)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.l)
        .frame(maxWidth: .infinity, minHeight: ComponentSize.todayActionHeight)
        .foregroundStyle(primaryActionInk)
        .background(
            primaryActionFill,
            in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        )
        .overlay {
            if summary.kind == .unavailable {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(Color.trameSeparator, lineWidth: 1)
            }
        }
    }

    private var showsEyebrow: Bool {
        summary.kind != .free
    }

    private var showsSubtitle: Bool {
        summary.kind != .free
    }

    private var showsSavedWorkoutsFooter: Bool {
        summary.kind == .free
    }

    private var showsSemanticRail: Bool {
        summary.kind != .free
    }

    private var semanticRailColor: Color {
        switch summary.kind {
        case .guidedConflict, .unavailable:
            return .trameAttention
        case .active, .planned, .repeating, .free:
            return .trameStrength
        }
    }

    private var displayedExerciseCount: Int? {
        guard let exerciseCount, exerciseCount > 0 else { return nil }
        return exerciseCount
    }

    private var exerciseCount: Int? {
        if let activeWorkout {
            return activeWorkout.orderedExercises.count
        }

        if let activePlanRun,
           let activePlanProgress,
           let plannedWorkout = PlanCoordinator.plannedWorkout(
                for: activePlanProgress,
                in: activePlanRun
           ) {
            return plannedWorkout.orderedPlannedExercises.count
        }

        return nil
    }

    private var primaryActionFill: Color {
        summary.kind == .unavailable ? Color.trameRow : Color.trameAction
    }

    private var primaryActionInk: Color {
        summary.kind == .unavailable ? Color.trameSubdued : Color.trameActionInk
    }

    @ViewBuilder
    private var scheduleActions: some View {
        if let activePlanRun, let activePlanProgress,
           !hasActiveWorkout,
           PlanCoordinator.canEditSchedule(activePlanProgress, in: activePlanRun) {
            Divider()
                .overlay(Color.trameSeparator)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        scheduleActionButton(
                            "Tomorrow",
                            systemImage: AppIcon.tomorrow,
                            identifier: "today-postpone-planned-workout",
                            action: onPostpone
                        )
                        Divider().overlay(Color.trameSeparator)
                        scheduleActionButton(
                            "Reschedule",
                            systemImage: AppIcon.reschedule,
                            identifier: "today-reschedule-planned-workout"
                        ) {
                            onReschedule(activePlanProgress)
                        }
                        Divider().overlay(Color.trameSeparator)
                        scheduleActionButton(
                            "Skip",
                            systemImage: AppIcon.skip,
                            identifier: "today-skip-planned-workout",
                            role: .destructive
                        ) {
                            onSkip(activePlanProgress)
                        }
                    }
                } else {
                    HStack(spacing: Spacing.s) {
                        scheduleActionButton(
                            "Tomorrow",
                            systemImage: AppIcon.tomorrow,
                            identifier: "today-postpone-planned-workout",
                            action: onPostpone
                        )

                        scheduleActionButton(
                            "Reschedule",
                            systemImage: AppIcon.reschedule,
                            identifier: "today-reschedule-planned-workout"
                        ) {
                            onReschedule(activePlanProgress)
                        }

                        Spacer(minLength: Spacing.m)

                        scheduleActionButton(
                            "Skip",
                            systemImage: AppIcon.skip,
                            identifier: "today-skip-planned-workout",
                            role: .destructive
                        ) {
                            onSkip(activePlanProgress)
                        }
                    }
                }
            }
            .font(AppFont.subheadlineSemibold)
            .padding(.vertical, Spacing.xs)
        }
    }

    private func scheduleActionButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        identifier: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(role == .destructive ? Color.trameDestructiveText : Color.trameText)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    private var cardTitleText: Text {
        if summary.kind == .free {
            return Text("Nothing planned")
        }
        guard summary.kind == .active else {
            return Text(LocalizedStringKey(summary.title))
        }
        guard let name = activeWorkout?.name, !name.isEmpty else {
            return Text("Workout")
        }
        return Text(verbatim: name)
    }

    private var cardSubtitle: LocalizedStringKey {
        if let activeWorkout {
            guard activeWorkout.totalSetCount > 0 else {
                return "No exercises yet · Pick your first exercise"
            }
            return "\(activeWorkout.completedSetCount) / \(activeWorkout.totalSetCount) sets · \(nextExerciseDescription(in: activeWorkout))"
        }
        return LocalizedStringKey(summary.subtitle)
    }

    private var cardLabel: LocalizedStringKey {
        switch summary.kind {
        case .active: return "Active"
        case .planned: return "Planned"
        case .repeating: return "Next"
        case .guidedConflict: return "Needs attention"
        case .unavailable: return "Unavailable"
        case .free: return "Start"
        }
    }

    private var cardAccessibilityLabel: String {
        var parts = [summary.title]
        if let activeWorkout, activeWorkout.totalSetCount > 0 {
            parts.append(String(
                localized: "\(activeWorkout.completedSetCount) of \(activeWorkout.totalSetCount) sets complete"
            ))
            parts.append(nextExerciseDescription(in: activeWorkout))
        } else if !summary.subtitle.isEmpty {
            parts.append(summary.subtitle)
        }
        return parts.joined(separator: ". ")
    }

    private var cardHint: String {
        switch summary.kind {
        case .active:
            return "Returns to your active workout."
        case .planned:
            return "Starts the next workout in your active plan."
        case .repeating:
            return String(localized: "Starts the next workout in your active rotation.")
        case .guidedConflict:
            return String(localized: "Choose which guided training source should remain active.")
        case .unavailable:
            return String(localized: "This workout cannot start until you repair it in the Train tab.")
        case .free:
            return "Starts an empty workout."
        }
    }

    private var cardAccessibilityIdentifier: String {
        switch summary.kind {
        case .active: return "resume-active-workout"
        case .planned: return "start-planned-workout"
        case .repeating: return "start-repeating-workout"
        case .guidedConflict: return "resolve-guided-source-conflict"
        case .unavailable: return "guided-workout-unavailable"
        case .free: return "start-free-workout"
        }
    }

    private var primaryActionTitle: LocalizedStringKey {
        switch summary.kind {
        case .active: return "Resume workout"
        case .planned, .repeating, .free: return "Start workout"
        case .guidedConflict: return "Choose"
        case .unavailable: return "Unavailable"
        }
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) }),
              let setIndex = exercise.orderedSets.firstIndex(where: { !$0.done })
        else {
            return String(localized: "Workout complete")
        }

        let format = String(localized: "Next · %@ · Set %lld")
        return String(format: format, exercise.exercise.name, Int64(setIndex + 1))
    }
}

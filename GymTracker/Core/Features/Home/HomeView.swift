import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let workoutVM: WorkoutViewModel
    @Binding var isShowingActiveWorkout: Bool
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void

    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query private var planRuns: [PlanRun]
    @State private var isShowingTemplatePicker = false
    @State private var templateToStart: WorkoutTemplate? = nil
    @State private var isShowingActiveWorkoutConflictAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                welcomeHeader
                primaryWorkoutCard
                quickActions
                recentActivity
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground)
        .tint(Color.gymPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.gymBackground, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
        .sheet(isPresented: $isShowingTemplatePicker) {
            NavigationStack {
                SavedWorkoutTemplatePicker(templates: workoutTemplates) { template in
                    isShowingTemplatePicker = false
                    DispatchQueue.main.async {
                        startWorkout(from: template)
                    }
                }
            }
        }
        .confirmationDialog(
            "An active workout is already in progress",
            isPresented: $isShowingActiveWorkoutConflictAlert,
            titleVisibility: .visible
        ) {
            Button("Resume Active Workout") {
                isShowingActiveWorkout = true
                templateToStart = nil
            }
            Button("Discard & Start New", role: .destructive) {
                workoutVM.discardActiveWorkout(using: modelContext)
                if let template = templateToStart {
                    workoutVM.startWorkout(with: template, using: modelContext)
                    isShowingActiveWorkout = true
                }
                templateToStart = nil
            }
            Button("Cancel", role: .cancel) {
                templateToStart = nil
            }
        } message: {
            Text("Do you want to continue your active workout, or discard it and start a new one?")
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppFont.subheadlineMediumMonospaced)
                .foregroundStyle(Color.gymAccent)

            if let activePlanRun {
                activePlanContext(for: activePlanRun)
                    .padding(.bottom, Spacing.xs)
            }

            Text(workoutVM.hasActiveWorkout ? "Your workout is ready." : "Ready when you are.")
                .font(AppFont.displayMedium)

            Text(workoutVM.hasActiveWorkout
                 ? "Your session is still running."
                 : "Track your training today.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private func activePlanContext(for run: PlanRun) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: AppIcon.plan)
                .font(AppFont.captionBold)

            Text(run.sourcePlanName)
                .font(AppFont.captionBold)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Spacing.s)

            Text("Week \(run.currentWeekIndex + 1)")
                .font(AppFont.caption2Bold)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .background(Color.gymCard.opacity(0.72), in: Capsule())
        }
        .foregroundStyle(Color.gymAccent)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active program: \(run.sourcePlanName), week \(run.currentWeekIndex + 1)")
        .accessibilityIdentifier("active-plan-badge")
    }

    private var primaryWorkoutCard: some View {
        Button(action: openPrimaryWorkout) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Label(
                        primaryCardLabel,
                        systemImage: primaryCardIcon
                    )
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(workoutVM.hasActiveWorkout ? .white : Color.gymPrimary)

                    Spacer()

                    if workoutVM.hasActiveWorkout {
                        Image(systemName: "chevron.right")
                            .font(AppFont.subheadlineBold)
                            .foregroundStyle(.white)
                    }
                }

                Text(primaryCardTitle)
                    .font(AppFont.titleMedium)
                    .foregroundStyle(workoutVM.hasActiveWorkout ? .white : Color.gymText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(primaryCardSubtitle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(workoutVM.hasActiveWorkout ? .white.opacity(0.86) : Color.gymSubduedText)

                if let workout = workoutVM.activeWorkout, workout.totalSetCount > 0 {
                    ProgressView(
                        value: Double(workout.completedSetCount),
                        total: Double(workout.totalSetCount)
                    )
                    .tint(.white.opacity(0.95))
                    .padding(.top, Spacing.xxs)
                }

                if !workoutVM.hasActiveWorkout {
                    HStack(spacing: Spacing.s) {
                        Text("Start workout")
                            .font(AppFont.subheadlineBold)
                        Image(systemName: "arrow.right")
                            .font(AppFont.captionBold)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.xl)
                    .background(Color.gymPrimary, in: Capsule())
                    .padding(.top, Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background {
                if workoutVM.hasActiveWorkout {
                    LinearGradient(
                        colors: [Color.gymPrimary, Color.gymPrimary.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.gymCard
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .shadow(color: Color.gymText.opacity(0.03), radius: 6, x: 0, y: 3)
            .overlay {
                if !workoutVM.hasActiveWorkout {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.gymPrimary.opacity(0.16), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.gymPress)
        .accessibilityHint(primaryCardHint)
        .accessibilityIdentifier(primaryCardAccessibilityIdentifier)
    }

    private var quickActions: some View {
        Group {
            if !workoutVM.hasActiveWorkout {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("QUICK ACTIONS")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymSubduedText)

                    Button {
                        isShowingTemplatePicker = true
                    } label: {
                        quickActionRow(
                            icon: "rectangle.stack",
                            iconColor: Color.gymPrimary,
                            title: "Use a Saved Workout",
                            detail: "Follow a reusable session"
                        )
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("start-from-template")
                }
            }
        }
    }

    private func quickActionRow(
        icon: String,
        iconColor: Color,
        title: String,
        detail: String,
        isInformational: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(AppFont.headline)
                .frame(width: 38, height: 38)
                .foregroundStyle(iconColor)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.subheadlineSemibold)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer()

            Image(systemName: isInformational ? "info.circle" : "chevron.right")
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)
        }
        .padding(Spacing.m)
        .background(Color.gymCard)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private var recentActivity: some View {
        let completedWorkouts = workouts.filter { $0.status == .completed }

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("HISTORY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            if completedWorkouts.isEmpty {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppFont.headline)
                        .frame(width: 38, height: 38)
                        .foregroundStyle(Color.gymAccent)
                        .background(Color.gymAccent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("No workouts yet")
                            .font(AppFont.subheadlineSemibold)
                        Text("Finish a workout to unlock performance and progression history.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gymCard)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .stroke(Color.gymBorder, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(completedWorkouts.prefix(3), id: \.self) { workout in
                        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                            HStack(spacing: Spacing.m) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(AppFont.headline)
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(Color.gymSecondary)
                                    .background(Color.gymSecondary.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.displayTitle)
                                        .font(AppFont.subheadlineSemibold)
                                    Text(workout.startTime, style: .date)
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.gymSubduedText)
                                }

                                Spacer()

                                Text("^[\(workout.exercises.count) exercise](inflect: true)")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)

                                Image(systemName: "chevron.right")
                                    .font(AppFont.captionBold)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            .padding(Spacing.m)
                            .background(Color.gymCard)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                                    .stroke(Color.gymBorder, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                            .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.gymPress)
                    }
                }
            }
        }
    }

    private var primaryCardTitle: LocalizedStringKey {
        if let workout = workoutVM.activeWorkout {
            if let name = workout.name, !name.isEmpty {
                return "Resume \(name)"
            }
            return "Resume workout"
        }
        if let progress = activePlanProgress {
            return LocalizedStringKey(progress.plannedWorkoutName)
        }
        return "Free Workout"
    }

    private var primaryCardSubtitle: LocalizedStringKey {
        if let workout = workoutVM.activeWorkout {
            guard workout.totalSetCount > 0 else {
                return "No exercises yet · Pick your first exercise"
            }
            let completedSets = workout.completedSetCount
            let totalSets = workout.totalSetCount
            let nextDesc = nextExerciseDescription(in: workout)
            return "\(completedSets) / \(totalSets) sets · \(nextDesc)"
        }
        if let progress = activePlanProgress {
            let week = progress.weekIndex + 1
            if let scheduledDate = progress.scheduledDate, Calendar.current.isDateInToday(scheduledDate) {
                return "Week \(week) · Today"
            }
            return "Week \(week) · Start early when you are ready"
        }
        return "Jump in and add exercises as you go."
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) }),
              let setIndex = exercise.orderedSets.firstIndex(where: { !$0.done })
        else {
            return String(localized: "Workout complete")
        }

        let format = String(localized: "Next: %@ · Set %lld")
        return String(format: format, exercise.exercise.name, Int64(setIndex + 1))
    }

    private func openPrimaryWorkout() {
        if workoutVM.hasActiveWorkout {
            isShowingActiveWorkout = true
        } else if let run = activePlanRun, let progress = activePlanProgress {
            onStartPlannedWorkout(run, progress)
        } else {
            workoutVM.startWorkout(using: modelContext)
            isShowingActiveWorkout = true
        }
    }

    private func startWorkout(from template: WorkoutTemplate) {
        if workoutVM.hasActiveWorkout {
            templateToStart = template
            isShowingActiveWorkoutConflictAlert = true
        } else {
            workoutVM.startWorkout(with: template, using: modelContext)
            isShowingActiveWorkout = true
        }
    }

    private var activePlanRun: PlanRun? {
        planRuns
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private var activePlanProgress: PlanWorkoutProgress? {
        guard let activePlanRun else { return nil }
        return PlanCoordinator.nextProgress(in: activePlanRun)
    }

    private var primaryCardLabel: LocalizedStringKey {
        if workoutVM.hasActiveWorkout { return "ACTIVE WORKOUT" }
        if activePlanProgress != nil { return "PLANNED WORKOUT" }
        return "FREE WORKOUT"
    }

    private var primaryCardIcon: String {
        workoutVM.hasActiveWorkout || activePlanProgress != nil
            ? "figure.strengthtraining.traditional"
            : "bolt.fill"
    }

    private var primaryCardHint: String {
        if workoutVM.hasActiveWorkout { return "Returns to your active workout." }
        if activePlanProgress != nil { return "Starts the next workout in your active program." }
        return "Starts a blank workout."
    }

    private var primaryCardAccessibilityIdentifier: String {
        if workoutVM.hasActiveWorkout { return "resume-active-workout" }
        if activePlanProgress != nil { return "start-planned-workout" }
        return "start-free-workout"
    }
}

private struct SavedWorkoutTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No saved workouts",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Create a saved workout in Library, then start it from here.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(templates, id: \.self) { template in
                    Button {
                        dismiss()
                        onStartWorkout(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(template.name)
                                    .font(AppFont.subheadlineBold)
                                    .foregroundStyle(Color.gymText)
                                Text("\(template.exercises.count) exercises")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(AppFont.titleSmall)
                                .foregroundStyle(Color.gymPrimary)
                        }
                    }
                    .disabled(template.exercises.isEmpty)
                    .accessibilityIdentifier("workout-template-\(template.name)")
                    .accessibilityHint(template.exercises.isEmpty ? "Add an exercise before starting this workout." : "Starts a new session from this saved workout.")
                    .listRowBackground(Color.gymCard)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Start a saved workout")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

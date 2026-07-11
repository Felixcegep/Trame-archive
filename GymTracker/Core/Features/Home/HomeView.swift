import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    @Binding var isShowingActiveWorkout: Bool

    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @State private var isShowingTemplatePicker = false
    @State private var isShowingSettings = false

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
        .foregroundStyle(WorkoutPalette.text)
        .background(WorkoutPalette.background)
        .tint(WorkoutPalette.primary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WorkoutPalette.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(WorkoutPalette.primary)
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("settings-button")
            }
        }
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
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                isShowingSettings = false
                            }
                        }
                    }
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppFont.subheadlineMediumMonospaced)
                .foregroundStyle(WorkoutPalette.subduedText)

            Text(workoutVM.hasActiveWorkout ? "Your workout is ready." : "Ready when you are.")
                .font(AppFont.displayMedium)

            Text(workoutVM.hasActiveWorkout
                 ? "Continue where you left off."
                 : "Track your training today.")
                .font(AppFont.subheadline)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
    }

    private var primaryWorkoutCard: some View {
        Button(action: openPrimaryWorkout) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Label(
                        workoutVM.hasActiveWorkout ? "ACTIVE WORKOUT" : "START WORKOUT",
                        systemImage: workoutVM.hasActiveWorkout ? "figure.strengthtraining.traditional" : "bolt.fill"
                    )
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(workoutVM.hasActiveWorkout ? .white : Color.gymPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(workoutVM.hasActiveWorkout ? .white : Color.gymPrimary)
                }

                Text(primaryCardTitle)
                    .font(AppFont.titleMedium)
                    .foregroundStyle(workoutVM.hasActiveWorkout ? .white : WorkoutPalette.text)

                Text(primaryCardSubtitle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(workoutVM.hasActiveWorkout ? .white.opacity(0.86) : WorkoutPalette.subduedText)

                if let workout = workoutVM.activeWorkout {
                    ProgressView(
                        value: Double(workout.completedSetCount),
                        total: Double(max(workout.totalSetCount, 1))
                    )
                    .tint(.white.opacity(0.95))
                    .padding(.top, Spacing.xxs)
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
                    WorkoutPalette.surface
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
        .buttonStyle(.plain)
        .accessibilityHint(workoutVM.hasActiveWorkout ? "Returns to your active workout." : "Starts a blank workout.")
        .accessibilityIdentifier("start-free-workout")
    }

    private var quickActions: some View {
        Group {
            if !workoutVM.hasActiveWorkout {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("QUICK ACTIONS")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(WorkoutPalette.subduedText)

                    Button {
                        isShowingTemplatePicker = true
                    } label: {
                        quickActionRow(
                            icon: "rectangle.stack",
                            iconColor: WorkoutPalette.primary,
                            title: "Use a Template",
                            detail: "Follow a saved structure"
                        )
                    }
                    .buttonStyle(.plain)
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
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            Spacer()

            Image(systemName: isInformational ? "info.circle" : "chevron.right")
                .font(AppFont.captionBold)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
        .padding(Spacing.m)
        .background(WorkoutPalette.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(WorkoutPalette.border, lineWidth: 1)
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
                .foregroundStyle(WorkoutPalette.subduedText)

            if completedWorkouts.isEmpty {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppFont.headline)
                        .frame(width: 38, height: 38)
                        .foregroundStyle(WorkoutPalette.accent)
                        .background(WorkoutPalette.accentSurface)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Activity History")
                            .font(AppFont.subheadlineSemibold)
                        Text("Your completed sessions will appear here.")
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }
                }
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WorkoutPalette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .stroke(WorkoutPalette.border, lineWidth: 1)
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
                                    .foregroundStyle(WorkoutPalette.secondary)
                                    .background(WorkoutPalette.secondary.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.nom ?? "Session")
                                        .font(AppFont.subheadlineSemibold)
                                    Text(workout.startTime, style: .date)
                                        .font(AppFont.caption)
                                        .foregroundStyle(WorkoutPalette.subduedText)
                                }

                                Spacer()

                                Text("\(workout.exercises.count) ex")
                                    .font(AppFont.caption)
                                    .foregroundStyle(WorkoutPalette.subduedText)

                                Image(systemName: "chevron.right")
                                    .font(AppFont.captionBold)
                                    .foregroundStyle(WorkoutPalette.subduedText)
                            }
                            .padding(Spacing.m)
                            .background(WorkoutPalette.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                                    .stroke(WorkoutPalette.border, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                            .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var primaryCardTitle: LocalizedStringKey {
        guard let workout = workoutVM.activeWorkout else { return "Start Workout" }
        if let nom = workout.nom, !nom.isEmpty {
            return "Resume \(nom)"
        }
        return "Resume workout"
    }

    private var primaryCardSubtitle: LocalizedStringKey {
        guard let workout = workoutVM.activeWorkout else {
            return "Start a blank workout."
        }

        let completedSets = workout.completedSetCount
        let totalSets = workout.totalSetCount
        let nextDesc = nextExerciseDescription(in: workout)
        return "\(completedSets) / \(totalSets) sets · \(nextDesc)"
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) }),
              let setIndex = exercise.orderedSets.firstIndex(where: { !$0.done })
        else {
            return String(localized: "Workout complete")
        }

        let format = String(localized: "Next: %@ · Set %lld")
        return String(format: format, exercise.exercice.name, Int64(setIndex + 1))
    }

    private func openPrimaryWorkout() {
        if !workoutVM.hasActiveWorkout {
            workoutVM.startWorkout(using: modelContext)
        }
        isShowingActiveWorkout = true
    }

    private func startWorkout(from template: WorkoutTemplate) {
        workoutVM.startWorkout(with: template, using: modelContext)
        isShowingActiveWorkout = true
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
                    "No saved templates",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Create a workout template in Library, then start it from here.")
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
                                Text("\(template.exercises.count) exercises")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(AppFont.titleSmall)
                                .foregroundStyle(Color.gymPrimary)
                        }
                    }
                    .disabled(template.exercises.isEmpty)
                    .accessibilityIdentifier("workout-template-\(template.name)")
                    .accessibilityHint(template.exercises.isEmpty ? "Add an exercise before starting this template." : "Starts a new workout using this template.")
                }
            }
        }
        .navigationTitle("Start from template")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

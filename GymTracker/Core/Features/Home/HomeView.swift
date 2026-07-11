import SwiftUI
import SwiftData

struct HomeView: View {
    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    @Binding var isShowingActiveWorkout: Bool

    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @State private var showSetting = false
    @State private var isShowingTemplatePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                welcomeHeader
                primaryWorkoutCard
                quickActions
                recentActivity
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(WorkoutPalette.text)
        .background(WorkoutPalette.background)
        .tint(WorkoutPalette.primary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSetting = true
                } label: {
                    Image(systemName: "gearshape")
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 36)
                        .background(WorkoutPalette.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(WorkoutPalette.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
        .sheet(isPresented: $showSetting) {
            NavigationStack {
                SettingView()
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
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WorkoutPalette.subduedText)

            Text(workoutVM.hasActiveWorkout ? "Your workout is ready." : "Ready when you are.")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(workoutVM.hasActiveWorkout
                 ? "Continue where you left off."
                 : "Track your training session today.")
                .font(.subheadline)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
    }

    private var primaryWorkoutCard: some View {
        Button(action: openPrimaryWorkout) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        workoutVM.hasActiveWorkout ? "RESUME" : "QUICK START",
                        systemImage: workoutVM.hasActiveWorkout ? "figure.strengthtraining.traditional" : "bolt.fill"
                    )
                    .font(.caption.weight(.bold))
                    .tracking(0.7)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.bold))
                }

                Text(primaryCardTitle)
                    .font(.title3.weight(.bold))

                Text(primaryCardSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))

                if let workout = workoutVM.activeWorkout {
                    ProgressView(
                        value: Double(workout.completedSetCount),
                        total: Double(max(workout.totalSetCount, 1))
                    )
                    .tint(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .foregroundStyle(.white)
            .background(workoutVM.hasActiveWorkout ? WorkoutPalette.secondary : WorkoutPalette.primary)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(workoutVM.hasActiveWorkout ? "Returns to your active workout." : "Starts a blank workout.")
        .accessibilityIdentifier("start-free-workout")
    }

    private var quickActions: some View {
        Group {
            if !workoutVM.hasActiveWorkout {
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK ACTIONS")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkoutPalette.subduedText)

                    Button {
                        isShowingTemplatePicker = true
                    } label: {
                        quickActionRow(
                            icon: "rectangle.stack",
                            iconColor: WorkoutPalette.secondary,
                            title: "Start from a template",
                            detail: "Choose one of your saved workouts"
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
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 38, height: 38)
                .foregroundStyle(iconColor)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            Spacer()

            Image(systemName: isInformational ? "info.circle" : "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(WorkoutPalette.subduedText)
        }
        .padding(13)
        .background(WorkoutPalette.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WorkoutPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recentActivity: some View {
        let completedWorkouts = workouts.filter { $0.endTime != nil }

        return VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ACTIVITY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            if completedWorkouts.isEmpty {
                HStack(spacing: 13) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .foregroundStyle(WorkoutPalette.accent)
                        .background(WorkoutPalette.accentSurface)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your recent workouts")
                            .font(.subheadline.weight(.semibold))
                        Text("Completed sessions will appear here.")
                            .font(.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WorkoutPalette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WorkoutPalette.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(completedWorkouts.prefix(3), id: \.self) { workout in
                        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                            HStack(spacing: 13) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(WorkoutPalette.secondary)
                                    .background(WorkoutPalette.secondary.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(workout.nom ?? "Workout")
                                        .font(.subheadline.weight(.semibold))
                                    Text(workout.startTime, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(WorkoutPalette.subduedText)
                                }

                                Spacer()

                                Text("\(workout.exercises.count) ex")
                                    .font(.caption)
                                    .foregroundStyle(WorkoutPalette.subduedText)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(WorkoutPalette.subduedText)
                            }
                            .padding(13)
                            .background(WorkoutPalette.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(WorkoutPalette.border, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var primaryCardTitle: LocalizedStringKey {
        guard let workout = workoutVM.activeWorkout else { return "Blank Workout" }
        if let nom = workout.nom, !nom.isEmpty {
            return "Resume \(nom)"
        }
        return "Resume workout"
    }

    private var primaryCardSubtitle: LocalizedStringKey {
        guard let workout = workoutVM.activeWorkout else {
            return "Log exercises and sets as you train."
        }

        let completedSets = workout.completedSetCount
        let totalSets = workout.totalSetCount
        let nextDesc = nextExerciseDescription(in: workout)
        return "\(completedSets) / \(totalSets) sets · \(nextDesc)"
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.exercises.first(where: { $0.sets.contains(where: { !$0.done }) }),
              let setIndex = exercise.sets.firstIndex(where: { !$0.done })
        else {
            return String(localized: "Workout complete")
        }

        let format = String(localized: "Next: %@ · Set %lld")
        return String(format: format, exercise.exercice.name, Int64(setIndex + 1))
    }



    private func openPrimaryWorkout() {
        if !workoutVM.hasActiveWorkout {
            workoutVM.startWorkout()
        }
        isShowingActiveWorkout = true
    }

    private func startWorkout(from template: WorkoutTemplate) {
        workoutVM.startWorkout(with: template)
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.body.weight(.semibold))
                                Text("\(template.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(.title3)
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

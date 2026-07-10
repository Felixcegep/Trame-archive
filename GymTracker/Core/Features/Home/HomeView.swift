import SwiftUI
import SwiftData

struct HomeView: View {
    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]

    @Query private var exerciceTemplates: [ExerciceTemplate]
    @State private var showSetting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                welcomeHeader
                primaryWorkoutCard
                quickActions
                recentActivityPlaceholder
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
                 : "Start with a workout or continue a plan.")
                .font(.subheadline)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
    }

    private var primaryWorkoutCard: some View {
        Button(action: openPrimaryWorkout) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        workoutVM.hasActiveWorkout ? "RESUME" : "START WORKOUT",
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
                        value: Double(completedSetCount(in: workout)),
                        total: Double(max(totalSetCount(in: workout), 1))
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
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ACTIONS")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            if workoutVM.hasActiveWorkout {
                Button(action: openPrimaryWorkout) {
                    quickActionRow(
                        icon: "list.bullet",
                        iconColor: WorkoutPalette.primary,
                        title: "View current workout",
                        detail: "Log your next set or add an exercise"
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: startSampleWorkout) {
                    quickActionRow(
                        icon: "sparkles",
                        iconColor: WorkoutPalette.accent,
                        title: "Try a sample session",
                        detail: "Explore every set tracking style"
                    )
                }
                .buttonStyle(.plain)

                quickActionRow(
                    icon: "rectangle.stack",
                    iconColor: WorkoutPalette.secondary,
                    title: "Templates and plans",
                    detail: "Create and manage them in Library",
                    isInformational: true
                )
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

    private var recentActivityPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ACTIVITY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

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
        }
    }

    private var primaryCardTitle: String {
        guard let workout = workoutVM.activeWorkout else { return "Start a workout" }
        return "Resume \(workout.nom ?? "workout")"
    }

    private var primaryCardSubtitle: String {
        guard let workout = workoutVM.activeWorkout else {
            return "Create a workout as you train."
        }

        let completedSets = completedSetCount(in: workout)
        let totalSets = totalSetCount(in: workout)
        return "\(completedSets) / \(totalSets) sets · \(nextExerciseDescription(in: workout))"
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.exercises.first(where: { $0.sets.contains(where: { !$0.done }) }),
              let setIndex = exercise.sets.firstIndex(where: { !$0.done })
        else {
            return "Workout complete"
        }

        return "Next: \(exercise.exercice.name) · Set \(setIndex + 1)"
    }

    private func completedSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    private func totalSetCount(in workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func openPrimaryWorkout() {
        if !workoutVM.hasActiveWorkout {
            workoutVM.startWorkout()
        }

        guard navigationPath.last != .activeWorkout else { return }
        navigationPath.append(.activeWorkout)
    }

    private func startSampleWorkout() {
        let template = WorkoutTemplate(name: "Sample Workout", exercises: defaultTemplateExercises)
        workoutVM.startWorkoutWithTemplate(Template: template)
        navigationPath.append(.activeWorkout)
    }

    private var defaultTemplateExercises: [ExerciceTemplate] {
        TrackingType.allCases.map { trackingType in
            exerciceTemplates.first { $0.trackingType == trackingType } ?? sampleExercise(for: trackingType)
        }
    }

    private func sampleExercise(for trackingType: TrackingType) -> ExerciceTemplate {
        switch trackingType {
        case .weightAndReps:
            return ExerciceTemplate(name: "Bench Press", PrimaryMuscle: [.middleChest], trackingType: .weightAndReps, equipmentType: .barbell, resistanceType: .externalWeight, movementPattern: .horizontalPush, difficulty: .intermediate)
        case .repsOnly:
            return ExerciceTemplate(name: "Crunch", PrimaryMuscle: [.rectusAbdominis], trackingType: .repsOnly, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .isolation, difficulty: .beginner)
        case .weightedBodyweight:
            return ExerciceTemplate(name: "Pull Up", PrimaryMuscle: [.latissimusDorsi], trackingType: .weightedBodyweight, equipmentType: .bodyweight, resistanceType: .weightedBodyweight, movementPattern: .verticalPull, difficulty: .intermediate)
        case .assistedBodyweight:
            return ExerciceTemplate(name: "Assisted Pull Up", PrimaryMuscle: [.latissimusDorsi], trackingType: .assistedBodyweight, equipmentType: .machine, resistanceType: .assistedBodyweight, movementPattern: .verticalPull, difficulty: .beginner)
        case .duration:
            return ExerciceTemplate(name: "Plank", PrimaryMuscle: [.transverseAbdominis], trackingType: .duration, equipmentType: .bodyweight, resistanceType: .bodyweight, movementPattern: .antiRotation, difficulty: .beginner)
        case .durationAndDistance:
            return ExerciceTemplate(name: "Treadmill Run", PrimaryMuscle: [.quadriceps, .hamstrings, .calves], category: .cardio, trackingType: .durationAndDistance, equipmentType: .cardioMachine, difficulty: .beginner)
        }
    }
}

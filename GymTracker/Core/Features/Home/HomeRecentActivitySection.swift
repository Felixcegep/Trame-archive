import SwiftData
import SwiftUI

struct HomeRecentActivitySection: View {
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]

    var body: some View {
        let completedWorkouts = workouts.filter { $0.status == .completed }

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("HISTORY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            if completedWorkouts.isEmpty {
                emptyState
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(completedWorkouts.prefix(3), id: \.self) { workout in
                        workoutLink(workout)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.history)
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
    }

    private func workoutLink(_ workout: Workout) -> some View {
        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.checkmarkCircle)
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

                Image(systemName: AppIcon.chevronRight)
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

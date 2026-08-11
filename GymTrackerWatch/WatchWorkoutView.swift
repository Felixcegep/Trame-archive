import SwiftUI

struct WatchWorkoutView: View {
    let connectivity: WatchWorkoutConnectivity

    var body: some View {
        Group {
            if let snapshot = connectivity.snapshot {
                activeWorkout(snapshot)
            } else {
                ContentUnavailableView(
                    String(localized: "No active workout"),
                    systemImage: WatchIcon.phone,
                    description: Text(connectivity.connectionDescription)
                )
            }
        }
        .accessibilityIdentifier("watch-workout-screen")
    }

    private func activeWorkout(_ snapshot: WatchWorkoutDisplaySnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchSpacing.standard) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(snapshot.startTime, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Workout elapsed time"))
                }
                Text(snapshot.currentExerciseName ?? String(localized: "Workout complete on Watch"))
                    .font(.headline)
                    .lineLimit(2)
                if let current = snapshot.currentSet, let total = snapshot.totalSets {
                    Text(String(format: String(localized: "Set %lld of %lld"), Int64(current), Int64(total)))
                        .font(.title3.monospacedDigit())
                }

                Button {
                    connectivity.send("completeCurrentSet")
                } label: {
                    Label(String(localized: "Log current set"), systemImage: WatchIcon.complete)
                }
                .buttonStyle(.borderedProminent)
                .disabled(snapshot.currentSetOrderIndex == nil)

                restControls(snapshot)

                Button {
                    connectivity.send("completeWorkout")
                } label: {
                    Label(String(localized: "Finish on iPhone"), systemImage: WatchIcon.phone)
                }
                .buttonStyle(.bordered)

                if let status = connectivity.lastCommandStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("watch-command-status")
                }
            }
        }
    }

    @ViewBuilder
    private func restControls(_ snapshot: WatchWorkoutDisplaySnapshot) -> some View {
        switch snapshot.restPhase {
        case .running:
            if let deadline = snapshot.restEndDate {
                Text(timerInterval: .now...max(.now, deadline), countsDown: true)
                    .font(.title2.monospacedDigit())
            }
            HStack(spacing: WatchSpacing.compact) {
                Button { connectivity.send("pauseRest") } label: { Image(systemName: WatchIcon.pause) }
                    .accessibilityLabel(String(localized: "Pause rest"))
                Button { connectivity.send("extendRest", extensionSeconds: 30) } label: { Image(systemName: WatchIcon.addTime) }
                    .accessibilityLabel(String(localized: "Add 30 seconds"))
                Button { connectivity.send("skipRest") } label: { Image(systemName: WatchIcon.skip) }
                    .accessibilityLabel(String(localized: "Skip rest"))
            }
        case .paused:
            Text(String(format: String(localized: "%lld seconds remaining"), Int64(snapshot.pausedRemainingTime ?? 0)))
                .font(.title3.monospacedDigit())
            HStack(spacing: WatchSpacing.compact) {
                Button { connectivity.send("resumeRest") } label: { Image(systemName: WatchIcon.resume) }
                    .accessibilityLabel(String(localized: "Resume rest"))
                Button { connectivity.send("skipRest") } label: { Image(systemName: WatchIcon.skip) }
                    .accessibilityLabel(String(localized: "Skip rest"))
            }
        case .ready:
            Text(String(localized: "Rest complete"))
                .font(.headline)
        case .inactive:
            EmptyView()
        }
    }
}

import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct GymTrackerExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTrackerAttributes.self) { context in
            lockScreenCard(for: context)
                .activityBackgroundTint(context.state.restPhase == .running ? LiveActivityPalette.accent : LiveActivityPalette.secondary)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.restPhase == .inactive ? "figure.strengthtraining.traditional" : "timer")
                        .foregroundStyle(context.state.restPhase == .running ? LiveActivityPalette.accent : LiveActivityPalette.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    activityTime(for: context)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.restPhase == .inactive ? displayExerciseName(for: context) : "Rest between sets")
                            .font(.headline)
                            .lineLimit(1)

                        if context.state.restPhase == .inactive {
                            Text(setProgress(for: context))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    controls(for: context)
                }
            } compactLeading: {
                if context.state.restPhase == .running {
                    activityTime(for: context)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                }
            } compactTrailing: {
                if context.state.restPhase != .inactive {
                    Image(systemName: "timer")
                } else {
                    Text("\(context.state.currentSet ?? 1)/\(context.state.totalSeries ?? 0)")
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: context.state.restPhase == .inactive ? "figure.strengthtraining.traditional" : "timer")
            }
        }
    }

    @ViewBuilder
    private func lockScreenCard(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    context.state.restPhase == .inactive ? "WORKOUT" : "REST",
                    systemImage: context.state.restPhase == .inactive ? "figure.strengthtraining.traditional" : "timer"
                )
                .font(.caption.weight(.bold))
                .tracking(0.7)

                Spacer()

                activityTime(for: context)
                    .font(.headline.monospacedDigit().weight(.semibold))
            }

            if context.state.restPhase != .inactive {
                Text("Rest between sets")
                    .font(.headline)

                Text("Next up: \(displayExerciseName(for: context))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
            } else {
                Text(displayExerciseName(for: context))
                    .font(.headline)
                    .lineLimit(1)

                Text(setProgress(for: context))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))

                ProgressView(
                    value: Double(context.state.currentSet ?? 1),
                    total: Double(max(context.state.totalSeries ?? 1, 1))
                )
                .tint(.white.opacity(0.9))

            }

            controls(for: context)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func activityTime(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        if context.state.restPhase == .running, let restEnd = context.state.restEndDate {
            Text(timerInterval: Date.now...restEnd, countsDown: true)
        } else if context.state.restPhase == .paused, let remaining = context.state.pausedRemainingTime {
            Text("Paused · \(Int(remaining))s")
        } else {
            Text(context.attributes.startTime, style: .timer)
        }
    }

    @ViewBuilder
    private func controls(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        switch context.state.restPhase {
        case .inactive:
            if let exerciseOrder = context.state.currentExerciseOrderIndex,
               let setOrder = context.state.currentSetOrderIndex {
                Button(intent: CompleteCurrentSetIntent(
                    workoutID: context.attributes.workoutID,
                    expectedExerciseOrderIndex: exerciseOrder,
                    expectedSetOrderIndex: setOrder
                )) {
                    Label("Complete set", systemImage: "checkmark.circle.fill")
                }
                .accessibilityLabel("Complete current set")
            }
        case .running:
            HStack(spacing: 12) {
                Button(intent: ExtendRestIntent(workoutID: context.attributes.workoutID, seconds: 30)) {
                    Text("+30s")
                }
                .accessibilityLabel("Add 30 seconds to rest")

                Button(intent: PauseRestIntent(workoutID: context.attributes.workoutID)) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .accessibilityLabel("Pause rest")

                Button(intent: SkipRestIntent(workoutID: context.attributes.workoutID)) {
                    Label("Skip", systemImage: "forward.fill")
                }
                .accessibilityLabel("Skip rest")
            }
        case .paused:
            HStack(spacing: 12) {
                Button(intent: ExtendRestIntent(workoutID: context.attributes.workoutID, seconds: 30)) {
                    Text("+30s")
                }
                .accessibilityLabel("Add 30 seconds to paused rest")

                Button(intent: ResumeRestIntent(workoutID: context.attributes.workoutID)) {
                    Label("Resume", systemImage: "play.fill")
                }
                .accessibilityLabel("Resume rest")

                Button(intent: SkipRestIntent(workoutID: context.attributes.workoutID)) {
                    Label("Skip", systemImage: "forward.fill")
                }
                .accessibilityLabel("Skip rest")
            }
        }
    }

    private func displayExerciseName(for context: ActivityViewContext<GymTrackerAttributes>) -> String {
        context.state.currentExerciseName ?? "Add an exercise"
    }

    private func setProgress(for context: ActivityViewContext<GymTrackerAttributes>) -> String {
        "Set \(context.state.currentSet ?? 1) of \(context.state.totalSeries ?? 0)"
    }
}

private enum LiveActivityPalette {
    static let secondary = Color(red: 0x48 / 255.0, green: 0x7A / 255.0, blue: 0x6C / 255.0)
    static let accent = Color(red: 0xA1 / 255.0, green: 0x68 / 255.0, blue: 0x3A / 255.0)
}

extension GymTrackerAttributes {
    fileprivate static var preview: GymTrackerAttributes {
        GymTrackerAttributes(workoutID: UUID(), startTime: .now)
    }
}

extension GymTrackerAttributes.ContentState {
    fileprivate static var preview: GymTrackerAttributes.ContentState {
        GymTrackerAttributes.ContentState(
            currentExerciseName: "Rear Delt Fly",
            currentSet: 1,
            totalSeries: 3,
            currentExerciseOrderIndex: 0,
            currentSetOrderIndex: 0,
            restPhase: .inactive,
            restEndDate: nil,
            pausedRemainingTime: nil
        )
    }
}

import ActivityKit
import WidgetKit
import SwiftUI

struct GymTrackerExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTrackerAttributes.self) { context in
            lockScreenCard(for: context)
                .activityBackgroundTint(context.state.restTimeActive ? LiveActivityPalette.accent : LiveActivityPalette.secondary)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.restTimeActive ? "timer" : "figure.strengthtraining.traditional")
                        .foregroundStyle(context.state.restTimeActive ? LiveActivityPalette.accent : LiveActivityPalette.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    activityTime(for: context)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.restTimeActive ? "Rest between sets" : displayExerciseName(for: context))
                            .font(.headline)
                            .lineLimit(1)

                        if !context.state.restTimeActive {
                            Text(setProgress(for: context))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                if context.state.restTimeActive {
                    activityTime(for: context)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                }
            } compactTrailing: {
                if context.state.restTimeActive {
                    Image(systemName: "timer")
                } else {
                    Text("\(context.state.currentSerie ?? 1)/\(context.state.totalSeries ?? 0)")
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: context.state.restTimeActive ? "timer" : "figure.strengthtraining.traditional")
            }
        }
    }

    @ViewBuilder
    private func lockScreenCard(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    context.state.restTimeActive ? "REST" : "RESUME",
                    systemImage: context.state.restTimeActive ? "timer" : "figure.strengthtraining.traditional"
                )
                .font(.caption.weight(.bold))
                .tracking(0.7)

                Spacer()

                activityTime(for: context)
                    .font(.headline.monospacedDigit().weight(.semibold))
            }

            if context.state.restTimeActive {
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
                    value: Double(context.state.currentSerie ?? 1),
                    total: Double(max(context.state.totalSeries ?? 1, 1))
                )
                .tint(.white.opacity(0.9))

            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func activityTime(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        if context.state.restTimeActive, let restEnd = context.state.RestTime {
            Text(timerInterval: Date.now...restEnd, countsDown: true)
        } else {
            Text(context.attributes.startTime, style: .timer)
        }
    }

    private func displayExerciseName(for context: ActivityViewContext<GymTrackerAttributes>) -> String {
        context.state.currentExerciseName ?? "Add an exercise"
    }

    private func setProgress(for context: ActivityViewContext<GymTrackerAttributes>) -> String {
        "Set \(context.state.currentSerie ?? 1) of \(context.state.totalSeries ?? 0)"
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
            currentSerie: 1,
            totalSeries: 3,
            restTimeActive: false,
            RestTime: nil
        )
    }
}

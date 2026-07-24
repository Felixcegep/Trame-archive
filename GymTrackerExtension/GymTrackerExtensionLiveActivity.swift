import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct GymTrackerExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTrackerAttributes.self) { context in
            lockScreenCard(for: context)
                .activityBackgroundTint(context.state.restPhase == .inactive ? LiveActivityPalette.secondary : LiveActivityPalette.accent)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: islandSymbol(for: context.state.presentationState))
                        .foregroundStyle(context.state.restPhase == .inactive ? LiveActivityPalette.secondary : LiveActivityPalette.accent)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    activityTime(for: context)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }

                DynamicIslandExpandedRegion(.center) {
                    islandCenter(for: context.state.presentationState)
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
                compactTrailing(for: context.state.presentationState)
            } minimal: {
                Image(systemName: islandSymbol(for: context.state.presentationState))
            }
        }
    }

    @ViewBuilder
    private func lockScreenCard(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        let presentation = context.state.presentationState

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

            switch presentation {
            case .emptyWorkout:
                Text("Add your first exercise")
                    .font(.headline)
            case let .activeSet(exercise, set, total):
                Text(exercise)
                    .font(.headline)
                    .lineLimit(1)
                Text("Set \(set) of \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
                ProgressView(value: Double(set), total: Double(total))
                    .tint(.white.opacity(0.9))
            case let .resting(nextExercise):
                Text("Rest between sets")
                    .font(.headline)
                Text(nextExercise.map { "Next up: \($0)" } ?? "Next: review your workout")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
            case .readyForReview:
                Text("All sets completed")
                    .font(.headline)
                Text("Open GymTracker to review and finish")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
                ProgressView(value: 1, total: 1)
                    .tint(.white.opacity(0.9))
            }

            controls(for: context)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lockScreenAccessibilityLabel(for: presentation))
    }

    @ViewBuilder
    private func islandCenter(for presentation: WorkoutActivityPresentationState) -> some View {
        VStack(spacing: 2) {
            switch presentation {
            case .emptyWorkout:
                Text("Add your first exercise")
                    .font(.headline)
                    .lineLimit(1)
            case let .activeSet(exercise, set, total):
                Text(exercise)
                    .font(.headline)
                    .lineLimit(1)
                Text("Set \(set) of \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .resting:
                Text("Rest between sets")
                    .font(.headline)
            case .readyForReview:
                Text("All sets completed")
                    .font(.headline)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func compactTrailing(for presentation: WorkoutActivityPresentationState) -> some View {
        switch presentation {
        case let .activeSet(_, set, total):
            Text("\(set)/\(total)")
                .font(.caption2.monospacedDigit())
        case .resting:
            Image(systemName: "timer")
        case .readyForReview:
            Image(systemName: "checkmark.circle.fill")
        case .emptyWorkout:
            Image(systemName: "figure.strengthtraining.traditional")
        }
    }

    @ViewBuilder
    private func activityTime(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        if context.state.restPhase == .running,
           let restEnd = context.state.restEndDate,
           let interval = LiveActivityTimeRange.restInterval(now: .now, end: restEnd) {
            Text(timerInterval: interval, countsDown: true)
        } else if context.state.restPhase == .running {
            // A stale ActivityKit update can outlive its persisted rest
            // deadline. Never construct an invalid ClosedRange for the timer.
            Text("Ready")
        } else if context.state.restPhase == .paused, let remaining = context.state.pausedRemainingTime {
            Text("Paused · \(Int(remaining))s")
        } else {
            Text(context.attributes.startTime, style: .timer)
        }
    }

    @ViewBuilder
    private func controls(for context: ActivityViewContext<GymTrackerAttributes>) -> some View {
        switch context.state.presentationState {
        case .emptyWorkout, .readyForReview:
            EmptyView()
        case .activeSet:
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
        case .resting:
            switch context.state.restPhase {
            case .running:
                HStack(spacing: 12) {
                    Button(intent: ExtendRestIntent(workoutID: context.attributes.workoutID, seconds: 30)) { Text("+30s") }
                    Button(intent: PauseRestIntent(workoutID: context.attributes.workoutID)) { Label("Pause", systemImage: "pause.fill") }
                    Button(intent: SkipRestIntent(workoutID: context.attributes.workoutID)) { Label("Skip", systemImage: "forward.fill") }
                }
            case .paused:
                HStack(spacing: 12) {
                    Button(intent: ExtendRestIntent(workoutID: context.attributes.workoutID, seconds: 30)) { Text("+30s") }
                    Button(intent: ResumeRestIntent(workoutID: context.attributes.workoutID)) { Label("Resume", systemImage: "play.fill") }
                    Button(intent: SkipRestIntent(workoutID: context.attributes.workoutID)) { Label("Skip", systemImage: "forward.fill") }
                }
            case .inactive:
                EmptyView()
            }
        }
    }

    private func islandSymbol(for presentation: WorkoutActivityPresentationState) -> String {
        switch presentation {
        case .resting: "timer"
        case .readyForReview: "checkmark.circle.fill"
        case .emptyWorkout, .activeSet: "figure.strengthtraining.traditional"
        }
    }

    private func lockScreenAccessibilityLabel(for presentation: WorkoutActivityPresentationState) -> String {
        switch presentation {
        case .emptyWorkout: "Workout started, no exercises yet"
        case let .activeSet(exercise, set, total): "Workout in progress, \(exercise), set \(set) of \(total)"
        case let .resting(nextExercise): nextExercise.map { "Rest between sets, next up \($0)" } ?? "Rest between sets, review your workout next"
        case .readyForReview: "All sets completed. Open GymTracker to review and finish."
        }
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
    fileprivate static var activePreview: GymTrackerAttributes.ContentState {
        GymTrackerAttributes.ContentState(
            currentExerciseName: "Rear Delt Fly",
            currentSet: 1,
            totalSeries: 3,
            currentExerciseOrderIndex: 0,
            currentSetOrderIndex: 0,
            hasAnySets: true,
            restPhase: .inactive,
            restEndDate: nil,
            pausedRemainingTime: nil
        )
    }
}

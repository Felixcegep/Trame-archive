import SwiftUI

/// A timed mobility hold, drawn as a ring rather than read as a bare number.
///
/// Replaces `MobilityHoldProgressLabel`, which stated "42 / 60 sec" as text and
/// nothing else. That is the one thing a held stretch makes hardest to read —
/// eyes shut, focus on the position, not the phone — and it gave no sense of
/// *how much is left* without doing the subtraction. A ring answers "nearly
/// there?" at a glance, the same job Active Workout's rest dial does for the
/// gap between sets.
///
/// Deliberately calm rather than urgent: unlike the rest dial, there is no
/// colour ramp toward red and no pulse in the final seconds. Nobody needs to
/// hurry out of a stretch — holding a few seconds past target is normal, and a
/// ring implying otherwise would be coaching the wrong instinct. Colour only
/// ever carries two states, matching what the label it replaces already meant:
/// accent while holding, secondary once the target is reached.
struct MobilityHoldRingView: View {
    let elapsedSeconds: Int
    let targetSeconds: Int
    let movementName: String
    /// Freezes the digits into "Paused at N sec" without changing the ring's
    /// size or position. Pausing used to swap this whole hero for a small text
    /// label, which meant the card visibly shrank the moment someone paused —
    /// exactly the kind of movement a phone propped up nearby, half-watched,
    /// should not make.
    var isPaused: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasReachedTarget: Bool { elapsedSeconds >= targetSeconds }

    private var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(1, Double(elapsedSeconds) / Double(targetSeconds))
    }

    private var ringColor: Color {
        hasReachedTarget ? Color.trameCompleted : Color.trameMobility
    }

    private var ringSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 160 : 200
    }

    private var ringWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 10 : 14
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.trameRow, lineWidth: ringWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : AppMotion.compact, value: progress)

            digits
                .padding(ringWidth * 1.6)
        }
        .frame(width: ringSize, height: ringSize)
        .animation(reduceMotion ? nil : AppMotion.compact, value: hasReachedTarget)
        // A Bool trigger never fires on its initial value, so re-entering a
        // movement whose target already passed stays silent: reaching the
        // target is the event, not observing that it was reached.
        // Gated on `!isPaused` so pausing at the exact instant a target is
        // crossed can never announce "reached" underneath digits that are
        // simultaneously saying "paused" — the two would contradict each
        // other in the one channel (VoiceOver) that can't show both at once.
        .gymFeedback(.timedTargetReached, trigger: hasReachedTarget) { _, reached in
            reached && !isPaused
        }
        .onChange(of: hasReachedTarget) { _, reached in
            guard reached, !isPaused else { return }
            GymAnnouncement.post(
                String(localized: "Target duration reached for \(movementName).")
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                isPaused
                    ? String(localized: "Paused at \(elapsedSeconds) seconds")
                    : hasReachedTarget
                        ? String(localized: "Target reached, \(elapsedSeconds) seconds")
                        : String(localized: "\(elapsedSeconds) of \(targetSeconds) seconds")
            )
        )
    }

    @ViewBuilder
    private var digits: some View {
        if isPaused {
            VStack(spacing: Spacing.xs) {
                Image(systemName: AppIcon.pause)
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.trameText)
                Text("Paused at \(elapsedSeconds) sec")
                    .font(AppFont.subheadlineSemibold)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameText)
                    .multilineTextAlignment(.center)
            }
        } else if hasReachedTarget {
            VStack(spacing: Spacing.xs) {
                Image(systemName: AppIcon.checkmarkCircle)
                    .font(AppFont.displayMedium)
                    .foregroundStyle(Color.trameCompleted)
                Text("\(elapsedSeconds) sec")
                    .font(AppFont.metricCompact)
                    .foregroundStyle(Color.trameSubdued)
            }
        } else {
            VStack(spacing: 0) {
                Text("\(elapsedSeconds)")
                    .font(AppFont.timer)
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(Color.trameText)
                Text("of \(targetSeconds) sec")
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
            }
        }
    }
}

#Preview {
    MobilityHoldRingView(elapsedSeconds: 42, targetSeconds: 60, movementName: "Couch Stretch")
        .padding()
        .background(Color.trameCanvas)
}

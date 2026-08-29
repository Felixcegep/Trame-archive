import SwiftUI

/// Where the run stands right now: plan name, lifecycle status, and the
/// block/week/session or cycle/slot position behind it.
///
/// Both the fixed and rotation paths share this header so the two surfaces read
/// as one feature rather than two screens that happen to be adjacent.
struct ProgramPathHeader: View {
    let title: String
    let statusTitle: String
    /// Paused, ended, and archived runs read as inert: the status badge drops
    /// its accent tint rather than competing with the live primary action.
    let isMuted: Bool
    let positionLines: [String]
    var progressFraction: Double?
    var progressSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymEyebrow("Plan path")

            Text(title)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)

            GymStatusBadge(
                title: statusTitle,
                systemImage: isMuted ? AppIcon.pause : AppIcon.play,
                tint: isMuted ? Color.gymSubduedText : Color.trameAction
            )
            .accessibilityHidden(true)

            // Indexed rather than keyed by value: two position lines can render
            // the same text, and duplicate ForEach identities drop rows.
            ForEach(Array(positionLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progressFraction, let progressSummary {
                ProgressView(value: progressFraction)
                    .tint(Color.trameAction)
                    .accessibilityHidden(true)
                Text(progressSummary)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("program-path-header")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        ([title, statusTitle] + positionLines + [progressSummary].compactMap { $0 })
            .joined(separator: ", ")
    }
}

/// The one session the run is actually asking for, with its primary action.
///
/// This is the only place on the path that carries a filled button. Everything
/// below it is history or preview, so a single call to action stays obvious at
/// any Dynamic Type size.
struct ProgramPathCurrentSession: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let eyebrow: LocalizedStringKey
    let workoutName: String
    var detailLines: [String] = []
    var stateStyle: ProgramPathPresentation.StateStyle?
    var primaryAction: PrimaryAction?

    /// There is deliberately no disabled variant. When a run cannot be started
    /// the action is absent and a section footer says why, which reads better
    /// than a dimmed button with no explanation.
    struct PrimaryAction {
        let title: String
        let systemImage: String
        let identifier: String
        var hint: String?
        let perform: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GymEyebrow(eyebrow, tint: .trameAction)

                Text(workoutName)
                    .font(AppFont.titleSmallSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                if let stateStyle {
                    Label(stateStyle.title, systemImage: stateStyle.systemImage)
                        .font(AppFont.captionBold)
                        .foregroundStyle(stateStyle.tint)
                        .accessibilityIdentifier(stateStyle.identifier)
                }

                ForEach(Array(detailLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("program-path-current-session")

            if let primaryAction {
                Button(action: primaryAction.perform) {
                    Label(primaryAction.title, systemImage: primaryAction.systemImage)
                }
                .buttonStyle(.tramePrimaryAction)
                .accessibilityIdentifier(primaryAction.identifier)
                .accessibilityHint(primaryAction.hint ?? "")
                .animation(reduceMotion ? nil : AppMotion.compact, value: primaryAction.title)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// Derived inconsistencies the path found while reading the run.
///
/// These are explanations, not errors the user caused, so they stay descriptive
/// and never block the rest of the screen from rendering.
struct ProgramPathWarningView: View {
    let messages: [String]

    var body: some View {
        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
            Label {
                Text(message)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: AppIcon.warning)
                    .foregroundStyle(Color.gymAccent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("program-path-warning-\(index)")
        }
    }
}

/// Shown when the route cannot resolve a run at all — the run was deleted,
/// restored from a backup that no longer contains it, or replaced.
struct ProgramPathUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "Plan path unavailable",
            systemImage: AppIcon.warning,
            description: Text("This plan run may have been removed or replaced. Choose a plan to start a new one.")
        )
        .accessibilityIdentifier("program-path-unavailable")
    }
}

/// A quiet row that links into an adjacent flow (the schedule, a completed
/// workout). Kept visually distinct from the primary action so the path never
/// shows two competing calls to action.
struct ProgramPathLinkLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var detail: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                if let detail {
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } icon: {
            GymIconChip(systemImage: systemImage)
        }
    }
}

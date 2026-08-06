import SwiftUI

/// Plan name, reviewed week position, block/phase, run status, and the
/// scheduled date range this week actually spans.
///
/// A distinct type from `ProgramPathHeader` even though the shapes are
/// similar: that component hardcodes its own `program-path-header`
/// accessibility identifier internally, and wrapping it would risk exactly
/// the container-identifier-shadows-child pitfall this feature's
/// accessibility contract explicitly warns against.
struct WeeklyProgramReviewHeader: View {
    let planName: String
    let weekPositionTitle: String
    let blockName: String?
    let phaseType: PlanPhaseType?
    let statusTitle: String
    let statusNote: String?
    let isMuted: Bool
    let dateRangeTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymEyebrow("Weekly review")

            Text(planName)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)

            Text(weekPositionTitle)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)

            if blockName != nil || phaseType != nil {
                ChipFlowLayout(spacing: Spacing.s) {
                    if let blockName {
                        GymTagChip(title: blockName, tint: .gymAccent, style: .outlined)
                    }
                    if let phaseType {
                        GymTagChip(
                            title: ProgramPathPresentation.phaseTitle(phaseType),
                            systemImage: phaseType == .deload ? AppIcon.pause : AppIcon.progression,
                            tint: phaseType == .deload ? .gymAccent : .gymPrimary
                        )
                    }
                }
            }

            GymStatusBadge(
                title: statusTitle,
                systemImage: isMuted ? AppIcon.pause : AppIcon.play,
                tint: isMuted ? Color.gymSubduedText : Color.gymPrimary
            )
            .accessibilityHidden(true)

            if let statusNote {
                Text(statusNote)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let dateRangeTitle {
                Text(dateRangeTitle)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("weekly-review-header")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        ([planName, weekPositionTitle, blockName]
            + [phaseType.map(ProgramPathPresentation.phaseTitle)]
            + [statusTitle, statusNote, dateRangeTitle])
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// Derived inconsistencies the review found while reading the week's
/// evidence. Descriptive, never blocking — the rest of the review still
/// renders around them.
struct WeeklyProgramReviewWarningView: View {
    let messages: [String]

    var body: some View {
        ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
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
            .accessibilityIdentifier("weekly-review-warning")
        }
    }
}

/// Shown when the route cannot resolve a run at all — the run was deleted,
/// belongs to a repeating plan, or the projection lookup failed.
struct WeeklyProgramReviewUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "Weekly review unavailable",
            systemImage: AppIcon.warning,
            description: Text("This plan run may have been removed or replaced.")
        )
        .accessibilityIdentifier("weekly-review-unavailable")
    }
}

import SwiftUI

/// The whole fixed run, in plan order: one section per run week, introduced by
/// its block whenever the block changes.
///
/// This is a vertical `List` rather than a horizontal diagram on purpose. The
/// path can be dozens of sessions long, and a list keeps every row reachable by
/// VoiceOver, resizable under Dynamic Type, and free to wrap.
struct FixedProgramPathTimeline: View {
    let projection: FixedProgramPathProjection
    let onReschedule: (FixedProgramPathProjection.Session) -> Void

    var body: some View {
        ForEach(weeks, id: \.week.id) { item in
            ProgramPathWeekSection(
                week: item.week,
                blockHeader: item.isBlockStart ? item.week.block : nil,
                currentSessionID: projection.currentSessionID,
                onReschedule: onReschedule
            )
        }
    }

    /// A week paired with the block context it should introduce. Block headers
    /// only render where the block actually changes, so a four-week block reads
    /// as one unit instead of repeating its name four times.
    private struct TimelineWeek {
        let week: FixedProgramPathProjection.Week
        let isBlockStart: Bool
    }

    private var weeks: [TimelineWeek] {
        var previousBlockID: UUID?
        return projection.weeks.map { week in
            let isBlockStart = week.block?.id != previousBlockID
            previousBlockID = week.block?.id
            return TimelineWeek(week: week, isBlockStart: isBlockStart)
        }
    }
}

/// One run week and its sessions.
struct ProgramPathWeekSection: View {
    let week: FixedProgramPathProjection.Week
    let blockHeader: FixedProgramPathProjection.Block?
    let currentSessionID: UUID?
    let onReschedule: (FixedProgramPathProjection.Session) -> Void

    var body: some View {
        Section {
            ForEach(week.sessions) { session in
                row(session)
                    .listRowBackground(rowBackground(for: session))
            }
        } header: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if let blockHeader {
                    ProgramPathBlockHeader(block: blockHeader)
                }
                Text(ProgramPathPresentation.weekTitle(week))
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .textCase(nil)
            .padding(.bottom, Spacing.xxs)
            .accessibilityIdentifier("program-path-week-\(week.runWeekIndex)")
        } footer: {
            // Describes the block, not the cursor. Whether this deload is the
            // one you are in or one still ahead is answered by the callout at
            // the top of the path, which knows where the cursor actually is.
            if let blockHeader, blockHeader.isDeload {
                ProgramPathDeloadView(
                    title: ProgramPathPresentation.deloadWeekTitle,
                    detail: ProgramPathPresentation.deloadReductions(blockHeader),
                    emphasis: .quiet
                )
            }
        }
    }

    /// The current session keeps the same tinted surface Active Workout uses
    /// for the set you are on, so "where am I" reads the same way in both.
    private func rowBackground(for session: FixedProgramPathProjection.Session) -> Color? {
        session.id == currentSessionID ? Color.gymCurrentSetSurface : nil
    }

    @ViewBuilder
    private func row(_ session: FixedProgramPathProjection.Session) -> some View {
        let content = ProgramPathSessionRow(
            session: session,
            isCurrent: session.id == currentSessionID
        )

        switch session.action {
        case .openCompletedWorkout(let workoutID)?:
            NavigationLink {
                ProgramPathCompletedWorkoutDestination(workoutID: workoutID)
            } label: {
                content
            }
            .accessibilityIdentifier("program-path-session-completed")
            .accessibilityHint(Text("Opens the completed workout."))

        case .rescheduleFixedWorkout?:
            Button {
                onReschedule(session)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("program-path-session-reschedulable")
            .accessibilityHint(Text("Opens the reschedule picker."))

        default:
            content
                .accessibilityIdentifier("program-path-session")
        }
    }
}

/// Introduces a block: its name, its phase, and where it sits in the plan.
struct ProgramPathBlockHeader: View {
    let block: FixedProgramPathProjection.Block

    var body: some View {
        // A flow layout rather than an HStack: at accessibility text sizes the
        // phase chip drops below the block name instead of truncating it.
        ChipFlowLayout(spacing: Spacing.s) {
            Text(block.name)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)

            GymTagChip(
                title: ProgramPathPresentation.phaseTitle(block.phaseType),
                systemImage: block.isDeload ? AppIcon.pause : AppIcon.progression,
                tint: block.isDeload ? Color.gymAccent : Color.gymPrimary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One session on the path.
///
/// State is carried by an icon plus a written label, never by tint alone, and
/// the current session adds a badge on top of its tinted row so the emphasis
/// survives both Increase Contrast and grayscale.
struct ProgramPathSessionRow: View {
    let session: FixedProgramPathProjection.Session
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: style.systemImage)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(style.tint)
                .frame(width: Spacing.xxl, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(session.workoutName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                if let rescheduled = ProgramPathPresentation.rescheduledDetail(session) {
                    Label(rescheduled, systemImage: AppIcon.reschedule)
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymAccent)
                        .accessibilityIdentifier("program-path-session-rescheduled")
                }
            }

            Spacer(minLength: Spacing.s)

            if isCurrent {
                GymStatusBadge(
                    title: String(localized: "Current"),
                    systemImage: AppIcon.play,
                    tint: Color.gymPrimary
                )
                .accessibilityIdentifier("program-path-session-current")
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var style: ProgramPathPresentation.StateStyle {
        ProgramPathPresentation.style(for: session.displayState)
    }

    private var detail: String {
        [ProgramPathPresentation.scheduledDateTitle(session.scheduledDate), style.title]
            .joined(separator: " · ")
    }

    private var accessibilityLabel: String {
        var parts = [session.workoutName, style.title, ProgramPathPresentation.scheduledDateTitle(session.scheduledDate)]
        if let rescheduled = ProgramPathPresentation.rescheduledDetail(session) {
            parts.append(rescheduled)
        }
        if isCurrent {
            parts.append(String(localized: "Current session"))
        }
        return parts.joined(separator: ", ")
    }
}

/// A deload callout. Used twice: as a prominent card near the top of the path
/// when a deload is current or next, and as a quiet week footer inside the
/// timeline where the deload block begins.
struct ProgramPathDeloadView: View {
    enum Emphasis {
        case prominent
        case quiet
    }

    let title: String
    let detail: String?
    var emphasis: Emphasis = .prominent

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(emphasis == .prominent ? AppFont.subheadlineSemibold : AppFont.caption)
                    .foregroundStyle(emphasis == .prominent ? Color.gymText : Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } icon: {
            Image(systemName: AppIcon.pause)
                .foregroundStyle(Color.gymAccent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("program-path-deload")
    }
}

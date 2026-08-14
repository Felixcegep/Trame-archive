import SwiftData
import SwiftUI

/// Visually subordinate supporting actions on Today.
///
/// Renders supporting items (active mobility in progress, due mobility program session,
/// exercise library, and stretch routines) in a single compact, grouped surface below the
/// primary workout card. Workout execution remains visually primary while supporting
/// actions stay easily accessible without competing at equal visual weight.
struct HomeTodaySection: View {
    let onOpenExercises: () -> Void
    let onOpenMobility: () -> Void
    let onResumeMobility: (MobilitySession) -> Void

    @Query(
        filter: #Predicate<MobilitySession> { $0.statusRaw == "active" },
        sort: \MobilitySession.updatedAt,
        order: .reverse
    ) private var mobilitySessions: [MobilitySession]
    @Query(filter: #Predicate<MobilityProgramRun> { $0.statusRaw == "active" })
    private var mobilityProgramRuns: [MobilityProgramRun]

    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Passed pre-localized: `LibrarySectionTitle` takes a `String`, so a
            // bare literal would never reach the string catalog.
            LibrarySectionTitle(String(localized: "Quick access"))

            GymCard {
                VStack(spacing: 0) {
                    if let activeMobilitySession {
                        resumeMobilityRow(activeMobilitySession)
                        Divider().background(Color.gymBorder)
                    } else if let dueProgramSession {
                        dueMobilityProgramRow(dueProgramSession)
                        Divider().background(Color.gymBorder)
                    }

                    // Neutral chips.
                    //
                    // These were tinted primary and accent, which spent two of
                    // the palette's meanings on rows that carry no state:
                    // "Exercises" is not an action in progress and "Stretch" is
                    // not something needing attention — they are doors. Colour
                    // on a door is decoration, and it competed with the two
                    // things on Today that genuinely are states (a session in
                    // progress, a day trained). The glyph still distinguishes
                    // them; the hue no longer claims anything.
                    quickAccessRow(
                        title: "Exercises",
                        subtitle: "Browse the exercise library",
                        icon: AppIcon.muscles,
                        tint: Color.gymSubduedText,
                        surface: Color.gymRowSurface,
                        identifier: "today-open-exercises",
                        hint: "Opens the exercise library in Train.",
                        action: onOpenExercises
                    )

                    if featureFlags.isEnabled(.mobility) {
                        Divider().background(Color.gymBorder)

                        quickAccessRow(
                            title: "Stretch",
                            subtitle: "Mobility routines and programs",
                            icon: AppIcon.mobility,
                            tint: Color.gymSubduedText,
                            surface: Color.gymRowSurface,
                            identifier: "today-open-mobility",
                            hint: "Opens mobility routines in Train.",
                            action: onOpenMobility
                        )
                    }
                }
            }
        }
    }

    /// The next pending session of any followed mobility plan, scheduled for
    /// today or earlier (overdue). This only surfaces awareness — starting
    /// it, rescheduling it, or skipping it stays in the dedicated mobility
    /// plan screen, which owns the program's lifecycle rules; Today never
    /// selects a prescription itself, matching `TodayMobilityRowPolicy`.
    private var dueProgramSession: (run: MobilityProgramRun, progress: MobilityProgramSessionProgress)? {
        guard featureFlags.isEnabled(.mobilityProgram) else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for run in mobilityProgramRuns where run.status == .active {
            guard let next = MobilityProgramRunCoordinator.nextSessionProgress(in: run),
                  let scheduledDate = next.scheduledDate,
                  calendar.startOfDay(for: scheduledDate) <= today
            else { continue }
            return (run, next)
        }
        return nil
    }

    private func dueMobilityProgramRow(_ due: (run: MobilityProgramRun, progress: MobilityProgramSessionProgress)) -> some View {
        Button(action: onOpenMobility) {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.mobility)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymAccent)
                    .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
                    .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(due.progress.sessionNameSnapshot)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                    Text(due.run.sourceProgramName)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("today-open-mobility-plan-session")
        .accessibilityLabel("\(due.progress.sessionNameSnapshot), \(due.run.sourceProgramName)")
        .accessibilityHint("Opens Mobility to start this plan session.")
    }

    private var activeMobilitySession: MobilitySession? {
        // Routed through the policy rather than testing the session inline, so
        // the rule that Today resumes work but never picks a routine stays in
        // one place with its own coverage.
        guard TodayMobilityRowPolicy.shouldShowRow(
            hasActiveMobilitySession: mobilitySessions.contains { $0.status == .active }
        ) else { return nil }
        return mobilitySessions.first { $0.status == .active }
    }

    private func resumeMobilityRow(_ session: MobilitySession) -> some View {
        let position = min(session.currentEntryIndex + 1, session.entries.count)
        let value = String(localized: "Resume · \(position) of \(session.entries.count)")

        return Button {
            onResumeMobility(session)
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.mobility)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymAccent)
                    .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
                    .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text("Stretch in progress")
                            .font(AppFont.subheadlineBold)
                            .foregroundStyle(Color.gymText)
                        GymStatusBadge(title: "Active", systemImage: AppIcon.play, tint: Color.gymAccent)
                    }
                    Text(value)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("resume-mobility-session")
        .accessibilityLabel("Stretch in progress, \(value)")
    }

    private func quickAccessRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        tint: Color,
        surface: Color,
        identifier: String,
        hint: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: icon)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(tint)
                    .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
                    .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(identifier)
        .accessibilityHint(hint)
    }
}

/// Today resumes performed work but never selects a reusable prescription.
///
/// A warm-up is prescription context selected through a template or rotation
/// link before workout creation. Standalone routine discovery and selection
/// belongs to Train — which is where the Stretch tile navigates to, rather than
/// starting anything here.
enum TodayMobilityRowPolicy {
    static func shouldShowRow(hasActiveMobilitySession: Bool) -> Bool {
        hasActiveMobilitySession
    }
}

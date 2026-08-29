import SwiftData
import SwiftUI

/// Active or due mobility training support on Today.
///
/// Positioned directly below the primary workout card so that in-progress
/// or scheduled mobility work is immediately actionable before temporal context.
struct HomeActiveTrainingSupport: View {
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
        if let activeMobilitySession {
            resumeMobilityRow(activeMobilitySession)
        } else if let dueProgramSession {
            dueMobilityProgramRow(dueProgramSession)
        }
    }

    private var activeMobilitySession: MobilitySession? {
        guard TodayMobilityRowPolicy.shouldShowRow(
            hasActiveMobilitySession: mobilitySessions.contains { $0.status == .active }
        ) else { return nil }
        return mobilitySessions.first { $0.status == .active }
    }

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

    private func resumeMobilityRow(_ session: MobilitySession) -> some View {
        let position = min(session.currentEntryIndex + 1, session.entries.count)

        return Button {
            onResumeMobility(session)
        } label: {
            HStack(spacing: Spacing.m) {
                Rectangle()
                    .fill(Color.trameMobility)
                    .frame(width: 6, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("MOBILITY")
                        .font(AppFont.eyebrow)
                        .foregroundStyle(Color.trameMobility)

                    Text(session.nameSnapshot)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.s)

                Text("\(position) / \(session.entries.count)")
                    .font(AppFont.metricCompact)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameSubdued)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("resume-mobility-session")
        .accessibilityLabel("Active mobility: \(session.nameSnapshot), step \(position) of \(session.entries.count)")
    }

    private func dueMobilityProgramRow(_ due: (run: MobilityProgramRun, progress: MobilityProgramSessionProgress)) -> some View {
        Button(action: onOpenMobility) {
            HStack(spacing: Spacing.m) {
                Rectangle()
                    .fill(Color.trameMobility)
                    .frame(width: 6, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("MOBILITY PLAN")
                        .font(AppFont.eyebrow)
                        .foregroundStyle(Color.trameMobility)

                    Text(due.progress.sessionNameSnapshot)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.s)

                Text(due.run.sourceProgramName)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .lineLimit(1)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("today-open-mobility-plan-session")
        .accessibilityLabel("Due mobility: \(due.progress.sessionNameSnapshot), \(due.run.sourceProgramName)")
    }
}

/// Passive navigation shortcuts on Today, positioned below Week.
struct HomeQuickAccessSection: View {
    let onOpenExercises: () -> Void
    let onOpenMobility: () -> Void

    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        VStack(spacing: 0) {
            quickAccessRow(
                title: "Exercises",
                icon: AppIcon.exercise,
                color: Color.trameStrength,
                identifier: "today-open-exercises",
                hint: "Opens the exercise library in Train.",
                action: onOpenExercises
            )

            if featureFlags.isEnabled(.mobility) {
                quickAccessRow(
                    title: "Mobility",
                    icon: AppIcon.mobility,
                    color: Color.trameMobility,
                    identifier: "today-open-mobility",
                    hint: "Opens mobility routines in Train.",
                    action: onOpenMobility
                )
            }
        }
    }

    private func quickAccessRow(
        title: LocalizedStringKey,
        icon: String,
        color: Color,
        identifier: String,
        hint: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Rectangle()
                    .fill(color)
                    .frame(width: 4, height: 30)
                    .accessibilityHidden(true)

                Image(systemName: icon)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)
                    .frame(width: 26)
                    .accessibilityHidden(true)

                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.md)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}

/// Compatibility wrapper preserving HomeTodaySection naming for any other references.
struct HomeTodaySection: View {
    let onOpenExercises: () -> Void
    let onOpenMobility: () -> Void
    let onResumeMobility: (MobilitySession) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HomeActiveTrainingSupport(
                onOpenMobility: onOpenMobility,
                onResumeMobility: onResumeMobility
            )
            HomeQuickAccessSection(
                onOpenExercises: onOpenExercises,
                onOpenMobility: onOpenMobility
            )
        }
    }
}

enum TodayMobilityRowPolicy {
    static func shouldShowRow(hasActiveMobilitySession: Bool) -> Bool {
        hasActiveMobilitySession
    }
}

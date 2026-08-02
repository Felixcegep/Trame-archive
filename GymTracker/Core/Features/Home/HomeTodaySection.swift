import SwiftData
import SwiftUI

/// What sits under the workout card on Today: work already in progress, then
/// the two places a lifter goes next.
///
/// This used to be a six-row "Today's support" group covering mobility, a daily
/// check-in, nutrition totals, creatine, and caffeine. Five of those rows were
/// adjacent domains competing with training for the most valuable space in the
/// app, and the group read as the content of the screen rather than as the tier
/// below the session. Today is a training screen; food, supplements, and the
/// daily questionnaire live in their own destinations.
struct HomeTodaySection: View {
    let onOpenExercises: () -> Void
    let onOpenMobility: () -> Void
    let onResumeMobility: (MobilitySession) -> Void

    @Query(sort: \MobilitySession.updatedAt, order: .reverse) private var mobilitySessions: [MobilitySession]

    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let activeMobilitySession {
                resumeMobilityCard(activeMobilitySession)
            }

            // Passed pre-localized: `LibrarySectionTitle` takes a `String`, so a
            // bare literal would never reach the string catalog.
            LibrarySectionTitle(String(localized: "Quick access"))

            HStack(spacing: Spacing.m) {
                quickAccessTile(
                    title: "Exercises",
                    subtitle: "Browse the library",
                    icon: AppIcon.muscles,
                    tint: Color.gymPrimary,
                    surface: Color.gymPrimarySurface,
                    identifier: "today-open-exercises",
                    hint: "Opens the exercise library in Train.",
                    action: onOpenExercises
                )

                if featureFlags.isEnabled(.mobility) {
                    quickAccessTile(
                        title: "Stretch",
                        subtitle: "Mobility routines",
                        icon: AppIcon.mobility,
                        tint: Color.gymAccent,
                        surface: Color.gymAccentSurface,
                        identifier: "today-open-mobility",
                        hint: "Opens mobility routines in Train.",
                        action: onOpenMobility
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
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

    /// In-progress work outranks both tiles, so it is a full-width card above
    /// them rather than a third destination beside them.
    private func resumeMobilityCard(_ session: MobilitySession) -> some View {
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
                    Text("Stretch in progress")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                    Text(value)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubtleText)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(Color.gymCard)
                    .stroke(Color.gymAccent.opacity(0.24), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("resume-mobility-session")
        .accessibilityLabel("Stretch in progress, \(value)")
    }

    private func quickAccessTile(
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
            VStack(alignment: .leading, spacing: Spacing.s) {
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Both dimensions fill: `maxHeight` is what keeps two tiles with
            // differently wrapping subtitles the same height instead of
            // centre-aligned at two different sizes.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(Spacing.l - 2)
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
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

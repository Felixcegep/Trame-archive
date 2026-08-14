import SwiftData
import SwiftUI

/// Train's hero card: the plan you are following, and the controls for it.
///
/// Pausing or stopping used to require knowing the path Train → My Plans → the
/// plan → scroll. Those live here instead, in an in-content `Menu` rather than
/// a toolbar — toolbar buttons on pushed Library screens do not fire on iOS 26.
struct CurrentPlanCard: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]
    @Query(filter: #Predicate<RepeatingPlanRun> { $0.endedAt == nil }) private var repeatingPlanRuns: [RepeatingPlanRun]

    let onOpenPlan: (CurrentPlanSummary.Target) -> Void
    let onOpenProgramPath: (ProgramPathRoute) -> Void
    /// Weekly Review supports fixed-length `PlanRun` only, so this row appears
    /// solely when `openFixedRun` names the open run — a repeating rotation
    /// never gets this entry point.
    let onOpenWeeklyReview: (WeeklyProgramReviewRoute) -> Void
    let onChoosePlan: () -> Void
    /// Resuming can collide with another guided source, so it routes back to the
    /// root's conflict-aware handlers. Pausing and stopping only ever reduce the
    /// number of open runs, so they are applied here directly.
    let onResumePlan: (PlanRun) -> Void
    let onPauseRepeatingPlan: (RepeatingPlanRun) -> Void
    let onResumeRepeatingPlan: (RepeatingPlanRun) -> Void
    let onEndRepeatingPlan: (RepeatingPlanRun) -> Void

    @State private var isConfirmingStop = false
    @State private var actionError: String?

    private var summary: CurrentPlanSummary {
        CurrentPlanSummary.resolve(planRuns: planRuns, repeatingPlanRuns: repeatingPlanRuns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Current plan")
            card
        }
        .confirmationDialog(
            "Stop following this plan?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop Following", role: .destructive, action: stopFollowing)
                .accessibilityIdentifier("confirm-stop-following-plan")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your completed workouts stay in history. You can start the plan again later.")
        }
        .alert("Couldn’t update plan", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var card: some View {
        switch summary.kind {
        case .none:
            emptyCard
        case .ambiguous:
            ambiguousCard
        default:
            followingCard
        }
    }
}

// MARK: - States

private extension CurrentPlanCard {
    var emptyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(summary.title)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            Text(summary.detail)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onChoosePlan) {
                Text("Choose a plan")
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(.white)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.xl)
                    .background(Color.gymPrimary, in: Capsule())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("choose-a-plan")
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymPrimary.opacity(0.16), lineWidth: 1.5)
        }
        .accessibilityIdentifier("current-plan-empty")
    }

    var ambiguousCard: some View {
        Button(action: onChoosePlan) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Label(summary.title, systemImage: AppIcon.warning)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymDestructive)
                Text(summary.detail)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("current-plan-ambiguous")
    }

    var followingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if let target = summary.target { onOpenPlan(target) }
            } label: {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        Label(
                            summary.isPaused ? "PAUSED PLAN" : "CURRENT PLAN",
                            systemImage: summary.isPaused ? AppIcon.pause : AppIcon.plan
                        )
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(summary.isPaused ? Color.gymSubduedText : Color.gymPrimary)

                        Spacer()

                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.captionBold)
                            .foregroundStyle(Color.gymSubduedText)
                    }

                    Text(summary.title)
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(summary.detail)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .multilineTextAlignment(.leading)

                    if let fraction = summary.progressFraction,
                       let completed = summary.completedWorkouts,
                       let total = summary.totalWorkouts {
                        ProgressView(value: fraction)
                            .tint(Color.gymPrimary)
                            .padding(.top, Spacing.xxs)
                        Text("\(completed) of \(total) workouts")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .padding(Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("current-plan-card")
            .accessibilityHint("Opens the plan.")

            if let route = programPathRoute {
                Divider()
                    .overlay(Color.gymBorder)
                    .padding(.horizontal, Spacing.l)

                programPathLink(route)
            }

            if let run = openFixedRun {
                Divider()
                    .overlay(Color.gymBorder)
                    .padding(.horizontal, Spacing.l)

                weeklyReviewLink(for: run)
            }

            Divider()
                .overlay(Color.gymBorder)
                .padding(.horizontal, Spacing.l)

            actions
        }
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            // A paused plan reads as inert: plain border, no accent ring.
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(
                    summary.isPaused ? Color.gymBorder : Color.gymPrimary.opacity(0.16),
                    lineWidth: summary.isPaused ? 1 : 1.5
                )
        }
        // No shadow: fill plus border already separates this from the
        // background, and a third device is noise. See `HomePrimaryWorkoutCard`.
    }

    /// Where the run currently is, as its own destination. The card's main tap
    /// still opens the plan: the path answers "how far along am I", which is a
    /// different question from "what is this plan".
    func programPathLink(_ route: ProgramPathRoute) -> some View {
        Button {
            onOpenProgramPath(route)
        } label: {
            HStack(spacing: Spacing.s) {
                Label(ProgramPathPresentation.entryTitle, systemImage: AppIcon.routine)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("current-plan-program-path")
        .accessibilityHint(Text(ProgramPathPresentation.entryDetail))
    }

    /// Fixed-plan only, matching Weekly Review v1's product boundary.
    func weeklyReviewLink(for run: PlanRun) -> some View {
        Button {
            onOpenWeeklyReview(WeeklyProgramReviewRoute(runID: run.id))
        } label: {
            HStack(spacing: Spacing.s) {
                Label(WeeklyProgramReviewPresentation.entryTitle, systemImage: AppIcon.chart)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("current-plan-weekly-review")
        .accessibilityHint(Text(WeeklyProgramReviewPresentation.entryDetail))
    }

    /// `nil` when no single run is open, which is also when the card is showing
    /// its empty or ambiguous state and has no run to describe.
    var programPathRoute: ProgramPathRoute? {
        if let run = openFixedRun {
            return .fixedRun(run.id)
        }
        if let run = openRepeatingRun {
            return .rotationRun(run.id)
        }
        return nil
    }

    var actions: some View {
        HStack(spacing: Spacing.s) {
            if summary.isPaused {
                Button(action: resume) {
                    Label("Resume", systemImage: AppIcon.play)
                }
                .accessibilityIdentifier("current-plan-resume")
            } else {
                Button(action: pause) {
                    Label("Pause", systemImage: AppIcon.pause)
                }
                .accessibilityIdentifier("current-plan-pause")
            }

            Spacer(minLength: Spacing.s)

            Menu {
                Button("Change plan", action: onChoosePlan)
                Button("Stop following", role: .destructive) { isConfirmingStop = true }
            } label: {
                Label("More", systemImage: AppIcon.ellipsis)
            }
            .accessibilityIdentifier("current-plan-menu")
            .accessibilityLabel("Plan options")
        }
        .font(AppFont.subheadlineSemibold)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }
}

// MARK: - Actions

private extension CurrentPlanCard {
    var openFixedRun: PlanRun? {
        planRuns.first { CurrentPlanSummary.isOpen($0) }
    }

    var openRepeatingRun: RepeatingPlanRun? {
        repeatingPlanRuns.first { $0.status == .active || $0.status == .paused }
    }

    func pause() {
        if let run = openFixedRun {
            guard PlanCoordinator.pause(run, using: modelContext) else {
                actionError = String(localized: "The plan could not be paused. Try again.")
                return
            }
        } else if let run = openRepeatingRun {
            onPauseRepeatingPlan(run)
        }
    }

    func resume() {
        if let run = openFixedRun {
            onResumePlan(run)
        } else if let run = openRepeatingRun {
            onResumeRepeatingPlan(run)
        }
    }

    func stopFollowing() {
        if let run = openFixedRun {
            guard PlanCoordinator.archive(run, using: modelContext) else {
                actionError = String(localized: "The plan could not be stopped. Try again.")
                return
            }
        } else if let run = openRepeatingRun {
            onEndRepeatingPlan(run)
        }
    }
}

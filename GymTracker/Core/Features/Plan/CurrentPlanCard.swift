import SwiftData
import SwiftUI

/// Train's open following block: the plan being followed and its controls.
///
/// Pausing, switching, or stopping used to hide behind an unlabeled ellipsis.
/// Those actions live here in a labeled Manage menu, and a free workout start
/// stays visible so following a plan never blocks unplanned training.
struct CurrentPlanCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]
    @Query(filter: #Predicate<RepeatingPlanRun> { $0.endedAt == nil }) private var repeatingPlanRuns: [RepeatingPlanRun]

    let onOpenPlan: (CurrentPlanSummary.Target) -> Void
    let onOpenProgramPath: (ProgramPathRoute) -> Void
    /// Weekly Review supports fixed-length `PlanRun` only, so this row appears
    /// solely when `openFixedRun` names the open run — a repeating rotation
    /// never gets this entry point.
    let onOpenWeeklyReview: (WeeklyProgramReviewRoute) -> Void
    let onChoosePlan: () -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartRepeatingWorkout: (RepeatingPlanRun) -> Void
    /// A free session is independent of the open run. Train keeps this path
    /// visible while a plan or rotation is followed, so structure never blocks
    /// logging unplanned work.
    let onStartFreeWorkout: () -> Void
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

    @ViewBuilder
    var body: some View {
        switch summary.kind {
        case .none:
            noPlanState
        case .ambiguous:
            VStack(alignment: .leading, spacing: Spacing.md) {
                TrameDomainSectionRule(title: "Active Plan", color: Color.trameAttention)
                ambiguousCard
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
        default:
            followingCard
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
    }
}

// MARK: - States

private extension CurrentPlanCard {
    var noPlanState: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            TrameDomainSectionRule(title: "FOLLOWING", color: Color.trameStrength)

            Button(action: onChoosePlan) {
                HStack(alignment: .center, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("No plan followed")
                            .font(AppFont.sectionTitle)
                            .foregroundStyle(Color.trameText)

                        Text("Browse ready-made plans or build your own.")
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.s)

                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityLabel("No plan followed. Browse plans")
            .accessibilityHint("Opens ready-made and custom training plans.")
            .accessibilityIdentifier("choose-plan-empty-state")
        }
    }

    var ambiguousCard: some View {
        Button(action: onChoosePlan) {
            HStack(spacing: Spacing.m) {
                Rectangle()
                    .fill(Color.trameAttention)
                    .frame(width: 6, height: 48)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("NEEDS ATTENTION")
                        .font(AppFont.eyebrow)
                        .tracking(0.8)
                        .foregroundStyle(Color.trameText)

                    Text(summary.title)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("current-plan-ambiguous")
    }

    var followingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrameDomainSectionRule(title: "FOLLOWING", color: Color.trameStrength)
                .padding(.bottom, Spacing.m)

            planField

            if primaryTrainingActionIsAvailable {
                Divider()
                    .overlay(Color.trameSeparator)

                primaryTrainingAction
                    .padding(.vertical, Spacing.l)
            }

            if showsFreeWorkoutStart {
                Divider()
                    .overlay(Color.trameSeparator)

                freeWorkoutStart
            }

            Divider()
                .overlay(Color.trameSeparator)

            planTools
                .padding(.vertical, Spacing.s)
        }
    }

    var planField: some View {
        Button {
            if let target = summary.target {
                onOpenPlan(target)
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if summary.isPaused {
                    Text("PAUSED")
                        .font(AppFont.eyebrow)
                        .tracking(1)
                        .foregroundStyle(Color.trameSubdued)
                }

                HStack(alignment: .top, spacing: Spacing.s) {
                    Text(summary.title)
                        .font(AppFont.stageTitle)
                        .foregroundStyle(Color.trameText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer(minLength: Spacing.s)

                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                        .padding(.top, Spacing.xs)
                }

                if let next = summary.nextWorkoutName {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("NEXT SESSION")
                            .font(AppFont.micro)
                            .tracking(1)
                            .foregroundStyle(Color.trameSubdued)

                        Text(next)
                            .font(AppFont.metricLarge)
                            .foregroundStyle(Color.trameText)
                            .multilineTextAlignment(.leading)
                    }
                }

                planProgress
            }
            .padding(.leading, Spacing.l)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(summary.isPaused ? Color.trameSeparator : Color.trameStrength)
                    .frame(width: 6)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("current-plan-card")
        .accessibilityHint("Opens the plan.")
    }

    var planProgress: some View {
        VStack(spacing: Spacing.s) {
            HStack {
                if let position = summary.positionText {
                    Text(compactPosition(position))
                        .font(AppFont.eyebrow)
                        .foregroundStyle(Color.trameSubdued)
                }

                Spacer()

                if let completed = summary.completedWorkouts,
                   let total = summary.totalWorkouts {
                    Text("\(completed) / \(total)")
                        .font(AppFont.metricCompact)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameText)
                }
            }

            if let fraction = summary.progressFraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.trameSeparator)

                        Rectangle()
                            .fill(Color.trameStrength)
                            .frame(width: max(0, proxy.size.width * CGFloat(fraction)))
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }
        }
    }

    var planTools: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    if let route = programPathRoute {
                        pathButton(route)
                    }
                    if let run = openFixedRun {
                        weeklyReviewButton(run)
                    }
                    planMenu
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: Spacing.xl) {
                    if let route = programPathRoute {
                        pathButton(route)
                    }
                    if let run = openFixedRun {
                        weeklyReviewButton(run)
                    }
                    Spacer(minLength: Spacing.s)
                    planMenu
                }
            }
        }
        .font(AppFont.metadata)
        .foregroundStyle(Color.trameText)
    }

    func pathButton(_ route: ProgramPathRoute) -> some View {
        Button("Path") {
            onOpenProgramPath(route)
        }
        .buttonStyle(.plain)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .accessibilityLabel("Open program path")
        .accessibilityIdentifier("current-plan-program-path")
    }

    func weeklyReviewButton(_ run: PlanRun) -> some View {
        Button("This week") {
            onOpenWeeklyReview(WeeklyProgramReviewRoute(runID: run.id))
        }
        .buttonStyle(.plain)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .accessibilityLabel("Open weekly review")
        .accessibilityIdentifier("current-plan-weekly-review")
    }

    var planMenu: some View {
        Menu {
            Section {
                if !summary.isPaused {
                    Button(action: pause) {
                        Label(pauseMenuTitle, systemImage: AppIcon.pause)
                    }
                    .accessibilityIdentifier("current-plan-pause")
                }

                Button(action: onChoosePlan) {
                    Label("Change plan", systemImage: AppIcon.plan)
                }
                .accessibilityIdentifier("current-plan-change")
            }

            Section {
                Button("Stop following", role: .destructive) {
                    isConfirmingStop = true
                }
                .accessibilityIdentifier("current-plan-stop")
            }
        } label: {
            Text("Manage")
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .padding(.horizontal, Spacing.s)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("current-plan-menu")
        .accessibilityLabel("Manage plan")
        .accessibilityHint("Pause, change, or stop following this plan.")
    }

    var pauseMenuTitle: LocalizedStringKey {
        switch summary.kind {
        case .followingRepeating, .pausedRepeating:
            "Pause Rotation"
        default:
            "Pause plan"
        }
    }

    var showsFreeWorkoutStart: Bool {
        switch summary.kind {
        case .followingFixed, .followingRepeating, .pausedFixed, .pausedRepeating:
            true
        case .none, .ambiguous:
            false
        }
    }

    var freeWorkoutStart: some View {
        Button(action: onStartFreeWorkout) {
            HStack(spacing: Spacing.m) {
                Text("Start a free workout")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityHint("Starts an empty workout without changing this plan.")
        .accessibilityIdentifier("current-plan-start-free")
    }

    func compactPosition(_ position: String) -> String {
        if position.lowercased().hasPrefix("week ") {
            let number = position.dropFirst(5)
            return "W\(number)"
        } else if position.lowercased().hasPrefix("cycle ") {
            let number = position.dropFirst(6)
            return "C\(number)"
        }
        return position
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

    var primaryTrainingActionIsAvailable: Bool {
        summary.isPaused
            || (openFixedRun.flatMap { PlanCoordinator.nextProgress(in: $0) } != nil)
            || openRepeatingRun?.status == .active
    }

    @ViewBuilder
    var primaryTrainingAction: some View {
        if summary.isPaused {
            Button(action: resume) {
                Text("Resume plan")
                    .font(AppFont.titleSmallSemibold)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.todayActionHeight)
            }
            .buttonStyle(.tramePrimaryAction)
            .accessibilityIdentifier("current-plan-resume")
        } else if let run = openFixedRun, let next = PlanCoordinator.nextProgress(in: run) {
            Button {
                onStartPlannedWorkout(run, next)
            } label: {
                Text("Start session")
                    .font(AppFont.titleSmallSemibold)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.todayActionHeight)
            }
            .buttonStyle(.tramePrimaryAction)
            .accessibilityLabel("Start \(next.plannedWorkoutName)")
            .accessibilityIdentifier("current-plan-start-next")
        } else if let run = openRepeatingRun, run.status == .active {
            Button {
                onStartRepeatingWorkout(run)
            } label: {
                Text("Start session")
                    .font(AppFont.titleSmallSemibold)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.todayActionHeight)
            }
            .buttonStyle(.tramePrimaryAction)
            .accessibilityLabel(summary.nextWorkoutName.map { "Start \($0)" } ?? "Start next rotation workout")
            .accessibilityIdentifier("current-plan-start-next")
        }
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

import SwiftData
import SwiftUI

/// The Plan Path screen: where you are in the plan you are following, what it
/// is asking for next, and everything it has already recorded.
///
/// The route carries only a run identifier. The run and its projection are
/// resolved at presentation time, so a navigation stack restored after a pause,
/// a completion, or a backup restore never renders stale run state.
///
/// Workout starts are handed back to the root, which owns the conflict-aware
/// guarded transitions. Rescheduling and in-stack navigation stay local, the
/// same way `PlanDetailView` and `PlanCalendarView` already handle them.
struct ProgramPathView: View {
    @Environment(\.modelContext) private var modelContext

    let route: ProgramPathRoute
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onResumeActiveWorkout: () -> Void

    @Query private var planRuns: [PlanRun]
    @Query private var repeatingPlanRuns: [RepeatingPlanRun]

    @State private var reschedulingProgress: PlanWorkoutProgress?

    var body: some View {
        content
            .navigationTitle(ProgramPathPresentation.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $reschedulingProgress) { progress in
                PlanRescheduleSheet(
                    workoutName: progress.plannedWorkoutName,
                    initialDate: progress.scheduledDate,
                    confirmIdentifier: "program-path-confirm-reschedule"
                ) { date in
                    guard let run = fixedRun else { return false }
                    return PlanCoordinator.reschedule(
                        progress,
                        to: date,
                        in: run,
                        using: modelContext
                    )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let run = fixedRun {
            fixedPath(run: run, projection: FixedProgramPathBuilder.build(for: run))
        } else if let run = rotationRun {
            rotationPath(run: run, projection: RotationProgramPathBuilder.build(run: run))
        } else {
            ProgramPathUnavailableView()
        }
    }

    private var fixedRun: PlanRun? {
        guard case .fixedRun(let runID) = route else { return nil }
        return planRuns.first { $0.id == runID }
    }

    private var rotationRun: RepeatingPlanRun? {
        guard case .rotationRun(let runID) = route else { return nil }
        return repeatingPlanRuns.first { $0.id == runID }
    }
}

// MARK: - Fixed plan

private extension ProgramPathView {
    func fixedPath(run: PlanRun, projection: FixedProgramPathProjection) -> some View {
        List {
            Section {
                ProgramPathHeader(
                    title: projection.title,
                    statusTitle: ProgramPathPresentation.runStatusTitle(projection.status),
                    isMuted: projection.status != .active,
                    positionLines: fixedPositionLines(projection.position),
                    progressFraction: projection.progress.fraction,
                    progressSummary: ProgramPathPresentation.progressSummary(projection.progress)
                )
            }

            if let session = currentSession(in: projection) {
                Section {
                    ProgramPathCurrentSession(
                        eyebrow: session.displayState == .inProgress ? "In progress" : "Up next",
                        workoutName: session.workoutName,
                        detailLines: currentSessionDetails(session),
                        stateStyle: ProgramPathPresentation.style(for: session.displayState),
                        primaryAction: fixedPrimaryAction(run: run, projection: projection)
                    )
                } footer: {
                    if projection.status == .paused {
                        Text("Resume this plan to start this session.")
                    } else if projection.status == .testDayAvailable {
                        Text("A test day is ready. Start it from the plan screen.")
                    }
                }
            }

            // Deload sits directly under the current session: it qualifies the
            // workout the user is about to start, so it must not be separated
            // from it by the rarer warning list.
            if let deload = projection.currentDeload ?? projection.upcomingDeload {
                Section {
                    ProgramPathDeloadView(
                        title: projection.currentDeload != nil
                            ? ProgramPathPresentation.currentDeloadTitle()
                            : ProgramPathPresentation.upcomingDeloadTitle(deload),
                        detail: ProgramPathPresentation.deloadReductions(deload.block)
                    )
                }
            }

            if !projection.warnings.isEmpty {
                Section("Needs attention") {
                    ProgramPathWarningView(
                        messages: projection.warnings.map { ProgramPathPresentation.warningMessage($0) }
                    )
                }
            }

            Section {
                NavigationLink {
                    PlanCalendarView(run: run)
                } label: {
                    ProgramPathLinkLabel(
                        title: "Open schedule",
                        systemImage: AppIcon.plan,
                        detail: String(localized: "Move sessions and see them by date.")
                    )
                }
                .accessibilityIdentifier("program-path-open-schedule")
            }

            FixedProgramPathTimeline(projection: projection) { session in
                beginReschedule(session, in: run)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("program-path-fixed-screen", label: "Plan path fixed")
        }
    }

    func fixedPositionLines(_ position: FixedProgramPathProjection.Position) -> [String] {
        [
            ProgramPathPresentation.blockPosition(position),
            ProgramPathPresentation.weekPosition(position),
            ProgramPathPresentation.sessionPosition(position)
        ].compactMap { $0 }
    }

    func currentSession(
        in projection: FixedProgramPathProjection
    ) -> FixedProgramPathProjection.Session? {
        guard let currentSessionID = projection.currentSessionID else { return nil }
        return projection.weeks
            .flatMap(\.sessions)
            .first { $0.id == currentSessionID }
    }

    func currentSessionDetails(
        _ session: FixedProgramPathProjection.Session
    ) -> [String] {
        var lines = [ProgramPathPresentation.scheduledDateTitle(session.scheduledDate)]
        if let rescheduled = ProgramPathPresentation.rescheduledDetail(session) {
            lines.append(rescheduled)
        }
        return lines
    }

    /// Only an active run offers a start. Paused and test-day runs keep their
    /// existing owners — the plan screen and the current-plan card — rather
    /// than growing a second way to change a run's lifecycle from here.
    func fixedPrimaryAction(
        run: PlanRun,
        projection: FixedProgramPathProjection
    ) -> ProgramPathCurrentSession.PrimaryAction? {
        guard projection.status == .active, let action = projection.primaryAction else {
            return nil
        }

        switch action {
        case .startFixedWorkout(_, let progressID):
            guard let progress = run.orderedWorkoutProgress.first(where: { $0.id == progressID }) else {
                return nil
            }
            let isResuming = progress.status == .inProgress
            return .init(
                title: isResuming
                    ? String(localized: "Resume workout")
                    : String(localized: "Start \(progress.plannedWorkoutName)"),
                systemImage: isResuming ? AppIcon.workout : AppIcon.play,
                identifier: "program-path-start-workout",
                hint: isResuming
                    ? String(localized: "Returns to the workout already in progress.")
                    : String(localized: "Starts this session of your plan."),
                perform: { onStartPlannedWorkout(run, progress) }
            )

        case .resumeWorkout:
            return .init(
                title: String(localized: "Resume workout"),
                systemImage: AppIcon.workout,
                identifier: "program-path-resume-workout",
                hint: String(localized: "Returns to the workout already in progress."),
                perform: onResumeActiveWorkout
            )

        case .rescheduleFixedWorkout, .openCompletedWorkout, .openFixedSchedule,
             .startExpectedRotationWorkout:
            return nil
        }
    }

    func beginReschedule(_ session: FixedProgramPathProjection.Session, in run: PlanRun) {
        guard let progress = run.orderedWorkoutProgress.first(where: { $0.id == session.id }),
              PlanCoordinator.canEditSchedule(progress, in: run)
        else {
            return
        }
        reschedulingProgress = progress
    }
}

// MARK: - Rotation

private extension ProgramPathView {
    func rotationPath(
        run: RepeatingPlanRun,
        projection: RotationProgramPathProjection
    ) -> some View {
        List {
            Section {
                ProgramPathHeader(
                    title: projection.title,
                    statusTitle: ProgramPathPresentation.rotationStatusTitle(projection.runStatus),
                    isMuted: projection.runStatus != .active,
                    positionLines: [ProgramPathPresentation.rotationPosition(projection)]
                )
            }

            if let nextWorkout = projection.nextWorkout {
                Section {
                    ProgramPathCurrentSession(
                        eyebrow: "Up next",
                        workoutName: nextWorkout.workoutName,
                        detailLines: [ProgramPathPresentation.slotTitle(nextWorkout.slotIndex)],
                        stateStyle: nil,
                        primaryAction: rotationPrimaryAction(run: run, projection: projection)
                    )
                } footer: {
                    if !nextWorkout.isTemplateAvailable {
                        Text("This rotation position no longer has an available workout. Correct the rotation before starting.")
                    } else if projection.runStatus == .paused {
                        Text("Resume this rotation to start the next workout.")
                    }
                }
            }

            if projection.hasWarnings {
                Section("Needs attention") {
                    ProgramPathWarningView(
                        messages: projection.warnings.map { ProgramPathPresentation.warningMessage($0) }
                    )
                }
            }

            RotationProgramPathTimeline(projection: projection)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("program-path-rotation-screen", label: "Plan path rotation")
        }
    }

    func rotationPrimaryAction(
        run: RepeatingPlanRun,
        projection: RotationProgramPathProjection
    ) -> ProgramPathCurrentSession.PrimaryAction? {
        guard case .startExpectedRotationWorkout? = projection.primaryAction else { return nil }
        return .init(
            title: String(localized: "Start next workout"),
            systemImage: AppIcon.play,
            identifier: "program-path-start-rotation-workout",
            hint: String(localized: "Starts the expected workout in your rotation."),
            perform: { onStartRepeatingWorkout(run) }
        )
    }
}

// MARK: - Completed workout

/// Resolves a completed workout by identity so the path can push History
/// without carrying a model object through navigation state.
struct ProgramPathCompletedWorkoutDestination: View {
    let workoutID: UUID

    @Query private var workouts: [Workout]

    init(workoutID: UUID) {
        self.workoutID = workoutID
        _workouts = Query(
            filter: #Predicate<Workout> { $0.id == workoutID },
            sort: \.startTime
        )
    }

    var body: some View {
        if let workout = workouts.first {
            HistoryWorkoutView(workout: workout)
        } else {
            ContentUnavailableView(
                "Workout unavailable",
                systemImage: AppIcon.warning,
                description: Text("This workout may have been removed from History.")
            )
            .accessibilityIdentifier("program-path-workout-unavailable")
        }
    }
}

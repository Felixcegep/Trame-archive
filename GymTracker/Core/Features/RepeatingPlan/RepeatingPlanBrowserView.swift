import SwiftData
import SwiftUI

struct RepeatingPlanBrowserView: View {
    @Query private var plans: [RepeatingPlan]

    let onStartRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onActivateRepeatingPlan: (RepeatingPlan) -> Void
    let onPauseRepeatingPlan: (RepeatingPlanRun) -> Void
    let onResumeRepeatingPlan: (RepeatingPlanRun) -> Void
    let onStartAlternateRepeatingWorkout: (RepeatingPlanRun, Int, RepeatingPlanContinuationMode) -> Void
    let onRepeatRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onSkipRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onUndoRepeatingPlanAdvancement: (RepeatingPlanRun) -> Void
    let onRestartRepeatingPlan: (RepeatingPlanRun) -> Void
    let onEndRepeatingPlan: (RepeatingPlanRun) -> Void

    var body: some View {
        List {
            if activePlans.isEmpty && archivedPlans.isEmpty {
                ContentUnavailableView {
                    Label("No rotations yet", systemImage: AppIcon.routine)
                } description: {
                    Text("A rotation repeats your workouts in order, so you can always start the next session.")
                }
            } else {
                Section("Rotations") {
                    ForEach(activePlans) { plan in
                        NavigationLink {
                            RepeatingPlanDetailView(
                                plan: plan,
                                onStartRepeatingWorkout: onStartRepeatingWorkout,
                                onActivateRepeatingPlan: onActivateRepeatingPlan,
                                onPauseRepeatingPlan: onPauseRepeatingPlan,
                                onResumeRepeatingPlan: onResumeRepeatingPlan,
                                onStartAlternateRepeatingWorkout: onStartAlternateRepeatingWorkout,
                                onRepeatRepeatingWorkout: onRepeatRepeatingWorkout,
                                onSkipRepeatingWorkout: onSkipRepeatingWorkout,
                                onUndoRepeatingPlanAdvancement: onUndoRepeatingPlanAdvancement,
                                onRestartRepeatingPlan: onRestartRepeatingPlan,
                                onEndRepeatingPlan: onEndRepeatingPlan
                            )
                        } label: {
                            planRow(plan)
                        }
                        .accessibilityIdentifier("repeating-plan-row-\(plan.id)")
                    }
                }

                if !archivedPlans.isEmpty {
                    Section("Archived") {
                        ForEach(archivedPlans) { plan in
                            NavigationLink {
                                RepeatingPlanDetailView(
                                    plan: plan,
                                    onStartRepeatingWorkout: onStartRepeatingWorkout,
                                    onActivateRepeatingPlan: onActivateRepeatingPlan,
                                    onPauseRepeatingPlan: onPauseRepeatingPlan,
                                    onResumeRepeatingPlan: onResumeRepeatingPlan,
                                    onStartAlternateRepeatingWorkout: onStartAlternateRepeatingWorkout,
                                    onRepeatRepeatingWorkout: onRepeatRepeatingWorkout,
                                    onSkipRepeatingWorkout: onSkipRepeatingWorkout,
                                    onUndoRepeatingPlanAdvancement: onUndoRepeatingPlanAdvancement,
                                    onRestartRepeatingPlan: onRestartRepeatingPlan,
                                    onEndRepeatingPlan: onEndRepeatingPlan
                                )
                            } label: {
                                planRow(plan)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Rotations")
    }

    private var activePlans: [RepeatingPlan] {
        plans
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isBuiltIn != rhs.isBuiltIn {
                    return lhs.isBuiltIn
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private var archivedPlans: [RepeatingPlan] {
        plans
            .filter(\.isArchived)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func planRow(_ plan: RepeatingPlan) -> some View {
        let run = currentRun(for: plan)
        return HStack(spacing: Spacing.m) {
            GymIconChip(systemImage: AppIcon.routine, tint: Color.gymPrimary)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(plan.name)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text(RepeatingPlanPresentation.rotationSummary(
                    slotCount: run?.orderedSlots.count ?? plan.orderedSlots.count
                ))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer(minLength: Spacing.s)
            if let run {
                runBadge(run.status)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(planRowAccessibilityLabel(plan, run: run))
    }

    private func currentRun(for plan: RepeatingPlan) -> RepeatingPlanRun? {
        let openRuns = plan.runs
            .filter { $0.status == .active || $0.status == .paused }
            .sorted { $0.updatedAt > $1.updatedAt }
        return openRuns.count == 1 ? openRuns[0] : nil
    }

    @ViewBuilder
    private func runBadge(_ status: RepeatingPlanRunStatus) -> some View {
        switch status {
        case .active:
            GymStatusBadge(
                title: RepeatingPlanPresentation.runStatusTitle(status),
                systemImage: AppIcon.play,
                tint: Color.gymPrimary
            )
        case .paused:
            GymStatusBadge(
                title: RepeatingPlanPresentation.runStatusTitle(status),
                systemImage: AppIcon.pause,
                tint: Color.gymSubduedText
            )
        case .ended, .archived:
            EmptyView()
        }
    }

    private func planRowAccessibilityLabel(_ plan: RepeatingPlan, run: RepeatingPlanRun?) -> String {
        let summary = RepeatingPlanPresentation.rotationSummary(
            slotCount: run?.orderedSlots.count ?? plan.orderedSlots.count
        )
        let status = run.map { ", \(RepeatingPlanPresentation.runStatusTitle($0.status))" } ?? ""
        let archiveStatus = plan.isArchived ? ", \(String(localized: "Archived"))" : ""
        return String(localized: "\(plan.name), \(summary)\(status)\(archiveStatus)")
    }
}

struct RepeatingPlanDetailView: View {
    let plan: RepeatingPlan
    let onStartRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onActivateRepeatingPlan: (RepeatingPlan) -> Void
    let onPauseRepeatingPlan: (RepeatingPlanRun) -> Void
    let onResumeRepeatingPlan: (RepeatingPlanRun) -> Void
    let onStartAlternateRepeatingWorkout: (RepeatingPlanRun, Int, RepeatingPlanContinuationMode) -> Void
    let onRepeatRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onSkipRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onUndoRepeatingPlanAdvancement: (RepeatingPlanRun) -> Void
    let onRestartRepeatingPlan: (RepeatingPlanRun) -> Void
    let onEndRepeatingPlan: (RepeatingPlanRun) -> Void

    @State private var isShowingAlternatePicker = false
    @State private var selectedAlternate: AlternateSelection?
    @State private var isShowingAlternateContinuationChoice = false
    @State private var pendingDestructiveAction: DestructiveAction?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(RepeatingPlanPresentation.goalTitle(plan.goal))
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    Text("\(RepeatingPlanPresentation.experienceTitle(plan.experienceLevel)) · \(RepeatingPlanPresentation.rotationSummary(slotCount: rotationSlotCount))")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                    if let notes = plan.notes, !notes.isEmpty {
                        Text(notes)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }

            Section("Rotation") {
                if let run = currentRun {
                    ForEach(Array(run.orderedSlots.enumerated()), id: \.element.id) { index, slot in
                        runSlotRow(slot, index: index, currentSlotIndex: run.currentSlotIndex)
                    }
                } else {
                    ForEach(Array(plan.orderedSlots.enumerated()), id: \.element.id) { index, slot in
                        planSlotRow(slot, index: index)
                    }
                }
            }

            if hasAmbiguousOpenRuns {
                Section("Rotation needs attention") {
                    Text("More than one active or paused rotation was found. Resolve the duplicate runs before changing this rotation.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityLabel(String(localized: "Rotation unavailable. More than one active or paused rotation was found. Resolve the duplicate runs before changing this rotation."))
                }
            } else if let run = currentRun {
                currentRunSections(run)
            } else if !plan.isArchived {
                Section {
                    Button {
                        onActivateRepeatingPlan(plan)
                    } label: {
                        Label("Activate Rotation", systemImage: AppIcon.play)
                    }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("activate-repeating-plan")
                    .disabled(!plan.validationIssues.isEmpty)
                    .accessibilityHint(activationAccessibilityHint)
                } footer: {
                    if !plan.validationIssues.isEmpty {
                        Text("This rotation needs an available workout in every position before it can start.")
                    } else {
                        Text("The app will ask before switching from another active guided plan.")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingAlternatePicker, onDismiss: presentAlternateContinuationChoice) {
            if let run = currentRun {
                NavigationStack {
                    List {
                        Section("Choose another workout") {
                            ForEach(
                                Array(run.orderedSlots.enumerated()).filter { $0.offset != run.currentSlotIndex },
                                id: \.element.id
                            ) { index, slot in
                                Button {
                                    selectedAlternate = AlternateSelection(
                                        slotIndex: index,
                                        templateName: slot.templateNameSnapshot
                                    )
                                    isShowingAlternatePicker = false
                                } label: {
                                    HStack(spacing: Spacing.m) {
                                        GymIconChip(systemImage: AppIcon.routine, tint: Color.gymAccent)
                                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                                            Text(slot.templateNameSnapshot)
                                                .font(AppFont.subheadlineSemibold)
                                                .foregroundStyle(Color.gymText)
                                            Text("Workout \(index + 1)")
                                                .font(AppFont.caption)
                                                .foregroundStyle(Color.gymSubduedText)
                                        }
                                        Spacer(minLength: Spacing.s)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.gymBackground)
                    .navigationTitle("Choose Workout")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isShowingAlternatePicker = false }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "How should the rotation continue?",
            isPresented: $isShowingAlternateContinuationChoice,
            titleVisibility: .visible
        ) {
            if let run = currentRun, let selectedAlternate {
                Button(RepeatingPlanPresentation.alternateContinuationTitle(.keepExpected)) {
                    startAlternate(run, selection: selectedAlternate, mode: .keepExpected)
                }
                Button(RepeatingPlanPresentation.alternateContinuationTitle(.continueAfterSelected)) {
                    startAlternate(run, selection: selectedAlternate, mode: .continueAfterSelected)
                }
            }
            Button("Cancel", role: .cancel) { selectedAlternate = nil }
        } message: {
            if let selectedAlternate {
                Text(RepeatingPlanPresentation.alternateContinuationPrompt(workoutName: selectedAlternate.templateName))
            }
        }
        .confirmationDialog(
            pendingDestructiveAction?.title ?? "",
            isPresented: Binding(
                get: { pendingDestructiveAction != nil },
                set: { if !$0 { pendingDestructiveAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingDestructiveAction, let run = currentRun {
                Button(action.confirmationTitle, role: .destructive) {
                    pendingDestructiveAction = nil
                    switch action {
                    case .restart:
                        onRestartRepeatingPlan(run)
                    case .end:
                        onEndRepeatingPlan(run)
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingDestructiveAction = nil }
        } message: {
            if let action = pendingDestructiveAction {
                Text(action.message)
            }
        }
    }

    @ViewBuilder
    private func currentRunSections(_ run: RepeatingPlanRun) -> some View {
        Section("Current position") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(RepeatingPlanPresentation.cycleSummary(
                    currentSlotIndex: run.currentSlotIndex,
                    slotCount: run.orderedSlots.count,
                    completedCycleCount: run.completedCycleCount
                ))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)

                if let nextSlot = nextSlot(in: run) {
                    Text("Next: \(nextSlot.templateNameSnapshot)")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }

            runStatusRow(run)
        }

        if run.status == .active {
            Section {
                Button {
                    onStartRepeatingWorkout(run)
                } label: {
                    Label("Start Next Workout", systemImage: AppIcon.play)
                }
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier("start-repeating-plan-workout")
                .disabled(nextWorkoutIsUnavailable(in: run))
                .accessibilityHint(startNextWorkoutAccessibilityHint(for: run))
            } footer: {
                Text(startNextWorkoutFooter(for: run))
            }

            Section("Rotation controls") {
                Button {
                    onPauseRepeatingPlan(run)
                } label: {
                    Label("Pause Rotation", systemImage: AppIcon.pause)
                }
                .accessibilityIdentifier("pause-repeating-plan")

                rotationMenu(run)
            }
        } else if run.status == .paused {
            Section {
                Button {
                    onResumeRepeatingPlan(run)
                } label: {
                    Label("Resume Rotation", systemImage: AppIcon.play)
                }
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier("resume-repeating-plan")
            } footer: {
                Text("The app will ask before changing an active guided plan.")
            }

            Section("Rotation controls") {
                rotationMenu(run)
            }
        }
    }

    private var currentRun: RepeatingPlanRun? {
        let openRuns = plan.runs
            .filter { $0.status == .active || $0.status == .paused }
            .sorted { $0.updatedAt > $1.updatedAt }
        return openRuns.count == 1 ? openRuns[0] : nil
    }

    private var hasAmbiguousOpenRuns: Bool {
        plan.runs.filter { $0.status == .active || $0.status == .paused }.count > 1
    }

    private var rotationSlotCount: Int {
        currentRun?.orderedSlots.count ?? plan.orderedSlots.count
    }

    private func nextSlot(in run: RepeatingPlanRun) -> RepeatingPlanRunSlot? {
        guard run.orderedSlots.indices.contains(run.currentSlotIndex) else { return nil }
        return run.orderedSlots[run.currentSlotIndex]
    }

    private var activationAccessibilityHint: String {
        if plan.validationIssues.isEmpty {
            return String(localized: "Activates this rotation and may ask before switching from another active guided plan.")
        }
        return String(localized: "Unavailable until every rotation position has an available workout.")
    }

    private func nextWorkoutIsUnavailable(in run: RepeatingPlanRun) -> Bool {
        nextSlot(in: run)?.workoutTemplate == nil
    }

    private func startNextWorkoutAccessibilityHint(for run: RepeatingPlanRun) -> String {
        if nextWorkoutIsUnavailable(in: run) {
            return String(localized: "Unavailable because the next rotation position no longer has an available workout.")
        }
        return String(localized: "Starts the next workout in your active rotation.")
    }

    private func startNextWorkoutFooter(for run: RepeatingPlanRun) -> String {
        if nextWorkoutIsUnavailable(in: run) {
            return String(localized: "The next rotation position no longer has an available workout. Choose another rotation or correct this rotation before starting.")
        }
        return String(localized: "The app will ask before changing an active guided plan.")
    }

    private func presentAlternateContinuationChoice() {
        guard selectedAlternate != nil else { return }
        isShowingAlternateContinuationChoice = true
    }

    private func startAlternate(
        _ run: RepeatingPlanRun,
        selection: AlternateSelection,
        mode: RepeatingPlanContinuationMode
    ) {
        selectedAlternate = nil
        onStartAlternateRepeatingWorkout(run, selection.slotIndex, mode)
    }

    private func rotationMenu(_ run: RepeatingPlanRun) -> some View {
        Menu {
            Button {
                selectedAlternate = nil
                isShowingAlternatePicker = true
            } label: {
                Label("Choose Another Workout", systemImage: AppIcon.routine)
            }
            .disabled(!canChooseAnotherWorkout(in: run))

            Button {
                onRepeatRepeatingWorkout(run)
            } label: {
                Label("Repeat Last Workout", systemImage: AppIcon.reset)
            }
            .disabled(!canRepeatLastWorkout(in: run) || !canAdvance(in: run))

            Button {
                onSkipRepeatingWorkout(run)
            } label: {
                Label("Skip This Workout", systemImage: AppIcon.skip)
            }
            .disabled(!canAdvance(in: run))

            Button {
                onUndoRepeatingPlanAdvancement(run)
            } label: {
                Label("Undo Last Advancement", systemImage: AppIcon.restore)
            }

            Divider()

            Button(role: .destructive) {
                pendingDestructiveAction = .restart
            } label: {
                Label("Restart Rotation", systemImage: AppIcon.reset)
            }
            .disabled(hasInProgressOccurrence(in: run))

            Button(role: .destructive) {
                pendingDestructiveAction = .end
            } label: {
                Label("End Plan", systemImage: AppIcon.stop)
            }
            .disabled(hasInProgressOccurrence(in: run))
        } label: {
            Label("More Rotation Actions", systemImage: AppIcon.ellipsis)
        }
        .accessibilityIdentifier("repeating-plan-more-actions")
    }

    private func hasInProgressOccurrence(in run: RepeatingPlanRun) -> Bool {
        run.occurrences.contains { $0.status == .inProgress }
    }

    private func canAdvance(in run: RepeatingPlanRun) -> Bool {
        run.status == .active && !hasInProgressOccurrence(in: run)
    }

    private func canChooseAnotherWorkout(in run: RepeatingPlanRun) -> Bool {
        canAdvance(in: run) && run.orderedSlots.count > 1
    }

    private func canRepeatLastWorkout(in run: RepeatingPlanRun) -> Bool {
        run.occurrences.contains {
            $0.status == .completed && $0.kind != .skip
        }
    }

    private func runSlotRow(
        _ slot: RepeatingPlanRunSlot,
        index: Int,
        currentSlotIndex: Int
    ) -> some View {
        rotationSlotRow(
            templateName: slot.templateNameSnapshot,
            index: index,
            isCurrent: currentSlotIndex == index
        )
    }

    private func planSlotRow(_ slot: RepeatingPlanSlot, index: Int) -> some View {
        rotationSlotRow(
            templateName: slot.templateNameSnapshot,
            index: index,
            isCurrent: false
        )
    }

    private func rotationSlotRow(
        templateName: String,
        index: Int,
        isCurrent: Bool
    ) -> some View {
        HStack(spacing: Spacing.m) {
            GymIconChip(systemImage: AppIcon.routine, tint: Color.gymAccent)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(templateName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text("Workout \(index + 1)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer(minLength: Spacing.s)
            if isCurrent {
                GymStatusBadge(
                    title: String(localized: "Next"),
                    systemImage: AppIcon.play,
                    tint: Color.gymPrimary
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func runStatusRow(_ run: RepeatingPlanRun) -> some View {
        switch run.status {
        case .active:
            GymStatusBadge(
                title: String(localized: "Rotation active"),
                systemImage: AppIcon.play,
                tint: Color.gymPrimary
            )
        case .paused:
            GymStatusBadge(
                title: String(localized: "Rotation paused"),
                systemImage: AppIcon.pause,
                tint: Color.gymSubduedText
            )
        case .ended, .archived:
            EmptyView()
        }
    }

    private struct AlternateSelection: Identifiable {
        let id = UUID()
        let slotIndex: Int
        let templateName: String
    }

    private enum DestructiveAction: Identifiable {
        case restart
        case end

        var id: String { title }

        var title: String {
            switch self {
            case .restart: String(localized: "Restart rotation?")
            case .end: String(localized: "End this rotation?")
            }
        }

        var confirmationTitle: String {
            switch self {
            case .restart: String(localized: "Restart Rotation")
            case .end: String(localized: "End Plan")
            }
        }

        var message: String {
            switch self {
            case .restart:
                String(localized: "This returns the rotation to Workout 1 and records the restart. Completed workout history stays unchanged.")
            case .end:
                String(localized: "You can activate this rotation again later. Completed workout history stays unchanged.")
            }
        }
    }
}

import SwiftUI
import SwiftData

/// The session chrome: a compact session identity, elapsed time, and an exact
/// position rail. The exercise below remains the stage's dominant object.
struct ActiveWorkoutStageHeader: View {
    let workout: Workout
    let pages: [WorkoutStagePage]
    @Binding var selection: WorkoutStagePage
    let onMinimize: () -> Void
    let onDiscard: () -> Void
    let onAddExercise: () -> Void
    let onAddBlock: () -> Void
    let onAddMobility: (() -> Void)?
    /// Whether the session can be committed right now. The control stays on
    /// screen while it cannot, because a finish that disappears reads as a
    /// missing feature rather than as unfinished work.
    let isFinishEnabled: Bool
    let onFinish: () -> Void

    private var workoutName: String {
        let name = workout.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "Today’s workout") : name
    }

    private var workPages: [WorkoutStagePage] {
        pages.filter { !$0.isFinish }
    }

    private var displayedPosition: Int {
        guard !workPages.isEmpty else { return 0 }
        guard let index = workPages.firstIndex(of: selection) else {
            return workPages.count
        }
        return index + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                Button(action: onMinimize) {
                    Image(systemName: AppIcon.minimize)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.trameText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityLabel("Minimize workout")
                .accessibilityIdentifier("minimize-workout")

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("WORKOUT")
                        .font(AppFont.micro)
                        .tracking(0.8)
                        .foregroundStyle(Color.trameSubdued)

                    HStack(spacing: Spacing.xs) {
                        Text(workoutName)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .accessibilityIdentifier("active-workout-title")

                        if workout.sourceTemplate?.isBuiltIn == true {
                            BuiltInBadge()
                        }
                    }
                }

                Spacer(minLength: 0)

                Text(workout.startTime, style: .timer)
                    .font(AppFont.metadata.monospacedDigit())
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityLabel("Elapsed time")

                if !workout.exercises.isEmpty {
                    finishButton
                }

                Menu {
                    Button {
                        onAddExercise()
                    } label: {
                        Label("Add exercise", systemImage: AppIcon.plus)
                    }
                    .accessibilityIdentifier("add-active-exercise-menu")

                    if let onAddMobility {
                        Button {
                            onAddMobility()
                        } label: {
                            Label("Add stretch", systemImage: AppIcon.mobility)
                        }
                        .accessibilityIdentifier("add-active-mobility-menu")
                    }

                    Button {
                        onAddBlock()
                    } label: {
                        Label("Add execution block", systemImage: AppIcon.relationship)
                    }
                    .accessibilityIdentifier("add-execution-block")

                    Section {
                        // Losing the session is the rarest action on this
                        // screen and must never sit one mistaken tap from the
                        // set logging.
                        Button(role: .destructive, action: onDiscard) {
                            Label("Discard workout", systemImage: AppIcon.trash)
                        }
                        .accessibilityIdentifier("discard-workout")
                    }
                } label: {
                    Image(systemName: AppIcon.ellipsis)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.trameText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Workout actions")
                .accessibilityIdentifier("active-workout-menu")
            }

            if !workPages.isEmpty {
                HStack(spacing: Spacing.m) {
                    Text("\(displayedPosition) / \(workPages.count)")
                        .font(AppFont.micro.monospacedDigit())
                        .foregroundStyle(Color.trameSubdued)
                        .monospacedDigit()
                        .fixedSize()
                        .accessibilityLabel(
                            Text("Page \(displayedPosition) of \(workPages.count)")
                        )

                    progressRail
                }
            }
        }
        .padding(.horizontal, Spacing.screenInset)
        .padding(.bottom, Spacing.s)
        .background(Color.trameCanvas)
    }

    /// Finishing happens once a session and ends it. It used to own the
    /// full-width bar at the thumb, which is the best real estate on a screen
    /// whose actual repeated action — logging a set, fifteen to forty times —
    /// had to share it. An exit belongs in the chrome, so this is the only
    /// place it lives; the command bar keeps the log action.
    private var finishButton: some View {
        Button(action: onFinish) {
            Text("Finish")
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isFinishEnabled ? Color.trameAction : Color.trameSubdued)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Spacing.xs)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .disabled(!isFinishEnabled)
        .accessibilityLabel("Finish workout")
        .accessibilityHint(
            Text(isFinishEnabled ? "" : String(localized: "Complete at least one set before finishing."))
        )
        .accessibilityIdentifier("finish-workout")
    }

    /// A thin segmented rail preserves direct page jumping while reading as
    /// progress rather than a second row of controls. Each segment retains a
    /// 44-point target; selection changes thickness and tone so it survives
    /// without color while remaining visually subordinate to the exercise.
    private var progressRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(workPages.enumerated()), id: \.element.id) { index, page in
                        railSegment(for: page, at: index)
                            .id(page.id)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { _, page in
                if workPages.contains(page) {
                    proxy.scrollTo(page.id, anchor: .center)
                }
            }
        }
    }

    private func railSegment(for page: WorkoutStagePage, at index: Int) -> some View {
        let isSelected = page == selection
        let progress = WorkoutStagePlan.progress(of: page, in: workout)

        return Button {
            selection = page
        } label: {
            RoundedRectangle(cornerRadius: Radius.icon, style: .continuous)
                .fill(railColor(for: progress))
                .frame(width: Spacing.xxl)
                .frame(height: isSelected ? 3 : 1)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(railAccessibilityLabel(for: page, at: index, progress: progress)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("stage-dot-\(page.id)")
    }

    private func railColor(for progress: WorkoutStagePlan.Progress) -> Color {
        switch progress {
        case .complete: return Color.trameCompleted
        case .started: return Color.trameText
        case .untouched: return Color.trameSeparator
        }
    }

    private func railAccessibilityLabel(
        for page: WorkoutStagePage,
        at index: Int,
        progress: WorkoutStagePlan.Progress
    ) -> String {
        let names = WorkoutStagePlan.entries(for: page, in: workout)
            .map(\.occurrenceDisplayName)
            .joined(separator: ", ")
        let position = String(localized: "Page \(index + 1) of \(workPages.count)")
        let state: String = switch progress {
        case .complete: String(localized: "complete")
        case .started: String(localized: "in progress")
        case .untouched: String(localized: "not started")
        }
        return "\(position). \(names). \(state)"
    }
}

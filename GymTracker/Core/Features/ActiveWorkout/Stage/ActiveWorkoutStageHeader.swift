import SwiftUI
import SwiftData

/// The session chrome: leave, where you are, how long you have been here, and
/// the rarely-wanted destructive action.
///
/// It replaces a navigation bar rather than decorating one. The bar gave three
/// slots — leading, title, trailing — and the thing most worth showing here is
/// none of those: it is *position in the session*, which is a row of dots the
/// width of the screen. A title reading "Today's workout" was restating what
/// the lifter chose ninety seconds ago.
struct ActiveWorkoutStageHeader: View {
    let workout: Workout
    let pages: [WorkoutStagePage]
    @Binding var selection: WorkoutStagePage
    let onMinimize: () -> Void
    let onDiscard: () -> Void
    let onAddExercise: () -> Void
    let onAddBlock: () -> Void

    private var workoutName: String {
        let name = workout.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "Today’s workout") : name
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                Button(action: onMinimize) {
                    Image(systemName: AppIcon.minimize)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityLabel("Minimize workout")
                .accessibilityIdentifier("minimize-workout")

                // Which session this is. Small and subdued rather than a
                // title: a lifter running "Push A" and "Push B" in the same
                // week needs to be able to confirm which one they opened, but
                // they chose it ninety seconds ago and it should not compete
                // with the exercise for the eye.
                Text(workoutName)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("active-workout-title")

                if workout.sourceTemplate?.isBuiltIn == true {
                    BuiltInBadge()
                }

                Spacer(minLength: Spacing.s)

                // Elapsed session time. `style: .timer` keeps itself current
                // without this view redrawing, which matters because the header
                // is above a pager that is expensive to invalidate.
                Text(workout.startTime, style: .timer)
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityLabel("Elapsed time")

                Menu {
                    Button {
                        onAddExercise()
                    } label: {
                        Label("Add exercise", systemImage: AppIcon.plus)
                    }
                    .accessibilityIdentifier("add-active-exercise-menu")

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
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Workout actions")
                .accessibilityIdentifier("active-workout-menu")
            }

            progressRail
        }
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.s)
        .background(Color.gymBackground)
    }

    /// One dot per page, carrying completion state and doubling as a jump
    /// target. The dots are the reason the exercise list could be taken off
    /// screen: they answer "how much is left" continuously, which is the only
    /// question the list was answering that the page cannot.
    private var progressRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        dot(for: page, at: index)
                            .id(page.id)
                    }
                }
                .padding(.horizontal, Spacing.s)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 28)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { _, page in
                // The pager already owns the interactive swipe animation.
                // Animating the rail at the same time creates a second layout
                // transaction exactly as the page settles, which reads as a
                // small hitch. Keep the rail synchronized without competing
                // motion.
                proxy.scrollTo(page.id, anchor: .center)
            }
        }
    }

    private func dot(for page: WorkoutStagePage, at index: Int) -> some View {
        let isSelected = page == selection
        let progress = WorkoutStagePlan.progress(of: page, in: workout)

        return Button {
            selection = page
        } label: {
            ZStack {
                // The selection ring is a *shape* change, not only a colour
                // change, so "you are here" survives grayscale and Increase
                // Contrast — the same rule the set list's current-row pointer
                // follows.
                Circle()
                    .stroke(isSelected ? Color.gymText : .clear, lineWidth: 1.5)
                    .frame(width: 16, height: 16)

                Group {
                    if page.isFinish {
                        Image(systemName: AppIcon.checkmark)
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(dotColor(for: progress, page: page))
                    } else {
                        Circle()
                            .fill(dotColor(for: progress, page: page))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(dotAccessibilityLabel(for: page, at: index, progress: progress)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("stage-dot-\(page.id)")
    }

    private func dotColor(for progress: WorkoutStagePlan.Progress, page: WorkoutStagePage) -> Color {
        if page.isFinish { return Color.gymSubduedText }
        switch progress {
        case .complete: return Color.gymSecondary
        case .started: return Color.gymAccent
        case .untouched: return Color.gymSubduedText.opacity(0.35)
        }
    }

    private func dotAccessibilityLabel(
        for page: WorkoutStagePage,
        at index: Int,
        progress: WorkoutStagePlan.Progress
    ) -> String {
        guard !page.isFinish else { return String(localized: "Finish and review") }

        let names = WorkoutStagePlan.entries(for: page, in: workout)
            .map(\.occurrenceDisplayName)
            .joined(separator: ", ")
        let position = String(localized: "Page \(index + 1) of \(pages.count)")
        let state: String = switch progress {
        case .complete: String(localized: "complete")
        case .started: String(localized: "in progress")
        case .untouched: String(localized: "not started")
        }
        return "\(position). \(names). \(state)"
    }
}

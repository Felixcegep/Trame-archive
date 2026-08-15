import SwiftUI

/// What the lifter is resting *for*. Assembled by the caller from the flow
/// resolver so this view never has to reach into the workout graph.
struct RestNextUp: Equatable {
    let exerciseName: String
    let setNumber: Int
    let setCount: Int
    /// "8 × 80 kg", "45 sec", "12 reps" — already unit-formatted.
    let target: String?
    /// Non-nil only for a set whose role is worth naming: warm-up, top set,
    /// AMRAP. A plain working set says nothing here.
    let roleTitle: String?
    /// True when the next set belongs to a different exercise than the one just
    /// finished, which is the case a lifter most needs warned about — it means
    /// walking to another station before the clock runs out.
    let changesExercise: Bool
}

/// Rest takes the field while the timer is visible. The attention color names
/// the state, the remaining time is the one dominant answer, and the next set
/// follows as preparation rather than as a competing object.
///
/// It stays collapsible. The timer continues in `ActiveWorkoutViewModel`, so
/// dismissing this presentation never changes session or Live Activity state.
struct RestTakeoverView: View {
    let viewModel: ActiveWorkoutViewModel
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    let nextUp: RestNextUp?
    let onStartNextSet: () -> Void
    let onCollapse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var countdownPointSize: CGFloat = 88

    /// Trimming below this threshold could end rest without an explicit Skip.
    private let trimStep: TimeInterval = 15
    private let extendStep: TimeInterval = 30

    var body: some View {
        VStack(spacing: 0) {
            restHeader

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    timerField
                    nextUpGroup
                    effortCapture
                }
                .padding(.horizontal, Spacing.screenInset)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            controls
                .padding(.horizontal, Spacing.screenInset)
                .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.trameAttention)
        .foregroundStyle(Color.trameAttentionInk)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAction(named: Text("Skip rest"), skipRest)
        .accessibilityAction(named: Text("Collapse rest timer"), onCollapse)
    }

    // MARK: - Header

    private var restHeader: some View {
        Button(action: onCollapse) {
            HStack(spacing: Spacing.m) {
                Text("Rest")
                    .font(AppFont.eyebrow)
                    .tracking(0.9)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                Image(systemName: AppIcon.chevronDown)
                    .font(AppFont.sectionTitle)
            }
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.screenInset)
        .padding(.top, Spacing.s)
        .accessibilityLabel(Text("Collapse rest timer"))
        .accessibilityIdentifier("collapse-rest-takeover")
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard value.translation.height > 40 else { return }
                    onCollapse()
                }
        )
    }

    // MARK: - Time

    private var timerField: some View {
        countdown
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    @ViewBuilder
    private var countdown: some View {
        if viewModel.isRestReady || viewModel.isTimerPaused {
            timerReadout(remaining: remaining(at: .now))
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                timerReadout(remaining: remaining(at: context.date))
            }
        }
    }

    private func timerReadout(remaining: TimeInterval) -> some View {
        VStack(spacing: Spacing.s) {
            Text(clockText(remaining))
                .font(AppFont.timer(scaledPointSize: countdownPointSize))
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            Label(timerStateTitle, systemImage: timerStateIcon)
                .font(AppFont.metadata)
                .tracking(0.7)
                .textCase(.uppercase)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(timerAccessibilityLabel))
        .accessibilityValue(Text(viewModel.isRestReady ? "" : clockText(remaining)))
    }

    // MARK: - Effort

    /// How hard the set that just ended felt, asked on the screen that already
    /// owns the moment after it.
    ///
    /// **Not a pop-up.** A dialog between the set and the timer delays the one
    /// thing on this screen that is genuinely time-sensitive, and adds a modal
    /// layer over a flow that already has one. Rest is dead time by definition
    /// — the question costs nothing here, and the lifter can ignore it entirely
    /// and let the clock run.
    ///
    /// Appears only when the exercise **prescribed** an effort target. Asking
    /// on every accessory set trains people to dismiss it, and an effort log
    /// nobody reads is worse than no effort log.
    @ViewBuilder
    private var effortCapture: some View {
        if let set = viewModel.lastCompletedSetAwaitingEffort {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Rectangle()
                    .fill(Color.trameAttentionInk)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline) {
                    Text(effortMeasure == .rpe ? "HOW HARD WAS THAT?" : "REPS LEFT IN RESERVE")
                        .font(AppFont.eyebrow)
                        .tracking(0.8)

                    Spacer(minLength: Spacing.s)

                    Text(effortValueText(for: set))
                        .font(AppFont.metricCompact)
                        .opacity(effortIsAnswered(set) ? 1 : 0.65)
                }

                // A native `Slider` rather than a row of ten targets: effort is
                // a felt quantity on a continuum, the thumb can be dragged
                // without looking, and VoiceOver gets an adjustable control for
                // free. Steps keep it on the scale's real granularity.
                Slider(
                    value: effortBinding(for: set),
                    in: effortRange,
                    step: effortStep
                ) {
                    Text(effortMeasure == .rpe ? "RPE" : "Reps in reserve")
                } minimumValueLabel: {
                    Text(Formatters.formatFloat(Float(effortRange.lowerBound)))
                        .font(AppFont.micro)
                } maximumValueLabel: {
                    Text(Formatters.formatFloat(Float(effortRange.upperBound)))
                        .font(AppFont.micro)
                }
                .tint(Color.trameAttentionInk)
                .accessibilityValue(Text(effortValueText(for: set)))

                // The scale in words. A number between 6 and 10 means nothing
                // on its own to anyone who has not memorised the table.
                Text(effortMeaning(for: set))
                    .font(AppFont.metadata)
                    .opacity(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(reduceMotion ? nil : AppMotion.compact, value: effortValueText(for: set))
            }
            .accessibilityIdentifier("rest-effort-capture")
        }
    }

    private var effortMeasure: EffortMeasure {
        EffortMeasure(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.effortMeasure) ?? "") ?? .rir
    }

    private var effortRange: ClosedRange<Double> {
        effortMeasure == .rpe ? 6...10 : 0...5
    }

    private var effortStep: Double {
        effortMeasure == .rpe ? 0.5 : 1
    }

    private func effortIsAnswered(_ set: ExerciseSet) -> Bool {
        effortMeasure == .rpe ? set.rpe != nil : set.rir != nil
    }

    /// Starts at the prescribed target rather than the middle of the scale: the
    /// programme already said what this set should have felt like, so the most
    /// likely answer is "as prescribed" and that should be zero drags away.
    private func effortValue(for set: ExerciseSet) -> Double {
        if effortMeasure == .rpe {
            return set.rpe ?? set.prescribedRPE ?? 8
        }
        return Double(set.rir ?? set.prescribedRIR ?? 2)
    }

    private func effortBinding(for set: ExerciseSet) -> Binding<Double> {
        Binding(
            get: { effortValue(for: set) },
            set: { newValue in
                if effortMeasure == .rpe {
                    set.rpe = newValue
                } else {
                    set.rir = Int(newValue.rounded())
                }
                viewModel.persistChanges()
            }
        )
    }

    private func effortValueText(for set: ExerciseSet) -> String {
        let value = effortValue(for: set)
        guard effortIsAnswered(set) else { return String(localized: "Not set") }
        return effortMeasure == .rpe
            ? "RPE \(Formatters.formatFloat(Float(value)))"
            : "RIR \(Int(value))"
    }

    private func effortMeaning(for set: ExerciseSet) -> String {
        let value = effortValue(for: set)
        return effortMeasure == .rpe
            ? RPEScale.meaning(for: value)
            : RIRScale.meaning(for: Int(value))
    }

    // MARK: - Next up

    @ViewBuilder
    private var nextUpGroup: some View {
        if let nextUp {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Rectangle()
                    .fill(Color.trameAttentionInk)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                HStack(spacing: Spacing.s) {
                    Text("Up next")
                        .font(AppFont.eyebrow)
                        .tracking(0.8)
                        .textCase(.uppercase)

                    if nextUp.changesExercise {
                        Text("New exercise")
                            .font(AppFont.micro)
                            .tracking(0.55)
                    }
                    Spacer(minLength: 0)
                }

                Text(nextUp.exerciseName)
                    .font(AppFont.stageTitle)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.s) {
                    Text("Set \(nextUp.setNumber) of \(nextUp.setCount)")
                        .font(AppFont.metadata)
                    if let roleTitle = nextUp.roleTitle {
                        Text("·")
                        Text(roleTitle)
                            .font(AppFont.metadata)
                    }
                }
                .opacity(0.72)

                if let target = nextUp.target {
                    Text(target)
                        .font(AppFont.metricLarge)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("rest-next-up")
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: Spacing.m) {
            Rectangle()
                .fill(Color.trameAttentionInk)
                .frame(height: 1)
                .accessibilityHidden(true)

            if viewModel.isRestReady {
                Button(action: onStartNextSet) {
                    Text("Start next set")
                        .font(AppFont.sectionTitle)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.trameAttention)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            Color.trameAttentionInk,
                            in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("start-next-set")
            } else {
                adjustmentRow

                Button(action: skipRest) {
                    Text("Skip rest")
                        .font(AppFont.metadata)
                        .underline()
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("skip-rest")
            }
        }
    }

    private var adjustmentRow: some View {
        HStack(spacing: Spacing.m) {
            adjustmentButton(
                title: "−\(Int(trimStep))s",
                systemImage: AppIcon.minus,
                accessibilityLabel: "Take \(Int(trimStep)) seconds off rest",
                identifier: "rest-trim",
                isEnabled: canTrim
            ) {
                viewModel.addRestTime(-trimStep)
            }

            adjustmentButton(
                title: viewModel.isTimerPaused ? String(localized: "Resume") : String(localized: "Pause"),
                systemImage: viewModel.isTimerPaused ? AppIcon.play : AppIcon.pause,
                accessibilityLabel: viewModel.isTimerPaused ? "Resume rest" : "Pause rest",
                identifier: "rest-pause-toggle",
                isEnabled: true
            ) {
                if viewModel.isTimerPaused {
                    viewModel.resumeTimer()
                } else {
                    viewModel.pauseTimer()
                }
            }

            adjustmentButton(
                title: "+\(Int(extendStep))s",
                systemImage: AppIcon.plus,
                accessibilityLabel: "Add \(Int(extendStep)) seconds to rest",
                identifier: "rest-extend",
                isEnabled: true
            ) {
                viewModel.addRestTime(extendStep)
            }
        }
    }

    private func adjustmentButton(
        title: String,
        systemImage: String,
        accessibilityLabel: String,
        identifier: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: systemImage)
                    .font(AppFont.subheadlineBold)
                Text(title)
                    .font(AppFont.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .foregroundStyle(Color.trameAttentionInk)
        .background(Color.trameAttention, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Color.trameAttentionInk, lineWidth: 1)
        }
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Derived state

    private func skipRest() {
        activeLoggingMetrics.restSkipped()
        viewModel.cancelTimer()
    }

    /// Trimming below zero would end the rest without the lifter asking to skip
    /// it, so the control switches off before it can.
    private var canTrim: Bool {
        remaining(at: .now) > trimStep
    }

    private func remaining(at date: Date) -> TimeInterval {
        if viewModel.isRestReady { return 0 }
        if viewModel.isTimerPaused { return viewModel.pausedTimeRemaining }
        guard let endDate = viewModel.timerPause else { return 0 }
        return max(0, endDate.timeIntervalSince(date))
    }

    private func clockText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var timerStateTitle: LocalizedStringKey {
        if viewModel.isRestReady { return "Ready" }
        if viewModel.isTimerPaused { return "Paused" }
        return "Remaining"
    }

    private var timerStateIcon: String {
        if viewModel.isRestReady { return AppIcon.checkmark }
        if viewModel.isTimerPaused { return AppIcon.pause }
        return AppIcon.timer
    }

    private var timerAccessibilityLabel: String {
        if viewModel.isRestReady { return String(localized: "Rest complete") }
        if viewModel.isTimerPaused { return String(localized: "Rest paused") }
        return String(localized: "Resting")
    }

    private var accessibilityIdentifier: String {
        if viewModel.isRestReady { return "rest-ready" }
        return viewModel.isTimerPaused ? "rest-paused" : "rest-running"
    }
}

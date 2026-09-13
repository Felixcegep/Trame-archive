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

/// Rest stays on the workout canvas. Amber is reserved for elapsed progress
/// and controls, while the remaining time remains the one dominant answer.
///
/// It stays collapsible. The timer continues in `ActiveWorkoutViewModel`, so
/// dismissing this presentation never changes session or Live Activity state.
struct RestTakeoverView: View {
    let viewModel: ActiveWorkoutViewModel
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    let nextUp: RestNextUp?
    let onEditJustLogged: (ExerciseEntry, ExerciseSet) -> Void
    /// Reopens the set that just ended, keeping its values. Rest keeps
    /// running: the lifter is undoing a completion, not cancelling a rest.
    let onUndoJustLogged: (ExerciseEntry, ExerciseSet) -> Void
    let onStartNextSet: () -> Void
    let onCollapse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var countdownPointSize: CGFloat = 88
    @ScaledMetric(relativeTo: .largeTitle) private var compactCountdownPointSize: CGFloat = 56

    /// Trimming below this threshold could end rest without an explicit Skip.
    private let trimStep: TimeInterval = 15
    private let extendStep: TimeInterval = 30

    var body: some View {
        VStack(spacing: 0) {
            restHeader

            ScrollView {
                VStack(spacing: showsPostSetCapture ? Spacing.l : Spacing.xxl) {
                    timerField
                    justLoggedGroup
                    effortCapture
                    nextUpGroup
                }
                .padding(.horizontal, Spacing.screenInset)
                .padding(.top, showsPostSetCapture ? Spacing.m : Spacing.xl)
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
        .background(Color.trameCanvas)
        .foregroundStyle(Color.trameText)
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

    /// After a logged set the rest screen also asks quality and effort. The
    /// countdown stays the dominant object, but it has to share the canvas or
    /// those questions fall below the fold between snatch attempts.
    private var showsPostSetCapture: Bool {
        viewModel.lastCompletedSetContext != nil
    }

    private var activeCountdownPointSize: CGFloat {
        showsPostSetCapture ? compactCountdownPointSize : countdownPointSize
    }

    private var timerField: some View {
        countdown
        .frame(maxWidth: .infinity)
        .padding(.vertical, showsPostSetCapture ? Spacing.s : Spacing.xxl)
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
            if let planned = viewModel.restPlannedDuration, planned > 0 {
                ProgressView(value: min(1, max(0, 1 - (remaining / planned))))
                    .tint(Color.trameAttention)
                    .opacity(viewModel.isTimerPaused ? 0.45 : 1)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            } else {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }

            Text(clockText(remaining))
                .font(AppFont.timer(scaledPointSize: activeCountdownPointSize))
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .foregroundStyle(viewModel.isTimerPaused ? Color.trameSubdued : Color.trameText)

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

    @ViewBuilder
    private var justLoggedGroup: some View {
        if let context = viewModel.lastCompletedSetContext {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("JUST LOGGED")
                            .font(AppFont.eyebrow)
                            .tracking(0.8)

                        Text(context.entry.occurrenceDisplayName)
                            .font(AppFont.metadata)
                    }

                    Spacer(minLength: Spacing.s)

                    Text(loggedSetSummary(context.set, in: context.entry))
                        .font(AppFont.metricCompact)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: Spacing.xl) {
                    Button("Edit") {
                        onEditJustLogged(context.entry, context.set)
                    }
                    .font(AppFont.metadata)
                    .frame(minWidth: ComponentSize.minimumTouchTarget, minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityLabel("Edit the set just logged")
                    .accessibilityHint("Rest continues while you correct the completed set.")
                    .accessibilityIdentifier("edit-just-logged-set")

                    // Correcting a value and taking the set back are different
                    // mistakes. Edit answers "the number is wrong"; Undo
                    // answers "this set should not be logged at all" — the one
                    // recovery that was previously only reachable by leaving
                    // rest and finding the set row.
                    Button("Undo") {
                        onUndoJustLogged(context.entry, context.set)
                    }
                    .font(AppFont.metadata)
                    .frame(minWidth: ComponentSize.minimumTouchTarget, minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityLabel("Undo the set just logged")
                    .accessibilityHint("Marks the set incomplete and keeps its values. Rest continues.")
                    .accessibilityIdentifier("undo-just-logged-set")

                    Spacer(minLength: 0)
                }

                olympicAttemptCapture(for: context)

                if !viewModel.isRestReady && !showsPostSetCapture {
                    Text("Rest continues")
                        .font(AppFont.micro)
                        .tracking(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("rest-just-logged")
        }
    }

    private func loggedSetSummary(_ set: ExerciseSet, in entry: ExerciseEntry) -> String {
        var parts: [String] = []
        if entry.trackingTypeSnapshot.usesWeight, set.weight > 0 {
            parts.append("\(Formatters.formatFloat(set.weight)) \(set.weightType.rawValue)")
        }
        if entry.trackingTypeSnapshot.usesReps, set.repetitions > 0 {
            parts.append("× \(Formatters.formatFloat(set.repetitions))")
        }
        if entry.trackingTypeSnapshot.usesDuration, let duration = set.duration, duration > 0 {
            parts.append("\(Formatters.formatFloat(Float(duration))) sec")
        }
        if let rpe = set.rpe {
            parts.append("@ RPE \(Formatters.formatFloat(Float(rpe)))")
        } else if let rir = set.rir {
            parts.append("@ RIR \(rir)")
        }
        return parts.isEmpty ? String(localized: "Completed") : parts.joined(separator: " ")
    }

    @ViewBuilder
    private func olympicAttemptCapture(for context: (entry: ExerciseEntry, set: ExerciseSet)) -> some View {
        if !context.set.orderedComplexComponents.isEmpty {
            ComplexComponentResultsView(
                components: context.set.orderedComplexComponents,
                onChange: {
                    context.set.refreshDerivedOlympicQuality()
                    viewModel.persistChanges()
                }
            )
        } else if context.entry.usesOlympicAttemptLogging {
            OlympicAttemptQualityCapture(set: context.set) {
                viewModel.persistChanges()
            }
        }
    }

    /// How hard the set that just ended felt, asked on the screen that already
    /// owns the moment after it.
    ///
    /// **Not a pop-up.** A dialog between the set and the timer delays the one
    /// thing on this screen that is genuinely time-sensitive, and adds a modal
    /// layer over a flow that already has one. Rest is dead time by definition
    /// — the question costs nothing here, and the lifter can ignore it and let
    /// the clock run. It is asked after every completed set so effort is a
    /// habit, not a prescription-only extra.
    @ViewBuilder
    private var effortCapture: some View {
        if let set = viewModel.lastCompletedSetAwaitingEffort {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Rectangle()
                    .fill(Color.trameSeparator)
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
                .tint(Color.trameAttention)
                .accessibilityValue(Text(effortValueText(for: set)))

                // The scale in words. A number between 6 and 10 means nothing
                // on its own to anyone who has not memorised the table.
                Text(effortMeaning(for: set))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(reduceMotion ? nil : AppMotion.compact, value: effortValueText(for: set))
            }
            .accessibilityIdentifier("rest-effort-capture")
        }
    }

    private var effortMeasure: EffortMeasure {
        if viewModel.lastCompletedSetContext?.entry.usesOlympicAttemptLogging == true {
            return .rpe
        }
        return EffortMeasure(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.effortMeasure) ?? "") ?? .rir
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
            VStack(alignment: .leading, spacing: showsPostSetCapture ? Spacing.s : Spacing.m) {
                Rectangle()
                    .fill(Color.trameSeparator)
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
                    .font(showsPostSetCapture ? AppFont.titleMedium : AppFont.stageTitle)
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
                .foregroundStyle(Color.trameSubdued)

                if let target = nextUp.target {
                    Text(target)
                        .font(showsPostSetCapture ? AppFont.metricCompact : AppFont.metricLarge)
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
                .fill(Color.trameSeparator)
                .frame(height: 1)
                .accessibilityHidden(true)

            if viewModel.isRestReady {
                Button(action: onStartNextSet) {
                    HStack(spacing: Spacing.m) {
                        Text("Continue")
                            .font(AppFont.sectionTitle)

                        Spacer(minLength: Spacing.s)

                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.subheadlineSemibold)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.tramePrimaryAction)
                .accessibilityLabel("Continue to next set")
                .accessibilityIdentifier("start-next-set")
            } else {
                adjustmentRow

                Button(action: skipRest) {
                    Text("Skip rest")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
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
        .foregroundStyle(Color.trameText)
        .background(Color.trameRow, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Color.trameSeparator, lineWidth: 1)
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

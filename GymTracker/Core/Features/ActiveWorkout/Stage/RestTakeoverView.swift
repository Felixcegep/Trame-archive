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

/// Rest, when rest is the whole job.
///
/// The previous treatment was a 60pt strip pinned above the list. That was the
/// right call against the card list it replaced, but it settled for being
/// *visible* when the actual requirement is to be **readable without holding
/// the phone** — set down on a bench, propped against a water bottle, glanced
/// at from inside a rack. Between sets there is nothing else to do, so there is
/// no content the strip was protecting: it was small out of habit, not need.
///
/// So rest takes the page. The countdown is the largest type in the app, the
/// ring answers "nearly done?" without reading digits at all, and the next set
/// is stated in full so the lifter can load the bar before the clock ends
/// rather than after.
///
/// It stays collapsible. A lifter who wants to review earlier sets mid-rest
/// drags it down and gets the compact pill in the command bar instead — the
/// timer keeps running either way, because the countdown lives in the view
/// model, not here.
struct RestTakeoverView: View {
    let viewModel: ActiveWorkoutViewModel
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    let nextUp: RestNextUp?
    let onStartNextSet: () -> Void
    let onCollapse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Below this, "+30s" would push the rest past where it started and the
    /// ring would read over full. Above it, trimming is safe.
    private let trimStep: TimeInterval = 15
    private let extendStep: TimeInterval = 30

    var body: some View {
        VStack(spacing: 0) {
            collapseHandle

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    dial
                    effortCapture
                    nextUpCard
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // The dial and the next-set card fit without scrolling at every
            // standard text size. The scroll view exists for accessibility
            // sizes, where the same content is genuinely taller than the
            // screen — and where clipping it would be the failure.
            .scrollBounceBehavior(.basedOnSize)

            controls
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gymAccentSurface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAction(named: Text("Skip rest"), skipRest)
        .accessibilityAction(named: Text("Collapse rest timer"), onCollapse)
    }

    // MARK: - Collapse

    private var collapseHandle: some View {
        Button(action: onCollapse) {
            VStack(spacing: Spacing.xs) {
                Capsule()
                    .fill(Color.gymSubduedText.opacity(0.4))
                    .frame(width: 40, height: 5)
                Text(title)
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.s)
        .accessibilityLabel(Text("\(title). Collapse rest timer"))
        .accessibilityIdentifier("collapse-rest-takeover")
        // Dragging the sheet down is the gesture people try first; the handle
        // above is what tells them it is there, and the button is what makes it
        // reachable to anyone who cannot drag.
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard value.translation.height > 40 else { return }
                    onCollapse()
                }
        )
    }

    // MARK: - Dial

    private var dial: some View {
        ZStack {
            ring
            countdown
        }
        .frame(maxWidth: .infinity)
        .frame(height: dialSize)
        .padding(.top, Spacing.m)
        // The digits change every second. Read as one status instead, without
        // the count — `Documentation/Accessibility.md` is explicit that a
        // per-second re-read is worse than no reading at all.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(dialAccessibilityLabel))
    }

    /// Only drawn when the rest's intended length is known. After a cold launch
    /// mid-rest it is not, and a ring with an invented denominator would be a
    /// confident lie — the digits alone are the honest fallback.
    @ViewBuilder
    private var ring: some View {
        Circle()
            .stroke(Color.gymText.opacity(0.08), lineWidth: ringWidth)

        if let total = viewModel.restPlannedDuration, total > 0 {
            // `.animation` drives a frame-rate timeline rather than a one-second
            // one. The arc used to step once per second, which reads as a
            // stuttering gauge rather than time passing; the digits below still
            // tick per second, because a sliding clock is harder to read than a
            // ticking one.
            //
            // Reduce Motion keeps the per-second step: that *is* the accessible
            // rendering of this control, not a lesser one.
            if reduceMotion {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    progressRing(total: total, at: context.date)
                }
            } else {
                TimelineView(.animation) { context in
                    progressRing(total: total, at: context.date)
                }
            }
        }
    }

    private func progressRing(total: TimeInterval, at date: Date) -> some View {
        let left = remaining(at: date)
        return Circle()
            .trim(from: 0, to: max(0, min(1, left / total)))
            .stroke(
                ringColor(remaining: left),
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            // A second channel for the last ten seconds, so urgency is never
            // carried by colour alone.
            .scaleEffect(pulseScale(remaining: left, at: date))
    }

    /// The rest dial's one piece of information beyond the digits: how urgent
    /// this is, readable from across a rack.
    ///
    /// Colours cross-fade across a three-second window either side of each
    /// threshold. A hard switch at exactly 60 seconds reads as a rendering
    /// glitch; a ramp reads as time passing.
    private func ringColor(remaining: TimeInterval) -> Color {
        if viewModel.isRestReady { return Color.gymSecondary }

        let plenty = Color.gymSecondary
        let soon = Color.gymCaution
        let now = Color.gymUrgent

        if remaining > 63 { return plenty }
        if remaining > 57 { return plenty.mix(with: soon, by: (63 - remaining) / 6) }
        if remaining > 13 { return soon }
        if remaining > 7 { return soon.mix(with: now, by: (13 - remaining) / 6) }
        return now
    }

    /// A 1 Hz pulse inside the final ten seconds. Small on purpose — it should
    /// register in peripheral vision without pulling the eye off the bar.
    private func pulseScale(remaining: TimeInterval, at date: Date) -> CGFloat {
        guard !reduceMotion, remaining > 0, remaining <= 10 else { return 1 }
        let phase = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        return 1 + 0.02 * CGFloat(sin(phase * 2 * .pi)).magnitude
    }

    /// Which urgency band the rest is in, named so VoiceOver and the state line
    /// carry it too.
    private func bandTitle(remaining: TimeInterval) -> String {
        if remaining > 60 { return String(localized: "Plenty") }
        if remaining > 10 { return String(localized: "Soon") }
        return String(localized: "Now")
    }

    @ViewBuilder
    private var countdown: some View {
        VStack(spacing: Spacing.xs) {
            if viewModel.isRestReady {
                Image(systemName: AppIcon.checkmarkCircle)
                    .font(AppFont.displayLarge)
                    .foregroundStyle(Color.gymSecondary)
                Text("Ready")
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.gymSecondary)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = remaining(at: context.date)
                    VStack(spacing: Spacing.xxs) {
                        Text(clockText(left))
                            .font(AppFont.restCountdown)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(Color.gymText)

                        // The ring's urgency band, in words. Without this the
                        // band is carried by hue alone, which fails both
                        // `Documentation/Accessibility.md` and anyone reading
                        // the dial in direct sun.
                        if !viewModel.isTimerPaused {
                            Text(bandTitle(remaining: left))
                                .font(AppFont.captionBold)
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(ringColor(remaining: left))
                        }
                    }
                }

                if viewModel.isTimerPaused {
                    Label("Paused", systemImage: AppIcon.pause)
                        .font(AppFont.footnoteMedium)
                        .foregroundStyle(Color.gymAccent)
                }
            }
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - Next up

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
                HStack(alignment: .firstTextBaseline) {
                    Text(effortMeasure == .rpe ? "HOW HARD WAS THAT?" : "REPS LEFT IN RESERVE")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymSubduedText)

                    Spacer(minLength: Spacing.s)

                    Text(effortValueText(for: set))
                        .font(AppFont.titleSmallSemiboldMonospaced)
                        .foregroundStyle(effortIsAnswered(set) ? Color.gymText : Color.gymSubduedText)
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
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                } maximumValueLabel: {
                    Text(Formatters.formatFloat(Float(effortRange.upperBound)))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .tint(Color.gymPrimary)
                .accessibilityValue(Text(effortValueText(for: set)))

                // The scale in words. A number between 6 and 10 means nothing
                // on its own to anyone who has not memorised the table.
                Text(effortMeaning(for: set))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(reduceMotion ? nil : AppMotion.compact, value: effortValueText(for: set))
            }
            .padding(Spacing.l)
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
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

    @ViewBuilder
    private var nextUpCard: some View {
        if let nextUp {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    GymEyebrow("Up next")
                    if nextUp.changesExercise {
                        // The one fact worth interrupting for: rest is also the
                        // window to walk to another station.
                        Text("New exercise")
                            .font(AppFont.caption2Bold)
                            .tracking(0.55)
                            .foregroundStyle(Color.gymAccent)
                    }
                    Spacer(minLength: 0)
                }

                Text(nextUp.exerciseName)
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.s) {
                    Text("Set \(nextUp.setNumber) of \(nextUp.setCount)")
                        .font(AppFont.subheadline)
                    if let roleTitle = nextUp.roleTitle {
                        Text("·")
                        Text(roleTitle)
                            .font(AppFont.subheadline)
                    }
                }
                .foregroundStyle(Color.gymSubduedText)

                if let target = nextUp.target {
                    Text(target)
                        .font(AppFont.titleSmallSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("rest-next-up")
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: Spacing.m) {
            if viewModel.isRestReady {
                Button(action: onStartNextSet) {
                    Label("Start next set", systemImage: AppIcon.play)
                }
                .buttonStyle(.gymPrimaryProminent)
                .accessibilityIdentifier("start-next-set")
            } else {
                adjustmentRow

                Button(action: skipRest) {
                    Label("Skip rest", systemImage: AppIcon.fastForward)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.gymPrimary)
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("skip-rest")
            }
        }
    }

    private var adjustmentRow: some View {
        // Three equal targets rather than the old row of four small bordered
        // buttons. Between sets the phone is being operated one-handed, often
        // with chalk on the fingers and without looking — this is the screen
        // that can least afford a 28pt control, and now the one with the most
        // room not to have one.
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
        .foregroundStyle(isEnabled ? Color.gymText : Color.gymSubduedText)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
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

    private var title: String {
        if viewModel.isRestReady { return String(localized: "REST COMPLETE") }
        if viewModel.isTimerPaused { return String(localized: "REST PAUSED") }
        return String(localized: "RESTING")
    }

    /// The dial shrinks at accessibility sizes so the next-set card and the
    /// controls stay on screen; the digits inside it are already scaling.
    private var dialSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 200 : 260
    }

    private var ringWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 16
    }

    private var dialAccessibilityLabel: String {
        if viewModel.isRestReady { return String(localized: "Rest complete") }
        if viewModel.isTimerPaused {
            return String(localized: "Rest paused, \(Int(viewModel.pausedTimeRemaining)) seconds remaining")
        }
        return String(localized: "Resting")
    }

    private var accessibilityIdentifier: String {
        if viewModel.isRestReady { return "rest-ready" }
        return viewModel.isTimerPaused ? "rest-paused" : "rest-running"
    }
}

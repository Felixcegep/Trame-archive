import SwiftUI

/// The input surface for assisted bodyweight work.
///
/// Assistance is the one value in the app that runs *backwards*: every other
/// number means "more is harder", and this one means the opposite. A lifter
/// adding 10 kg to a bar is progressing; a lifter adding 10 kg of assistance to
/// a pull-up machine is regressing. A bare number with a `+` in front of it
/// hides that completely — which is how the panel came to label this field
/// "Weight" and show more assistance as though it were more work.
///
/// So the control states the direction instead of leaving it to be inferred.
/// The track runs harder to easier, the thumb's position *is* the amount, and
/// the value reads "60 kg assist" rather than "60 kg". Nothing here needs the
/// lifter to know which way the arithmetic goes.
struct AssistKeypad: View {
    let value: Double
    /// "kg" or "lbs", already resolved for this set.
    let unitLabel: String
    /// The most assistance the machine can offer. Capped at body weight where
    /// it is known: nothing can take more than all of you off the bar.
    let maximum: Double
    let step: Double
    /// Set the assistance outright — the slider.
    let onChange: (Double) -> Void
    /// Move it by a fixed amount — the quick keys.
    let onAdjust: (Double) -> Void
    /// Hand the surface to the digit pad for a value the slider cannot land on
    /// precisely.
    let onDigits: () -> Void

    @State private var lastPressedStep: Double?

    private var quickSteps: [Double] {
        [-step * 2, -step, step, step * 2]
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { min(max(value, 0), maximum) },
            set: { onChange($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("ASSISTANCE")
                    .font(AppFont.caption2Bold)
                    .tracking(0.6)
                    .foregroundStyle(Color.trameSubdued)

                // "assist" is part of the value, not a caption beside it. Read
                // aloud or glanced at, "60 kg assist" cannot be mistaken for
                // load the way a bare "60 kg" can.
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(Formatters.formatFloat(Float(value)))
                        .font(AppFont.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameText)
                    Text("\(unitLabel) assist")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameSubdued)
                }
            }

            VStack(spacing: Spacing.xs) {
                // The two ends of the track, named. This is the whole point of
                // the control: the direction is stated rather than inferred.
                HStack {
                    Label("Harder", systemImage: AppIcon.chevronLeft)
                        .labelStyle(.titleAndIcon)
                    Spacer(minLength: Spacing.s)
                    Label("Easier", systemImage: AppIcon.chevronRight)
                        .labelStyle(.titleAndIcon)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)

                Slider(value: sliderBinding, in: 0...maximum, step: step) {
                    Text("Assistance")
                } minimumValueLabel: {
                    Text(verbatim: "0")
                        .font(AppFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameSubdued)
                } maximumValueLabel: {
                    Text(Formatters.formatFloat(Float(maximum)))
                        .font(AppFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameSubdued)
                }
                .tint(Color.trameActionDeep)
                .accessibilityValue(Text("\(Formatters.formatFloat(Float(value))) \(unitLabel) of assistance"))
                .accessibilityHint(Text("More assistance makes the set easier"))
                .accessibilityIdentifier("assist-slider")
            }

            HStack(spacing: Spacing.xs) {
                ForEach(quickSteps, id: \.self) { delta in
                    Button {
                        lastPressedStep = delta
                        onAdjust(delta)
                    } label: {
                        Text(signedLabel(delta))
                            .font(AppFont.subheadlineBold)
                            .monospacedDigit()
                            .foregroundStyle(Color.trameText)
                            .frame(maxWidth: .infinity)
                            .frame(height: ComponentSize.keypadKeyHeight)
                            .background(Color.trameSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                    .stroke(Color.trameSeparator, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.gymPress)
                    // The number alone would be read as a target, not a nudge,
                    // and the direction it moves the *difficulty* is the part
                    // worth saying out loud.
                    .accessibilityLabel(
                        Text(
                            delta < 0
                                ? "Reduce assistance by \(Formatters.formatFloat(Float(abs(delta)))), harder"
                                : "Add \(Formatters.formatFloat(Float(delta))) assistance, easier"
                        )
                    )
                    .accessibilityIdentifier("assist-step-\(Formatters.formatFloat(Float(delta)))")
                }
            }

            Button(action: onDigits) {
                Label("Enter an exact amount", systemImage: AppIcon.keyboard)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("assist-keypad-digits")
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.trameCanvas)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .gymFeedback(.keyPressed, trigger: lastPressedStep)
        .accessibilityIdentifier("assist-keypad")
    }

    private func signedLabel(_ delta: Double) -> String {
        let magnitude = Formatters.formatFloat(Float(abs(delta)))
        return delta < 0 ? "−\(magnitude)" : "+\(magnitude)"
    }
}

#Preview {
    VStack {
        Spacer()
        AssistKeypad(
            value: 20,
            unitLabel: "kg",
            maximum: 80,
            step: 2.5,
            onChange: { _ in },
            onAdjust: { _ in },
            onDigits: {}
        )
    }
    .background(Color.trameCanvas)
}

import SwiftUI

/// A device-angle instrument for mobility capture.
///
/// Diagram contract:
///
/// QUESTION      What angle is the phone holding, for which side, and is the
///               reading stable enough to capture?
/// DATA          Signed live device direction, exact recorded range magnitude,
///               capture axis, side, capture state, and stable-hold fraction.
///               A missing angle stays missing rather than becoming zero.
/// ENCODING      Ray rotation is signed device direction; ticks are fixed
///               15-degree landmarks; the outer arc is stable-hold time; teal
///               denotes mobility measurement evidence.
/// INTERACTION   Read-only. Capture, retry, cancellation, and manual input stay
///               native controls owned by the assessment flow.
/// DETAIL        Exact degrees, side, axis, state, and hold percentage are text.
/// EMPTY STATE   No ray is drawn and the value is an em dash.
/// ACCESSIBILITY One concise textual equivalent; streaming values are omitted
///               while measuring so VoiceOver never receives continuous noise.
///
/// Calibration, filtering, and sensor policy stay in the feature that supplies
/// these values. This view does not infer or save an assessment result.
struct GymArcGauge: View {
    enum Axis: String, Equatable, Sendable {
        case gravityPitch
        case gravityRoll
        case relativeYaw

        var title: String {
            switch self {
            case .gravityPitch: String(localized: "Gravity pitch")
            case .gravityRoll: String(localized: "Gravity roll")
            case .relativeYaw: String(localized: "Relative rotation")
            }
        }

        var interpretation: String {
            switch self {
            case .gravityPitch: String(localized: "Tilt from the calibrated start using gravity")
            case .gravityRoll: String(localized: "Side tilt from the calibrated start using gravity")
            case .relativeYaw: String(localized: "Rotation relative to the calibrated heading")
            }
        }
    }

    enum State: Equatable, Sendable {
        case calibrated
        case calibrating
        case measuring
        case stable
        case rejected(reason: String)
        case unavailable(reason: String)
        case completed

        var title: String {
            switch self {
            case .calibrated: String(localized: "Calibrated")
            case .calibrating, .measuring: String(localized: "Measuring")
            case .stable: String(localized: "Stable")
            case .rejected: String(localized: "Rejected")
            case .unavailable: String(localized: "Unavailable")
            case .completed: String(localized: "Measured")
            }
        }

        var detail: String? {
            switch self {
            case .rejected(let reason), .unavailable(let reason):
                return reason.isEmpty ? nil : reason
            case .calibrated, .calibrating, .measuring, .stable, .completed:
                return nil
            }
        }

        var symbolName: String {
            switch self {
            case .calibrated: AppIcon.mobilityAssessment
            case .calibrating, .measuring: AppIcon.gyroscope
            case .stable, .completed: AppIcon.checkmarkCircle
            case .rejected: AppIcon.warningCircle
            case .unavailable: AppIcon.circleDashed
            }
        }

        var showsProgress: Bool {
            switch self {
            case .measuring, .stable, .completed: true
            case .calibrated, .calibrating, .rejected, .unavailable: false
            }
        }
    }

    struct Layout: Equatable, Sendable {
        /// The outer stability arc deliberately leaves a quarter-circle break,
        /// so it cannot be mistaken for the full-circle angle scale inside it.
        static let arcStartFraction: CGFloat = 0.125
        static let arcSpanFraction: CGFloat = 0.75

        let holdProgress: CGFloat?

        init(holdProgress: Double?) {
            guard let holdProgress, holdProgress.isFinite else {
                self.holdProgress = nil
                return
            }
            self.holdProgress = max(0, min(1, CGFloat(holdProgress)))
        }

        var progressTrimEnd: CGFloat? {
            holdProgress.map { Self.arcStartFraction + ($0 * Self.arcSpanFraction) }
        }
    }

    let axis: Axis
    let state: State
    let degreesText: String?
    let angleDegrees: Double?
    let side: String?
    let holdProgress: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        axis: Axis,
        state: State,
        degreesText: String? = nil,
        angleDegrees: Double? = nil,
        side: String? = nil,
        holdProgress: Double? = nil
    ) {
        self.axis = axis
        self.state = state
        self.degreesText = degreesText
        self.angleDegrees = angleDegrees
        self.side = side
        self.holdProgress = holdProgress
    }

    /// Stable and captured values expose the exact result. A live stream does
    /// not, because updating the accessibility value at sensor frequency would
    /// turn VoiceOver into continuous noise.
    var readingOrder: [String] {
        var values: [String] = []
        if let side { values.append(side) }
        values.append(degreesText ?? String(localized: "No angle"))
        if let holdProgress = Layout(holdProgress: holdProgress).holdProgress {
            values.append(holdText(holdProgress))
        }
        values.append(axis.title)
        values.append(state.title)
        return values
    }

    var accessibilitySummary: String {
        let context = [side, axis.title].compactMap { $0 }.joined(separator: ", ")
        switch state {
        case .measuring:
            return String(format: String(localized: "%@, measuring. Keep the device still."), context)
        case .calibrating:
            return [
                context,
                String(localized: "Measuring"),
                String(localized: "Hold the device still for a moment to begin.")
            ].joined(separator: ", ")
        case .calibrated:
            return String(format: String(localized: "%@, calibrated. Ready to measure."), context)
        case .stable, .completed:
            var values = [context, state.title]
            if let degreesText { values.append(degreesText) }
            if let holdProgress = Layout(holdProgress: holdProgress).holdProgress {
                values.append(holdText(holdProgress))
            }
            return values.joined(separator: ", ")
        case .rejected(let reason):
            return reason.isEmpty
                ? String(format: String(localized: "%@, rejected."), context)
                : String(format: String(localized: "%@, rejected: %@"), context, reason)
        case .unavailable(let reason):
            return reason.isEmpty
                ? String(format: String(localized: "%@, unavailable."), context)
                : String(format: String(localized: "%@, unavailable: %@"), context, reason)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            valueHeader
            anglePlot
            evidenceFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
        .accessibilityIdentifier("gym-arc-gauge")
    }

    private var valueHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                valueText
                Spacer(minLength: Spacing.m)
                stateLabel
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                valueText
                stateLabel
            }
        }
    }

    private var valueText: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(degreesText ?? "—")
                .font(AppFont.metricHero)
                .foregroundStyle(Color.trameText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(side ?? String(localized: "No side"))
                .font(AppFont.micro)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Color.trameSubdued)
        }
    }

    private var stateLabel: some View {
        Label(state.title, systemImage: state.symbolName)
            .font(AppFont.metadata)
            .foregroundStyle(stateColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var anglePlot: some View {
        GeometryReader { proxy in
            let sideLength = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Color.trameRow)

                Circle()
                    .stroke(Color.trameSeparator, lineWidth: 1)

                landmarkTicks(sideLength: sideLength)
                zeroReference(sideLength: sideLength)

                if let instrumentAngle {
                    angleRay(sideLength: sideLength, angle: instrumentAngle)
                }

                Circle()
                    .fill(angleDegrees == nil ? Color.trameSubdued : Color.trameMobility)
                    .frame(width: Spacing.m, height: Spacing.m)

                stabilityArc
            }
            .frame(width: sideLength, height: sideLength)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 196 : 228)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    private func landmarkTicks(sideLength: CGFloat) -> some View {
        ForEach(Array(stride(from: -180, through: 165, by: 15)), id: \.self) { landmark in
            Capsule()
                .fill(landmark.isMultiple(of: 45) ? Color.trameSubdued : Color.trameSeparator)
                .frame(
                    width: landmark.isMultiple(of: 45) ? 2 : 1,
                    height: landmark.isMultiple(of: 45) ? Spacing.m : Spacing.s
                )
                .offset(y: -(sideLength * 0.405))
                .rotationEffect(.degrees(Double(landmark)))
        }
    }

    /// The right-facing line is the calibrated zero. Unlike a decorative
    /// crosshair, it has a direct physical meaning for every capture mode.
    private func zeroReference(sideLength: CGFloat) -> some View {
        Capsule()
            .fill(Color.trameSubdued)
            .frame(width: sideLength * 0.34, height: 1)
            .offset(x: sideLength * 0.17)
    }

    /// SwiftUI's positive rotation is clockwise on screen, matching the direct
    /// visual mapping used here. No animation is layered on sensor updates:
    /// the ray follows the current sample rather than trailing it through a
    /// queue of 50 Hz transitions. Values are wrapped to the sensor's signed
    /// one-turn domain rather than normalized to a made-up performance scale.
    private func angleRay(sideLength: CGFloat, angle: Double) -> some View {
        Capsule()
            .fill(Color.trameMobility)
            .frame(width: sideLength * 0.34, height: Spacing.xs)
            .offset(x: sideLength * 0.17)
            // Reduce Motion keeps the exact textual reading while removing
            // continuous physical rotation from the visual instrument.
            .rotationEffect(.degrees(reduceMotion ? 0 : angle))
    }

    private var stabilityArc: some View {
        let layout = Layout(holdProgress: holdProgress)
        return ZStack {
            Circle()
                .trim(
                    from: Layout.arcStartFraction,
                    to: Layout.arcStartFraction + Layout.arcSpanFraction
                )
                .stroke(
                    Color.trameSurface,
                    style: StrokeStyle(lineWidth: Spacing.xs, lineCap: .round)
                )

            if let progressTrimEnd = layout.progressTrimEnd, state.showsProgress {
                Circle()
                    .trim(from: Layout.arcStartFraction, to: progressTrimEnd)
                    .stroke(
                        Color.trameMobility,
                        style: StrokeStyle(lineWidth: Spacing.xs, lineCap: .round)
                    )
            }
        }
        .padding(Spacing.xs)
    }

    private var evidenceFooter: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(verbatim: "Δ 15°")
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                Spacer(minLength: Spacing.s)
                if let progress = Layout(holdProgress: holdProgress).holdProgress {
                    Text(holdText(progress))
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameMobility)
                        .monospacedDigit()
                }
            }

            Text(axis.interpretation)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = state.detail {
                Text(detail)
                    .font(AppFont.metadata)
                    .foregroundStyle(stateColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var instrumentAngle: Double? {
        guard let angleDegrees, angleDegrees.isFinite else { return nil }
        var wrapped = angleDegrees.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { wrapped -= 360 }
        if wrapped < -180 { wrapped += 360 }
        return wrapped
    }

    private var stateColor: Color {
        switch state {
        case .stable, .completed: Color.trameMobility
        case .rejected: Color.trameDestructiveText
        case .unavailable: Color.trameSubdued
        case .calibrated, .calibrating, .measuring: Color.trameText
        }
    }

    private func holdText(_ progress: CGFloat) -> String {
        String(
            format: String(localized: "Hold %lld%%"),
            Int64((progress * 100).rounded())
        )
    }
}

#Preview("Gym angle instrument states") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            GymArcGauge(axis: .gravityPitch, state: .calibrating, side: "Left")
            GymArcGauge(
                axis: .gravityRoll,
                state: .measuring,
                degreesText: "34.8°",
                angleDegrees: 34.8,
                side: "Right",
                holdProgress: 0.42
            )
            GymArcGauge(
                axis: .relativeYaw,
                state: .stable,
                degreesText: "−47.2°",
                angleDegrees: -47.2,
                side: "Left",
                holdProgress: 1
            )
            GymArcGauge(
                axis: .gravityPitch,
                state: .rejected(reason: "Movement detected"),
                degreesText: "14.8°",
                angleDegrees: 14.8,
                side: "Right",
                holdProgress: 0.22
            )
            GymArcGauge(
                axis: .relativeYaw,
                state: .completed,
                degreesText: "42.1°",
                angleDegrees: 42.1,
                side: "Left",
                holdProgress: 1
            )
        }
        .padding(Spacing.l)
    }
    .background(Color.trameCanvas)
}

import SwiftUI

/// An optional, ambient "how still is the device right now" gauge for a timed
/// mobility hold — the gyroscope feature already built for assessments,
/// offered here in the one shape that is honest without a placement protocol.
///
/// `MobilityInclinometerCaptureService` exists to turn a phone held against a
/// specific joint into a calibrated angle — it works because
/// `MobilityInclinometerDefinitionRegistry` tells the assessment flow exactly
/// where to place the device for each protocol ("Place the device along the
/// shin and keep the heel down"). A routine movement in a regular session
/// carries no such placement guidance, and `MobilityMetric.jointAngle` is
/// deliberately excluded from `completionWritable` — the execution surface was
/// never meant to record it. Reusing the service to print a joint-angle number
/// here would be a measurement the app cannot actually stand behind.
///
/// What *is* honest: the same service's stable-hold evaluator already
/// separates "the device stopped moving" from "the device is moving", using
/// only rotation-rate and acceleration noise — nothing that depends on where
/// the phone is. The rotor therefore follows the phone's short relative yaw
/// and labels it as device rotation, never joint range. The axis is fixed to
/// `.yaw` because it can be shown relative to the calibrated start without
/// claiming an anatomical reference.
///
/// Strictly opt-in and disposable: nothing here is written to a
/// `MobilityResult`. Starting it costs a CoreMotion session for the length of
/// the hold; leaving the movement cancels it immediately.
struct MobilitySteadinessPanel: View {
    /// Only ever instantiated while its hold is on screen and running — the
    /// caller conditionally removes this view the moment either stops being
    /// true, which is what `onDisappear` below relies on to cut CoreMotion
    /// updates promptly. There is deliberately no `isActive` flag to toggle
    /// instead: a view that outlives the condition it was built for is
    /// exactly the shape that leaves a sensor running unnoticed.
    let targetSeconds: Int

    @StateObject private var capture = MobilityInclinometerCaptureService()
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Hidden outright, not disabled, when the hardware can't do this —
        // an explanatory error here would be over-explaining a feature nobody
        // asked to see yet. The one place it does speak up is once the lifter
        // has opted in and it turns out unavailable (`unavailableNotice`).
        if isDeviceCapable {
            VStack(alignment: .leading, spacing: Spacing.m) {
                TrameDomainSectionRule(title: "Steadiness", color: .trameMobility)
                rotorButton
                Text(rotorDetail)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onDisappear { stop() }
        }
    }

    private var isDeviceCapable: Bool {
        MobilityCoreMotionManager.shared.isDeviceMotionAvailable
            && MobilityCoreMotionManager.shared.isGyroAvailable
    }

    /// Diagram contract:
    ///
    /// QUESTION      Is the phone still enough to support this timed hold?
    /// DATA          Relative device yaw, capture state, and stable-hold time.
    ///               No joint angle or performed result is inferred or saved.
    /// ENCODING      Needle rotation is signed device rotation; the outer arc
    ///               is stable-hold progress; text and symbol carry state.
    /// INTERACTION   Tap starts or stops this optional sensor session. The
    ///               needle itself is read-only and cannot be dragged.
    /// DETAIL        Signed device degrees and the state label are visible.
    /// EMPTY STATE   Sensor-off is explicit and is not rendered as zero ROM.
    /// ACCESSIBILITY A single button exposes start/stop, state, and purpose;
    ///               live 50 Hz values are intentionally not announced.
    private var rotorButton: some View {
        Button {
            toggleSensor()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.trameRow)

                Circle()
                    .stroke(Color.trameSeparator, lineWidth: 1)

                rotorTicks

                if isExpanded, let rotorAngle {
                    Capsule()
                        .fill(rotorTint)
                        .frame(width: rotorSize * 0.32, height: Spacing.xs)
                        .offset(x: rotorSize * 0.16)
                        .rotationEffect(.degrees(reduceMotion ? 0 : rotorAngle))
                }

                Circle()
                    .trim(from: 0, to: rotorProgress)
                    .stroke(
                        rotorTint,
                        style: StrokeStyle(lineWidth: Spacing.xs, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(Spacing.xs)

                Circle()
                    .fill(Color.trameSurface)
                    .frame(width: rotorSize * 0.52, height: rotorSize * 0.52)
                    .overlay {
                        rotorCenter
                    }
            }
            .frame(width: rotorSize, height: rotorSize)
            .contentShape(Circle())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mobility-steadiness-toggle")
        .accessibilityLabel(Text("Steadiness"))
        .accessibilityValue(Text(rotorStatus))
        .accessibilityHint(Text(rotorDetail))
    }

    private var rotorTicks: some View {
        ForEach(0..<12, id: \.self) { index in
            Capsule()
                .fill(index.isMultiple(of: 3) ? Color.trameSubdued : Color.trameSeparator)
                .frame(width: index.isMultiple(of: 3) ? 2 : 1, height: index.isMultiple(of: 3) ? Spacing.m : Spacing.s)
                .offset(y: -(rotorSize * 0.42))
                .rotationEffect(.degrees(Double(index) * 30))
        }
    }

    private var rotorCenter: some View {
        VStack(spacing: Spacing.xxs) {
            if isExpanded {
                Text(rotorAngleText)
                    .font(AppFont.metricCompact)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Image(systemName: AppIcon.gyroscope)
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }

            Text(rotorStatus)
                .font(AppFont.micro)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(rotorTint)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.s)
    }

    private var rotorStatus: String {
        guard isExpanded else { return String(localized: "Ready") }
        switch capture.state {
        case .idle, .calibrating:
            return String(localized: "Settling…")
        case .measuring(_, let holdProgress):
            return holdProgress >= 1 ? String(localized: "Steady") : String(localized: "Holding…")
        case .rejected:
            return String(localized: "Moving")
        case .completed, .unavailable:
            return String(localized: "Unavailable")
        }
    }

    private var rotorTint: Color {
        guard isExpanded else { return Color.trameSubdued }
        switch capture.state {
        case .rejected:
            return Color.trameDestructiveText
        case .completed:
            return Color.trameCompleted
        case .idle, .calibrating, .measuring:
            return Color.trameMobility
        case .unavailable:
            return Color.trameSubdued
        }
    }

    private var rotorProgress: CGFloat {
        switch capture.state {
        case let .measuring(_, progress):
            return CGFloat(max(0, min(1, progress)))
        case .completed:
            return 1
        case .idle, .calibrating, .rejected, .unavailable:
            return 0
        }
    }

    private var rotorAngle: Double? {
        guard let value = capture.liveAngleDegrees, value.isFinite else { return nil }
        return MobilityInclinometerBaseline.wrappedDegrees(value)
    }

    private var rotorAngleText: String {
        guard let angle = rotorAngle else { return "—" }
        let sign = angle > 0 ? "+" : angle < 0 ? "−" : ""
        return sign + abs(angle).formatted(.number.precision(.fractionLength(1))) + "°"
    }

    private var rotorDetail: String {
        if isExpanded {
            return String(localized: "The dial follows device rotation only. It does not measure or save joint range.")
        }
        return String(localized: "Tap the dial to check whether the phone stays steady during this hold.")
    }

    private var rotorSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 148 : 172
    }

    private func toggleSensor() {
        if isExpanded {
            stop()
        } else {
            isExpanded = true
            start()
        }
    }

    private func start() {
        // Long enough to outlast the hold plus a safety margin: the capture
        // service was built around a single calibrate-then-finish assessment
        // that has to end within a few seconds, but this panel wants to keep
        // streaming `.measuring` updates for the whole hold, so it deliberately
        // never calls `stopMeasurement()` — only `cancelMeasurement()` when the
        // hold is no longer on screen.
        let timeout = max(Double(targetSeconds) + 20, 30)
        capture.startMeasurement(
            configuration: MobilityInclinometerCaptureConfiguration(
                axis: .yaw,
                mode: .relativeRotation,
                timeout: timeout
            )
        )
    }

    private func stop() {
        if isExpanded {
            capture.cancelMeasurement()
        } else {
            capture.reset()
        }
        isExpanded = false
    }
}

#Preview {
    MobilitySteadinessPanel(targetSeconds: 60)
        .padding()
        .background(Color.trameCanvas)
}

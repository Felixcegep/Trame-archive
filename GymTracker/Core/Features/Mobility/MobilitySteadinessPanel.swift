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
/// the phone is. That's a legitimate ambient signal on its own, so this panel
/// asks only that question. It never shows the captured degrees, only whether
/// the device is currently steady, which is why the axis is fixed to `.yaw`
/// in relative-rotation mode — the one axis this service can measure without
/// a gravity reference, i.e. without caring how the phone is oriented.
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

    var body: some View {
        // Hidden outright, not disabled, when the hardware can't do this —
        // an explanatory error here would be over-explaining a feature nobody
        // asked to see yet. The one place it does speak up is once the lifter
        // has opted in and it turns out unavailable (`unavailableNotice`).
        if isDeviceCapable {
            VStack(alignment: .leading, spacing: Spacing.s) {
                toggle
                if isExpanded {
                    content
                }
            }
            .onDisappear { stop() }
        }
    }

    private var isDeviceCapable: Bool {
        MobilityCoreMotionManager.shared.isDeviceMotionAvailable
            && MobilityCoreMotionManager.shared.isGyroAvailable
    }

    private var toggle: some View {
        Button {
            isExpanded.toggle()
            if isExpanded {
                start()
            } else {
                stop()
            }
        } label: {
            Label("Steadiness", systemImage: AppIcon.gyroscope)
                .font(AppFont.captionBold)
                .tracking(0.6)
                .foregroundStyle(isExpanded ? Color.gymPrimary : Color.gymSubduedText)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mobility-steadiness-toggle")
        .accessibilityHint(Text("An optional, ambient sense of how still the device is holding — not a measurement of the movement."))
    }

    @ViewBuilder
    private var content: some View {
        switch capture.state {
        case .idle, .calibrating:
            statusRow(
                title: String(localized: "Settling…"),
                detail: String(localized: "Hold the device still for a moment to begin."),
                fraction: 0,
                tint: Color.gymSubduedText
            )

        case .measuring(_, let holdProgress):
            statusRow(
                title: holdProgress >= 1
                    ? String(localized: "Steady")
                    : String(localized: "Holding…"),
                detail: nil,
                fraction: holdProgress,
                tint: holdProgress >= 1 ? Color.gymSecondary : Color.gymAccent
            )

        case .rejected:
            statusRow(
                title: String(localized: "Moving"),
                detail: nil,
                fraction: 0,
                tint: Color.gymAccent
            )

        case .completed, .unavailable:
            unavailableNotice
        }
    }

    private func statusRow(title: String, detail: String?, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                Text(title)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            Capsule()
                .fill(Color.gymText.opacity(0.08))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * max(0, min(1, fraction)))
                    }
                }
                .animation(reduceMotion ? nil : AppMotion.compact, value: fraction)
            if let detail {
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(detail.map { "\(title). \($0)" } ?? title))
    }

    private var unavailableNotice: some View {
        Text("Motion sensing stopped responding for this hold.")
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
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
        capture.cancelMeasurement()
        isExpanded = false
    }
}

#Preview {
    MobilitySteadinessPanel(targetSeconds: 60)
        .padding()
        .background(Color.gymBackground)
}

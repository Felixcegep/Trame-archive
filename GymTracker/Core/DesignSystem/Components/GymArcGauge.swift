import SwiftUI

/// A neutral sensor-capture gauge. It owns presentation and accessibility
/// semantics only; calibration, filtering, and sensor policy stay in the
/// feature that supplies the values.
struct GymArcGauge: View {
    enum Axis: String, Equatable, Sendable {
        case gravityPitch
        case gravityRoll
        case relativeYaw

        var title: String {
            switch self {
            case .gravityPitch: String(localized: "Gravity pitch")
            case .gravityRoll: String(localized: "Gravity roll")
            case .relativeYaw: String(localized: "Relative yaw")
            }
        }

        var interpretation: String {
            switch self {
            case .gravityPitch: String(localized: "Tilt forward or backward from gravity")
            case .gravityRoll: String(localized: "Tilt side to side from gravity")
            case .relativeYaw: String(localized: "Rotation relative to the calibrated heading")
            }
        }
    }

    enum State: Equatable, Sendable {
        case calibrated
        case measuring
        case stable
        case rejected(reason: String)
        case unavailable(reason: String)
        case completed

        var title: String {
            switch self {
            case .calibrated: String(localized: "Calibrated")
            case .measuring: String(localized: "Measuring")
            case .stable: String(localized: "Stable")
            case .rejected: String(localized: "Rejected")
            case .unavailable: String(localized: "Unavailable")
            case .completed: String(localized: "Completed")
            }
        }

        var detail: String? {
            switch self {
            case .rejected(let reason), .unavailable(let reason):
                return reason.isEmpty ? nil : reason
            case .calibrated, .measuring, .stable, .completed:
                return nil
            }
        }

        var symbolName: String {
            switch self {
            case .calibrated: AppIcon.mobilityAssessment
            case .measuring: AppIcon.timer
            case .stable: AppIcon.checkmarkCircle
            case .rejected: AppIcon.failureCircle
            case .unavailable: AppIcon.circleDashed
            case .completed: AppIcon.checkmarkCircle
            }
        }

        var isLive: Bool {
            self == .measuring
        }

        var showsProgress: Bool {
            if case .unavailable = self { return false }
            return true
        }
    }

    struct Layout: Equatable, Sendable {
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
    let holdProgress: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        axis: Axis,
        state: State,
        degreesText: String? = nil,
        holdProgress: Double? = nil
    ) {
        self.axis = axis
        self.state = state
        self.degreesText = degreesText
        self.holdProgress = holdProgress
    }

    /// Visual reading order remains raw degrees, hold progress, axis, then
    /// interpretation. Live values are intentionally omitted from the
    /// measuring VoiceOver summary so a sensor stream never becomes a stream
    /// of announcements.
    var readingOrder: [String] {
        var values = [degreesText ?? String(localized: "No angle")]
        if let holdProgress = Layout(holdProgress: holdProgress).holdProgress {
            values.append(String(format: String(localized: "Hold %lld%%"), Int64((holdProgress * 100).rounded())))
        }
        values.append(axis.title)
        values.append(state.title)
        return values
    }

    var accessibilitySummary: String {
        switch state {
        case .measuring:
            return String(format: String(localized: "%@, measuring. Keep the device still."), axis.title)
        case .calibrated:
            return String(format: String(localized: "%@, calibrated. Ready to measure."), axis.title)
        case .stable, .completed:
            var values = [axis.title, state.title]
            if let degreesText { values.append(degreesText) }
            if let holdProgress = Layout(holdProgress: holdProgress).holdProgress {
                values.append(String(format: String(localized: "Hold %lld%%"), Int64((holdProgress * 100).rounded())))
            }
            return values.joined(separator: ", ")
        case .rejected(let reason):
            return reason.isEmpty
                ? String(format: String(localized: "%@, rejected."), axis.title)
                : String(format: String(localized: "%@, rejected: %@"), axis.title, reason)
        case .unavailable(let reason):
            return reason.isEmpty
                ? String(format: String(localized: "%@, unavailable."), axis.title)
                : String(format: String(localized: "%@, unavailable: %@"), axis.title, reason)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            gauge

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(axis.title)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(axis.interpretation)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(stateText)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
        .accessibilityIdentifier("gym-arc-gauge")
    }

    private var stateText: String {
        if let detail = state.detail {
            return String(format: String(localized: "%@: %@"), state.title, detail)
        }
        return state.title
    }

    private var gauge: some View {
        let layout = Layout(holdProgress: holdProgress)
        return ZStack {
            Circle()
                .trim(from: Layout.arcStartFraction, to: Layout.arcStartFraction + Layout.arcSpanFraction)
                .stroke(trackColor, style: StrokeStyle(lineWidth: Spacing.m, lineCap: .round))
                .rotationEffect(.degrees(0))

            if let progressTrimEnd = layout.progressTrimEnd, state.showsProgress {
                Circle()
                    .trim(from: Layout.arcStartFraction, to: progressTrimEnd)
                    .stroke(progressColor, style: progressStroke)
                    .rotationEffect(.degrees(0))
            }

            VStack(spacing: Spacing.xs) {
                Image(systemName: state.symbolName)
                    .font(AppFont.titleSmallSemibold)
                    .foregroundStyle(progressColor)
                    .accessibilityHidden(true)

                Text(degreesText ?? String(localized: "No angle"))
                    .font(AppFont.displayMedium.monospacedDigit())
                    .foregroundStyle(Color.gymDataEmphasis)
                    .fixedSize(horizontal: false, vertical: true)

                if let progress = layout.holdProgress {
                    Text(String(format: String(localized: "Hold %lld%%"), Int64((progress * 100).rounded())))
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.s)
        }
        .frame(minWidth: ComponentSize.minimumTouchTarget, minHeight: ComponentSize.minimumTouchTarget)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 180)
        .animation(reduceMotion ? nil : AppMotion.compact, value: layout.holdProgress)
        .accessibilityHidden(true)
    }

    private var trackColor: Color {
        reduceTransparency ? Color.gymCard : Color.gymRowSurface
    }

    private var progressColor: Color {
        switch state {
        case .calibrated: Color.gymPrimary
        case .measuring: Color.gymAccent
        case .stable: Color.gymSecondary
        case .rejected: Color.gymDestructive
        case .unavailable: Color.gymSubduedText
        case .completed: Color.gymSecondary
        }
    }

    private var progressStroke: StrokeStyle {
        StrokeStyle(
            lineWidth: Spacing.m,
            lineCap: .round,
            dash: state.isLive ? [Spacing.xs, Spacing.s] : []
        )
    }
}

#Preview("Gym arc gauge states") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            GymArcGauge(axis: .gravityPitch, state: .calibrated, degreesText: "0.0°")
            GymArcGauge(axis: .gravityRoll, state: .measuring, degreesText: "8.4°", holdProgress: 0.42)
            GymArcGauge(axis: .relativeYaw, state: .stable, degreesText: "−3.2°", holdProgress: 0.86)
            GymArcGauge(axis: .gravityPitch, state: .rejected(reason: "Movement detected"), degreesText: "14.8°", holdProgress: 0.22)
            GymArcGauge(axis: .gravityRoll, state: .unavailable(reason: "Motion sensor unavailable"))
            GymArcGauge(axis: .relativeYaw, state: .completed, degreesText: "4.1°", holdProgress: 1)
        }
        .padding(Spacing.l)
    }
    .background(Color.gymBackground)
}

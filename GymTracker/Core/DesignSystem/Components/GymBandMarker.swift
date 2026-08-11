import SwiftUI

/// A neutral, protocol-agnostic comparison marker for one raw measurement.
///
/// The component deliberately receives presentation strings and normalized
/// geometry rather than a mobility model. That keeps the design-system layer
/// reusable for any evidence-backed interval while leaving interpretation and
/// unit formatting with the owning feature.
struct GymBandMarker: View {
    struct Band: Equatable, Sendable {
        /// A normalized position in the track. A missing lower or upper bound
        /// means the band extends to that edge of the track.
        let lowerFraction: CGFloat?
        let upperFraction: CGFloat?
        let label: String

        init(lowerFraction: CGFloat? = nil, upperFraction: CGFloat? = nil, label: String) {
            self.lowerFraction = lowerFraction
            self.upperFraction = upperFraction
            self.label = label
        }

        /// Returns nil for an absent, non-finite, or inverted interval rather
        /// than drawing a misleading band.
        var normalizedRange: ClosedRange<CGFloat>? {
            guard lowerFraction != nil || upperFraction != nil else { return nil }
            if let lowerFraction, lowerFraction.isFinite == false { return nil }
            if let upperFraction, upperFraction.isFinite == false { return nil }

            let lower = max(0, min(1, lowerFraction ?? 0))
            let upper = max(0, min(1, upperFraction ?? 1))
            guard lower <= upper else { return nil }
            return lower...upper
        }
    }

    enum State: Equatable, Sendable {
        case below
        case within
        case above
        case missing(reason: String)
        case incompatible(reason: String)

        var displayText: String {
            switch self {
            case .below:
                return String(localized: "Below reference band")
            case .within:
                return String(localized: "Within reference band")
            case .above:
                return String(localized: "Above reference band")
            case .missing(let reason):
                return reason.isEmpty
                    ? String(localized: "Measurement unavailable")
                    : String(localized: "Measurement unavailable: \(reason)")
            case .incompatible(let reason):
                return reason.isEmpty
                    ? String(localized: "Reference comparison unavailable")
                    : String(localized: "Reference comparison unavailable: \(reason)")
            }
        }

        var position: Position? {
            switch self {
            case .below: .below
            case .within: .within
            case .above: .above
            case .missing, .incompatible: nil
            }
        }
    }

    enum Position: String, Equatable, Sendable {
        case below
        case within
        case above
    }

    struct Layout: Equatable, Sendable {
        let markerFraction: CGFloat?
        let interval: ClosedRange<CGFloat>?

        init(markerFraction: CGFloat?, band: Band?) {
            if let markerFraction, markerFraction.isFinite {
                self.markerFraction = max(0, min(1, markerFraction))
            } else {
                self.markerFraction = nil
            }
            self.interval = band?.normalizedRange
        }

        /// Returns the marker's center coordinate while keeping its full
        /// shape inside the track. Nil means the observation has no position.
        func markerCenter(trackWidth: CGFloat, markerSize: CGFloat) -> CGFloat? {
            guard let markerFraction,
                  trackWidth.isFinite,
                  markerSize.isFinite,
                  trackWidth >= 0,
                  markerSize > 0
            else { return nil }
            let minimumCenter = markerSize / 2
            let maximumCenter = max(minimumCenter, trackWidth - markerSize / 2)
            return min(maximumCenter, max(minimumCenter, markerFraction * trackWidth))
        }
    }

    let measurement: String?
    let measurementLabel: String
    let band: Band?
    let state: State
    let markerFraction: CGFloat?

    init(
        measurement: String?,
        measurementLabel: String = String(localized: "Measured"),
        band: Band? = nil,
        state: State,
        markerFraction: CGFloat? = nil
    ) {
        self.measurement = measurement
        self.measurementLabel = measurementLabel
        self.band = band
        self.state = state
        self.markerFraction = markerFraction
    }

    /// The visual and VoiceOver reading order is intentionally testable: the
    /// raw observation leads, then the optional interpretation, then state.
    var readingOrder: [String] {
        var values = [measurement.map { "\(measurementLabel): \($0)" } ?? String(localized: "Measurement unavailable")]
        if let band {
            values.append(band.label)
        }
        values.append(state.displayText)
        return values
    }

    var accessibilitySummary: String {
        readingOrder.joined(separator: ". ")
    }

    /// A coordinate exists only for an explicitly positioned state. A caller
    /// cannot accidentally make missing or incompatible evidence look like a
    /// midpoint by supplying a stale fraction.
    func positionedMarkerCenter(trackWidth: CGFloat, markerSize: CGFloat) -> CGFloat? {
        guard state.position != nil else { return nil }
        return Layout(markerFraction: markerFraction, band: band)
            .markerCenter(trackWidth: trackWidth, markerSize: markerSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            measurementView

            if let band {
                Text(band.label)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            markerTrack

            Text(state.displayText)
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
        .accessibilityIdentifier("gym-band-marker")
    }

    private var measurementView: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(measurementLabel)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)
            if let measurement {
                Text(measurement)
                    .font(AppFont.titleSmallSemiboldMonospaced)
                    .foregroundStyle(Color.gymDataEmphasis)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(String(localized: "Measurement unavailable"))
                    .font(AppFont.titleSmallSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var markerTrack: some View {
        GeometryReader { proxy in
            let layout = Layout(markerFraction: markerFraction, band: band)
            let markerSize = Spacing.l
            ZStack(alignment: .leading) {
                if state.position == nil {
                    // A missing or incompatible observation has no coordinate
                    // on this scale. The outlined track is an explicit
                    // unavailable cue, not a marker placed at an invented
                    // midpoint.
                    Capsule(style: .continuous)
                        .stroke(Color.gymText, style: StrokeStyle(lineWidth: Spacing.xxs, dash: [Spacing.xs, Spacing.xs]))
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.s)
                } else {
                    Capsule(style: .continuous)
                        .fill(Color.gymRowSurface)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.s)
                }

                if let interval = layout.interval {
                    Capsule(style: .continuous)
                        .fill(Color.gymSecondarySurface)
                        .frame(width: max(Spacing.xs, (interval.upperBound - interval.lowerBound) * proxy.size.width))
                        .frame(height: Spacing.s)
                        .offset(x: interval.lowerBound * proxy.size.width)
                }

                if let markerCenter = positionedMarkerCenter(trackWidth: proxy.size.width, markerSize: markerSize) {
                    markerShape
                        .frame(width: markerSize, height: markerSize)
                        .offset(x: markerCenter - markerSize / 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: Spacing.xl)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var markerShape: some View {
        switch state {
        case .below:
            GymBandTriangle(pointsUp: false)
                .fill(Color.gymCard)
                .overlay(GymBandTriangle(pointsUp: false).stroke(Color.gymText, lineWidth: Spacing.xxs))
        case .within:
            GymBandDiamond()
                .fill(Color.gymCard)
                .overlay(GymBandDiamond().stroke(Color.gymText, lineWidth: Spacing.xxs))
        case .above:
            GymBandTriangle(pointsUp: true)
                .fill(Color.gymCard)
                .overlay(GymBandTriangle(pointsUp: true).stroke(Color.gymText, lineWidth: Spacing.xxs))
        case .missing:
            Circle()
                .fill(Color.gymCard)
                .overlay(Circle().stroke(Color.gymText, style: StrokeStyle(lineWidth: Spacing.xxs, dash: [Spacing.xs, Spacing.xs])))
        case .incompatible:
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .fill(Color.gymCard)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(Color.gymText, lineWidth: Spacing.xxs)
                }
        }
    }
}

private struct GymBandDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct GymBandTriangle: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

#Preview("Gym band marker states") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            GymBandMarker(
                measurement: "12.5 cm",
                band: .init(lowerFraction: 0.25, upperFraction: 0.75, label: "Reference band: 10–15 cm"),
                state: .within,
                markerFraction: 0.5
            )
            GymBandMarker(
                measurement: "8 cm",
                band: .init(upperFraction: 0.6, label: "Reference band: up to 15 cm"),
                state: .below,
                markerFraction: 0.2
            )
            GymBandMarker(
                measurement: nil,
                state: .missing(reason: "No observation recorded")
            )
            GymBandMarker(
                measurement: "12.5 cm",
                band: .init(lowerFraction: 0.25, upperFraction: 0.75, label: "Reference band unavailable"),
                state: .incompatible(reason: "Different protocol version")
            )
        }
        .padding(Spacing.l)
    }
    .background(Color.gymBackground)
}

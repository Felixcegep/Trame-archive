import SwiftUI

/// The three physical parts of the Trame mark: an angled bar with a collar
/// near each end.
///
/// Addressable individually because the identity's assembly animation moves
/// them separately — the bar lands first, then each collar registers onto it.
/// Nothing else should draw a partial mark.
enum TrameMarkComponent: CaseIterable, Hashable, Sendable {
    case bar
    /// The collar toward the raised end of the bar.
    case collarUpper
    /// The collar toward the lowered end of the bar.
    case collarLower
}

/// The Trame symbol, as geometry rather than an image.
///
/// A `Shape` and not a bitmap or an SVG asset because the mark has to take a
/// tint (`trameMark` resolves per appearance), scale to any size without a
/// second export, and be animated one component at a time. The curves are
/// transcribed from the identity source with its group transforms already
/// applied, so this file is the flattened truth — re-exporting the SVG means
/// re-flattening, not pasting new transforms on top.
///
/// The collars overlap the bar, so **the mark must be filled non-zero**.
/// `fill()` is non-zero by default; an even-odd fill punches holes where the
/// parts cross.
struct TrameMark: Shape {
    /// Which parts to draw. The whole mark by default.
    var components: [TrameMarkComponent]

    init(_ components: [TrameMarkComponent] = TrameMarkComponent.allCases) {
        self.components = components
    }

    /// The whole mark's bounds in the identity's own coordinate space.
    ///
    /// Every component normalises against *this*, not against its own extent,
    /// so drawing one part alone leaves it registered where it belongs
    /// relative to the others.
    private static let designBounds = CGRect(x: 3.403, y: 2.074, width: 330.321, height: 250.674)

    /// The mark's aspect ratio, for callers sizing a container around it.
    static let aspectRatio: CGFloat = designBounds.width / designBounds.height

    /// The smallest size at which the symbol still reads as a barbell rather
    /// than an abstract letterform. Below this, use the wordmark instead of
    /// the mark — there is no small-size variant of this geometry.
    static let minimumLegibleHeight: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        let bounds = Self.designBounds
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        let drawnSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        // Read right to left: shift the design bounds to the origin, scale to
        // fit, then centre in `rect`. `translatedBy`/`scaledBy` prepend, so the
        // last call listed is the first transform a point sees.
        let transform = CGAffineTransform(
            translationX: rect.midX - drawnSize.width / 2,
            y: rect.midY - drawnSize.height / 2
        )
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -bounds.minX, y: -bounds.minY)

        var path = Path()
        for component in components {
            path.addPath(Self.designPath(for: component))
        }
        return path.applying(transform)
    }

    private static func designPath(for component: TrameMarkComponent) -> Path {
        switch component {
        case .bar: barPath
        case .collarUpper: collarUpperPath
        case .collarLower: collarLowerPath
        }
    }

    private static let barPath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 305.351, y: 43.139))
        path.addCurve(
            to: CGPoint(x: 315.239, y: 43.398),
            control1: CGPoint(x: 308.551, y: 41.911),
            control2: CGPoint(x: 312.108, y: 42.004)
        )
        path.addCurve(
            to: CGPoint(x: 322.049, y: 50.574),
            control1: CGPoint(x: 318.371, y: 44.793),
            control2: CGPoint(x: 320.821, y: 47.374)
        )
        path.addCurve(
            to: CGPoint(x: 332.495, y: 77.788),
            control1: CGPoint(x: 325.198, y: 58.776),
            control2: CGPoint(x: 329.347, y: 69.586)
        )
        path.addCurve(
            to: CGPoint(x: 332.236, y: 87.677),
            control1: CGPoint(x: 333.724, y: 80.988),
            control2: CGPoint(x: 333.630, y: 84.545)
        )
        path.addCurve(
            to: CGPoint(x: 325.061, y: 94.486),
            control1: CGPoint(x: 330.842, y: 90.809),
            control2: CGPoint(x: 328.261, y: 93.258)
        )
        path.addCurve(
            to: CGPoint(x: 31.777, y: 207.068),
            control1: CGPoint(x: 274.763, y: 113.794),
            control2: CGPoint(x: 82.074, y: 187.760)
        )
        path.addCurve(
            to: CGPoint(x: 21.888, y: 206.809),
            control1: CGPoint(x: 28.576, y: 208.296),
            control2: CGPoint(x: 25.020, y: 208.203)
        )
        path.addCurve(
            to: CGPoint(x: 15.078, y: 199.633),
            control1: CGPoint(x: 18.756, y: 205.414),
            control2: CGPoint(x: 16.307, y: 202.833)
        )
        path.addCurve(
            to: CGPoint(x: 4.632, y: 172.419),
            control1: CGPoint(x: 11.930, y: 191.431),
            control2: CGPoint(x: 7.780, y: 180.621)
        )
        path.addCurve(
            to: CGPoint(x: 4.891, y: 162.530),
            control1: CGPoint(x: 3.403, y: 169.219),
            control2: CGPoint(x: 3.497, y: 165.662)
        )
        path.addCurve(
            to: CGPoint(x: 12.066, y: 155.721),
            control1: CGPoint(x: 6.285, y: 159.398),
            control2: CGPoint(x: 8.866, y: 156.949)
        )
        path.addCurve(
            to: CGPoint(x: 305.351, y: 43.139),
            control1: CGPoint(x: 62.364, y: 136.413),
            control2: CGPoint(x: 255.053, y: 62.447)
        )
        path.closeSubpath()
        return path
    }()

    private static let collarUpperPath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 198.925, y: 33.569))
        path.addCurve(
            to: CGPoint(x: 206.359, y: 16.870),
            control1: CGPoint(x: 196.367, y: 26.905),
            control2: CGPoint(x: 199.696, y: 19.428)
        )
        path.addCurve(
            to: CGPoint(x: 238.241, y: 4.632),
            control1: CGPoint(x: 218.483, y: 12.216),
            control2: CGPoint(x: 236.555, y: 5.279)
        )
        path.addCurve(
            to: CGPoint(x: 254.940, y: 12.067),
            control1: CGPoint(x: 244.905, y: 2.074),
            control2: CGPoint(x: 252.381, y: 5.403)
        )
        path.addCurve(
            to: CGPoint(x: 310.182, y: 155.978),
            control1: CGPoint(x: 266.824, y: 43.027),
            control2: CGPoint(x: 298.297, y: 125.017)
        )
        path.addCurve(
            to: CGPoint(x: 302.747, y: 172.676),
            control1: CGPoint(x: 312.740, y: 162.642),
            control2: CGPoint(x: 309.411, y: 170.118)
        )
        path.addCurve(
            to: CGPoint(x: 270.866, y: 184.915),
            control1: CGPoint(x: 293.323, y: 176.294),
            control2: CGPoint(x: 280.290, y: 181.297)
        )
        path.addCurve(
            to: CGPoint(x: 254.167, y: 177.480),
            control1: CGPoint(x: 264.202, y: 187.473),
            control2: CGPoint(x: 256.725, y: 184.144)
        )
        path.addCurve(
            to: CGPoint(x: 198.925, y: 33.569),
            control1: CGPoint(x: 242.282, y: 146.519),
            control2: CGPoint(x: 210.809, y: 64.530)
        )
        path.closeSubpath()
        return path
    }()

    private static let collarLowerPath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 28.875, y: 98.845))
        path.addCurve(
            to: CGPoint(x: 36.310, y: 82.146),
            control1: CGPoint(x: 26.317, y: 92.181),
            control2: CGPoint(x: 29.646, y: 84.704)
        )
        path.addCurve(
            to: CGPoint(x: 68.192, y: 69.908),
            control1: CGPoint(x: 48.434, y: 77.492),
            control2: CGPoint(x: 66.506, y: 70.555)
        )
        path.addCurve(
            to: CGPoint(x: 84.890, y: 77.343),
            control1: CGPoint(x: 74.856, y: 67.350),
            control2: CGPoint(x: 82.332, y: 70.679)
        )
        path.addCurve(
            to: CGPoint(x: 140.133, y: 221.254),
            control1: CGPoint(x: 96.775, y: 108.303),
            control2: CGPoint(x: 128.248, y: 190.293)
        )
        path.addCurve(
            to: CGPoint(x: 132.698, y: 237.952),
            control1: CGPoint(x: 142.691, y: 227.918),
            control2: CGPoint(x: 139.362, y: 235.394)
        )
        path.addCurve(
            to: CGPoint(x: 100.816, y: 250.190),
            control1: CGPoint(x: 123.274, y: 241.570),
            control2: CGPoint(x: 110.240, y: 246.573)
        )
        path.addCurve(
            to: CGPoint(x: 84.118, y: 242.756),
            control1: CGPoint(x: 94.152, y: 252.748),
            control2: CGPoint(x: 86.676, y: 249.420)
        )
        path.addCurve(
            to: CGPoint(x: 28.875, y: 98.845),
            control1: CGPoint(x: 72.233, y: 211.795),
            control2: CGPoint(x: 40.760, y: 129.805)
        )
        path.closeSubpath()
        return path
    }()
}

/// The Trame symbol at a given height, tinted for the current appearance.
///
/// Decorative by default: in every placement the identity allows, either a
/// wordmark or a nearby heading already says "Trame", so a second
/// announcement would be noise. `TrameLockup` is the labelled one.
struct TrameMarkView: View {
    var height: CGFloat = 44
    var color: Color = .trameMark
    /// Draw only part of the mark. Whole mark by default; assembly animations
    /// are the only reason to narrow it.
    var components: [TrameMarkComponent] = TrameMarkComponent.allCases

    var body: some View {
        TrameMark(components)
            .fill(color)
            .frame(width: height * TrameMark.aspectRatio, height: height)
            .accessibilityHidden(true)
    }
}

/// The wordmark.
///
/// `Text(verbatim:)` because a brand name is not copy: it must not be
/// localised, and it must not acquire a string key that a translator can
/// reach. SF Pro Rounded matches the identity's `ui-rounded` specimen, with
/// the same slight negative tracking.
struct TrameWordmark: View {
    var textStyle: Font.TextStyle = .title
    var color: Color = .trameMark

    var body: some View {
        Text(verbatim: "Trame")
            .font(.system(textStyle, design: .rounded).weight(.semibold))
            .tracking(-0.5)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

/// Symbol and wordmark together — the full lockup.
///
/// The mark's height is a `@ScaledMetric` against the same text style the
/// wordmark uses, so the two grow together under Dynamic Type instead of the
/// symbol staying pinned while the name beside it doubles. It is also the
/// reason the default lands above `TrameMark.minimumLegibleHeight` at every
/// content size.
struct TrameLockup: View {
    var textStyle: Font.TextStyle = .title
    var color: Color = .trameMark

    @ScaledMetric(relativeTo: .title) private var markHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: markHeight * 0.34) {
            TrameMarkView(height: markHeight, color: color)
            TrameWordmark(textStyle: textStyle, color: color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Trame"))
    }
}

#Preview("Trame mark") {
    VStack(spacing: 32) {
        TrameLockup()

        TrameMarkView(height: 96)

        // The plate treatment: fixed cream on fixed navy, as the app icon and
        // any exported graphic must draw it.
        TrameMarkView(height: 96, color: .trameCream)
            .padding(44)
            .background(Color.trameNavy, in: RoundedRectangle(cornerRadius: 32, style: .continuous))

        // Component registration: each part drawn alone must land where it
        // sits in the whole mark.
        HStack(spacing: 24) {
            ForEach(TrameMarkComponent.allCases, id: \.self) { component in
                TrameMarkView(height: 40, components: [component])
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gymBackground)
}

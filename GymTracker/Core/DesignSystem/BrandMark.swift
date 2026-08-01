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
/// The source is `Documentation/Brand/TrameLogo.svg`: three rounded rects, each
/// carrying its own translate/rotate. Every part below is one of those rects
/// as 8 cubics — 4 corner arcs plus 4 edges written as degenerate curves —
/// with the transforms baked in, which is why the bar arrives already at its
/// -10.33° angle rather than being rotated at draw time. That is the same
/// geometry `Documentation/Brand/TrameLogo.svg` and the app-icon PNGs use, so
/// the launch animation and the icon it launches from are one mark.
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
    ///
    /// The origin is zero because the generator shifts the mark's exact curve
    /// bounds — solved from the cubics, not sampled — to the origin.
    private static let designBounds = CGRect(x: 0, y: 0, width: 772.1533, height: 479.3066)

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
        path.move(to: CGPoint(x: 12.313, y: 261.830))
        path.addCurve(
            to: CGPoint(x: 743.653, y: 128.527),
            control1: CGPoint(x: 256.093, y: 217.396),
            control2: CGPoint(x: 499.873, y: 172.961)
        )
        path.addCurve(
            to: CGPoint(x: 761.100, y: 140.594),
            control1: CGPoint(x: 751.803, y: 127.042),
            control2: CGPoint(x: 759.615, y: 132.444)
        )
        path.addCurve(
            to: CGPoint(x: 771.908, y: 199.887),
            control1: CGPoint(x: 764.703, y: 160.359),
            control2: CGPoint(x: 768.305, y: 180.123)
        )
        path.addCurve(
            to: CGPoint(x: 759.840, y: 217.334),
            control1: CGPoint(x: 773.393, y: 208.037),
            control2: CGPoint(x: 767.990, y: 215.849)
        )
        path.addCurve(
            to: CGPoint(x: 28.500, y: 350.637),
            control1: CGPoint(x: 516.060, y: 261.768),
            control2: CGPoint(x: 272.280, y: 306.203)
        )
        path.addCurve(
            to: CGPoint(x: 11.053, y: 338.570),
            control1: CGPoint(x: 20.350, y: 352.122),
            control2: CGPoint(x: 12.539, y: 346.720)
        )
        path.addCurve(
            to: CGPoint(x: 0.246, y: 279.277),
            control1: CGPoint(x: 7.451, y: 318.805),
            control2: CGPoint(x: 3.848, y: 299.041)
        )
        path.addCurve(
            to: CGPoint(x: 12.313, y: 261.830),
            control1: CGPoint(x: -1.240, y: 271.127),
            control2: CGPoint(x: 4.163, y: 263.315)
        )
        path.closeSubpath()
        return path
    }()

    private static let collarUpperPath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 584.298, y: 382.378))
        path.addCurve(
            to: CGPoint(x: 521.189, y: 36.082),
            control1: CGPoint(x: 563.262, y: 266.946),
            control2: CGPoint(x: 542.225, y: 151.514)
        )
        path.addCurve(
            to: CGPoint(x: 533.256, y: 18.635),
            control1: CGPoint(x: 519.703, y: 27.931),
            control2: CGPoint(x: 525.106, y: 20.121)
        )
        path.addCurve(
            to: CGPoint(x: 634.164, y: 0.246),
            control1: CGPoint(x: 566.892, y: 12.505),
            control2: CGPoint(x: 600.528, y: 6.376)
        )
        path.addCurve(
            to: CGPoint(x: 651.611, y: 12.313),
            control1: CGPoint(x: 642.314, y: -1.240),
            control2: CGPoint(x: 650.125, y: 4.163)
        )
        path.addCurve(
            to: CGPoint(x: 714.720, y: 358.610),
            control1: CGPoint(x: 672.647, y: 127.745),
            control2: CGPoint(x: 693.684, y: 243.178)
        )
        path.addCurve(
            to: CGPoint(x: 702.652, y: 376.056),
            control1: CGPoint(x: 716.205, y: 366.760),
            control2: CGPoint(x: 710.802, y: 374.571)
        )
        path.addCurve(
            to: CGPoint(x: 601.744, y: 394.446),
            control1: CGPoint(x: 669.016, y: 382.186),
            control2: CGPoint(x: 635.380, y: 388.316)
        )
        path.addCurve(
            to: CGPoint(x: 584.298, y: 382.378),
            control1: CGPoint(x: 593.594, y: 395.931),
            control2: CGPoint(x: 585.783, y: 390.528)
        )
        path.closeSubpath()
        return path
    }()

    private static let collarLowerPath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 119.974, y: 466.993))
        path.addCurve(
            to: CGPoint(x: 56.865, y: 120.697),
            control1: CGPoint(x: 98.938, y: 351.561),
            control2: CGPoint(x: 77.902, y: 236.129)
        )
        path.addCurve(
            to: CGPoint(x: 68.933, y: 103.251),
            control1: CGPoint(x: 55.380, y: 112.547),
            control2: CGPoint(x: 60.783, y: 104.736)
        )
        path.addCurve(
            to: CGPoint(x: 169.841, y: 84.861),
            control1: CGPoint(x: 102.569, y: 97.121),
            control2: CGPoint(x: 136.205, y: 90.991)
        )
        path.addCurve(
            to: CGPoint(x: 187.287, y: 96.929),
            control1: CGPoint(x: 177.991, y: 83.376),
            control2: CGPoint(x: 185.802, y: 88.779)
        )
        path.addCurve(
            to: CGPoint(x: 250.396, y: 443.225),
            control1: CGPoint(x: 208.323, y: 212.361),
            control2: CGPoint(x: 229.360, y: 327.793)
        )
        path.addCurve(
            to: CGPoint(x: 238.329, y: 460.671),
            control1: CGPoint(x: 251.882, y: 451.375),
            control2: CGPoint(x: 246.479, y: 459.186)
        )
        path.addCurve(
            to: CGPoint(x: 137.421, y: 479.061),
            control1: CGPoint(x: 204.693, y: 466.801),
            control2: CGPoint(x: 171.057, y: 472.931)
        )
        path.addCurve(
            to: CGPoint(x: 119.974, y: 466.993),
            control1: CGPoint(x: 129.271, y: 480.546),
            control2: CGPoint(x: 121.460, y: 475.143)
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

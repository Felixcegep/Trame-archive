import SwiftUI

enum AppMotion {
    static let compact = Animation.snappy(duration: 0.22, extraBounce: 0)
    static let layout = Animation.spring(response: 0.3, dampingFraction: 1)
    static let gesture = Animation.spring(response: 0.3, dampingFraction: 0.82)

    // MARK: Weighted Pulse

    /// Press: instant and non-accumulating. Short enough that a fast tapper
    /// never sees the response lag the finger.
    static let pressDown = Animation.easeOut(duration: 0.10)

    /// Release: returns *directly* to rest, with no overshoot.
    ///
    /// The identity's Weighted Pulse specimen overshoots to 101% on release.
    /// That contradicts the grammar the same document sets out — controlled
    /// completion, exactly one settle beat — and a bounce that is charming
    /// once is a tic at the hundreds of presses a week this style absorbs.
    /// Overshoot is reserved for the rare branded animations, where it reads
    /// as an event rather than as button behaviour.
    static let pressRelease = Animation.easeOut(duration: 0.19)

    // MARK: Brand curve grammar
    //
    // The four segments every branded animation is built from. Named here
    // rather than inline so a second animation cannot quietly invent a fifth
    // easing and drift out of the family.

    /// Loading the movement — a brief compression before anything travels.
    static let prepareCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.4, y: 0),
        endControlPoint: UnitPoint(x: 0.6, y: 1)
    )

    /// The ascent. Leaves quickly, arrives slowly.
    static let liftCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.18, y: 0.7),
        endControlPoint: UnitPoint(x: 0.3, y: 1)
    )

    /// Completion — decisive, with the deceleration front-loaded.
    static let lockCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.5, y: 0),
        endControlPoint: UnitPoint(x: 0.2, y: 1)
    )

    /// The single settle beat back to exact rest.
    static let settleCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.3, y: 0.6),
        endControlPoint: UnitPoint(x: 0.3, y: 1)
    )

    /// Components arriving on rails in the Trame assembly identity.
    static let assemblyCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.22, y: 0.85),
        endControlPoint: UnitPoint(x: 0.3, y: 1)
    )
}

/// The Weighted Pulse: the one press response in the app.
///
/// Scale, one point of downward travel, and a slight dim. No rotation, no
/// release overshoot, no ripple — those belong to the branded animations,
/// which are rare by design.
///
/// Reduce Motion keeps a 98% press rather than removing the response
/// entirely. Two percent of scale is not vestibular motion, and a button that
/// does nothing at all under the finger is a worse experience than the one
/// the setting is meant to protect; what it drops is the travel.
struct WeightedPulse: ViewModifier {
    var isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(y: travel)
            .opacity(isPressed ? 0.90 : 1)
            .animation(isPressed ? AppMotion.pressDown : AppMotion.pressRelease, value: isPressed)
    }

    private var scale: CGFloat {
        guard isPressed else { return 1 }
        return reduceMotion ? 0.98 : 0.97
    }

    private var travel: CGFloat {
        isPressed && !reduceMotion ? 1 : 0
    }
}

extension View {
    /// Applies the Weighted Pulse to a button style's label.
    func weightedPulse(isPressed: Bool) -> some View {
        modifier(WeightedPulse(isPressed: isPressed))
    }
}

struct GymPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .weightedPulse(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GymPressButtonStyle {
    static var gymPress: GymPressButtonStyle { GymPressButtonStyle() }
}

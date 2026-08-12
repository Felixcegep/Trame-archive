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

    /// One component's arrival, offset by its place in the sequence.
    ///
    /// Built on `assemblyCurve` rather than on a spring: the identity's
    /// assembly is components travelling a rail and stopping, not landing and
    /// wobbling. `0.42s` is long enough to read as deliberate at the sizes
    /// Today's cards occupy and short enough that a lifter who came to start a
    /// session is never waiting on it.
    static func assemblyArrival(
        index: Int,
        stagger: Double = assemblyStagger,
        baseDelay: Double = 0,
        duration: Double = 0.42
    ) -> Animation {
        .timingCurve(assemblyCurve, duration: duration)
        .delay(baseDelay + Double(index) * stagger)
    }

    /// The week strip fills left to right at a tighter cadence than the cards.
    ///
    /// Seven marks at the card stagger would take longer to draw than the whole
    /// rest of the page; at `0.04` they read as one sweep across the week. The
    /// base delay holds them until the card they sit in has arrived, so the
    /// strip fills *into* a card rather than alongside it.
    static let stripStagger: Double = 0.04
    static let stripBaseDelay: Double = 0.26

    /// The gap between one component arriving and the next.
    ///
    /// Small on purpose. Four cards at 0.07s finish 0.21s apart — the sequence
    /// reads as one assembly rather than as four separate animations, which is
    /// the difference between a brand moment and a slow screen.
    static let assemblyStagger: Double = 0.07
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

/// A short horizontal shake: "that did not work, and the reason is right here".
///
/// This is the app's one *refusal* animation, and it exists because a refusal
/// that only prints a sentence is easy to miss. A lifter who taps "Complete
/// set" is not reading the panel — they are looking at the bar, or at the
/// mirror, or at nothing. The tap is the moment they are paying attention to
/// the screen, and if nothing on it moves, the message that appeared a caption
/// away from their thumb may as well not have.
///
/// Both endpoints are at zero translation (`sin` of a whole number of periods),
/// so re-triggering never produces a jump.
struct GymShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    /// Deliberately small. This is a nudge, not a rejection tantrum.
    var travel: CGFloat = 7
    var cycles: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * cycles * 2),
                y: 0
            )
        )
    }
}

private struct GymShakeModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(GymShakeEffect(animatableData: phase))
            .onChange(of: trigger) { _, _ in
                // Reduce Motion drops the shake entirely rather than shrinking
                // it: unlike the Weighted Pulse, oscillation *is* the effect,
                // and there is no smaller honest version of it. The haptic and
                // the message carry the refusal on their own.
                guard !reduceMotion else { return }
                phase = 0
                withAnimation(.linear(duration: 0.4)) { phase = 1 }
            }
    }
}

extension View {
    /// Shakes when `trigger` changes. Pair it with `GymFeedback.validationBlocked`
    /// so the refusal is felt as well as seen.
    func gymShake<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(GymShakeModifier(trigger: trigger))
    }
}

/// Whether a branded assembly has already played on a screen this session.
///
/// The assembly is an *event*, not a screen transition. It marks the first time
/// a lifter sees a surface, which is the one moment it says something; playing
/// it again every time they switch back to the tab turns a brand moment into a
/// stutter between them and the button they came for.
///
/// Session-scoped rather than persisted: a fresh launch is a fresh first
/// impression, and nothing here is worth a `UserDefaults` key.
@MainActor
enum GymAssemblySession {
    private static var played: Set<String> = []

    /// Claims the assembly for `screen`, returning whether the caller won it.
    /// Calling twice for the same screen returns `false` the second time.
    static func claim(_ screen: String) -> Bool {
        played.insert(screen).inserted
    }
}

/// A component arriving on its rail.
///
/// The Trame assembly, applied to a stack of cards: each one rises a short
/// distance into place and fades up, offset from the one above it. The travel
/// is deliberately small — this is a component seating itself, not a card
/// flying in from off screen.
///
/// Reduce Motion drops the travel and the stagger and keeps a crossfade, which
/// is what both of the closest domain references specify for exactly this
/// pattern: the content still announces itself as new without anything
/// traversing the screen.
struct GymAssemblyEntrance: ViewModifier {
    /// Position in the sequence, from zero. Drives the delay only.
    let index: Int
    /// Whether this surface is playing the assembly at all. A returning lifter
    /// passes `false` and gets a static screen.
    let isActive: Bool
    var stagger: Double = AppMotion.assemblyStagger
    var baseDelay: Double = 0
    var travel: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasArrived = false

    func body(content: Content) -> some View {
        content
            .opacity(hasArrived ? 1 : 0)
            .offset(y: offset)
            .onAppear {
                guard isActive else {
                    hasArrived = true
                    return
                }
                withAnimation(animation) { hasArrived = true }
            }
    }

    private var offset: CGFloat {
        // Reduce Motion never travels, in either direction.
        guard !reduceMotion else { return 0 }
        return hasArrived ? 0 : travel
    }

    private var animation: Animation {
        guard !reduceMotion else { return .easeOut(duration: 0.2) }
        return AppMotion.assemblyArrival(index: index, stagger: stagger, baseDelay: baseDelay)
    }
}

/// One settle beat on first appearance — the mark scales just past rest and
/// returns, once.
///
/// Reserved for the element a screen wants read first: today's mark in the week
/// strip. It is the identity's settle beat rather than a bounce, and it never
/// repeats — a pulse that loops stops being a cue and becomes wallpaper.
struct GymSettleBeat: ViewModifier {
    let isActive: Bool
    /// Position in the sequence it belongs to, so the beat lands *after* its
    /// own arrival rather than during it.
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                guard isActive, !reduceMotion else { return }
                let arrival = Double(index) * AppMotion.assemblyStagger
                withAnimation(.timingCurve(AppMotion.liftCurve, duration: 0.16).delay(arrival + 0.24)) {
                    scale = 1.04
                }
                withAnimation(.timingCurve(AppMotion.settleCurve, duration: 0.22).delay(arrival + 0.40)) {
                    scale = 1
                }
            }
    }
}

extension View {
    /// Arrives on a rail, offset by `index`. See `GymAssemblyEntrance`.
    func gymAssembly(index: Int, isActive: Bool) -> some View {
        modifier(GymAssemblyEntrance(index: index, isActive: isActive))
    }

    /// One mark of the week strip filling in. Tighter cadence and a shorter
    /// rise than a card, because it is a dot rather than a surface.
    func gymStripFill(position: Int, isActive: Bool) -> some View {
        modifier(
            GymAssemblyEntrance(
                index: position,
                isActive: isActive,
                stagger: AppMotion.stripStagger,
                baseDelay: AppMotion.stripBaseDelay,
                travel: 6
            )
        )
    }

    /// A single settle beat after arriving. See `GymSettleBeat`.
    func gymSettleBeat(index: Int, isActive: Bool) -> some View {
        modifier(GymSettleBeat(isActive: isActive, index: index))
    }
}
